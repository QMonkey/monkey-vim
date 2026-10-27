# monkey-scripts/lib/common.sh — colors, logging, platform probes, version
# comparison, source-build job default. Retry lives in lib/retry.sh, TIOCSTI
# injection in lib/tty.sh, the XDG_RUNTIME_DIR repair in lib/env.sh.
# Sourced by scripts/install.sh and scripts/checkhealth.sh (see README.md).

# ──────────────────────────── colors ────────────────────────────
# Plain assignments, not `readonly`: entry points may be sourced more than
# once (tests, chained runs) and re-assigning a readonly aborts.
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ──────────────────────────── logging ────────────────────────────
# 2-space indent, tag centered in 4 columns ([INFO] / [ OK ] / [WARN] /
# [FAIL]). fail() aborts under install.sh (MONKEY_FAIL_EXITS=true) and stays
# status-neutral under checkhealth.sh (it collects failures instead).
info() { echo -e "  [${CYAN}INFO${NC}] $*"; }
ok() { echo -e "  [${GREEN} OK ${NC}] $*"; }
warn() { echo -e "  [${YELLOW}WARN${NC}] $*"; }
fail() {
	echo -e "  [${RED}FAIL${NC}] $*"
	if ${MONKEY_FAIL_EXITS:-false}; then
		exit 1
	fi
	return 0
}

# Fatal for both entry points (bad argument, unusable environment).
die() {
	echo -e "  [${RED}FAIL${NC}] $*"
	exit 1
}

# ──────────────────────────── platform ────────────────────────────
require_home() {
	# Never let a missing HOME fail later under `set -u`.
	[ -n "${HOME:-}" ] || die "\$HOME is not set — cannot determine install locations."
}

# Parallel-jobs default for source builds. An exported JOBS always wins.
JOBS=${JOBS:-$(nproc 2>/dev/null || echo 4)}

# WSL interop injects the WINDOWS PATH into ours: tools on the Windows side
# appear as /mnt/* shims that are NOT Linux binaries (sudo's secure_path
# drops /mnt/*, `npm i -g` through a shim lands on the Windows tree). Treat
# /mnt/* resolutions as "not installed".
have_native_cmd() {
	# Delegate to native_bin_path: ONE resolver owns the shim-skip logic,
	# and it keeps scanning past /mnt/* shims to a native candidate later in
	# PATH instead of rejecting on the first hit. Works inside _retry_run's
	# bash -c child because the export whitelist carries its closure.
	native_bin_path "$1" >/dev/null
}

# Resolve <cmd> to a NATIVE (Linux) binary path: under WSL interop skip
# /mnt/* shim candidates and let the next match in PATH win; non-WSL is a
# plain `command -v`. POSIX expansions only — also emitted into login
# profiles (may be zsh).
native_bin_path() {
	local cmd="$1"
	local rest="$PATH" e
	if ! is_wsl; then
		e=$(command -v "$cmd" 2>/dev/null) && {
			printf '%s' "$e"
			return 0
		}
		return 1
	fi
	while [ -n "$rest" ]; do
		e=${rest%%:*}
		case "$rest" in *:*) rest=${rest#*:} ;; *) rest="" ;; esac
		case "$e" in /mnt/*) continue ;; esac
		[ -x "$e/$cmd" ] || continue
		printf '%s' "$e/$cmd"
		return 0
	done
	return 1
}

# Absolute path to a LINUX sudo, or non-zero. Windows sudo.exe exposed via
# WSL interop would be meaningless to run.
native_sudo() {
	native_bin_path sudo
}

is_wsl() {
	case "$(uname -r)" in
	*[Mm]icrosoft*) return 0 ;;
	*) return 1 ;;
	esac
}

# retry's function-first child needs the sudo_cmd closure exported — the
# lib that owns the functions registers them (see retry.sh).
RETRY_EXPORT_FUNCS="native_sudo have_native_cmd native_bin_path is_wsl"

# Granular OS id: debian | ubuntu | arch | opensuse | centos | fedora |
# macos | linux-unknown | unknown. Every supported distro is its own id —
# nothing is folded into a neighbour, so the package tables can give each
# one the names its own repositories use. Derivatives are normalised here,
# at the only place that reads /etc/os-release; to fold a new id into a
# sibling, add it to that sibling's line and every table follows.
os_detect() {
	case "$(uname -s)" in
	Linux)
		if [ -f /etc/os-release ]; then
			# shellcheck disable=SC1091
			. /etc/os-release
			case "$ID" in
			ubuntu | linuxmint | pop | elementary | zorin) echo "ubuntu" ;;
			debian) echo "debian" ;;
			arch | manjaro | endeavouros) echo "arch" ;;
			opensuse | opensuse-leap | opensuse-tumbleweed | opensuse-microos | suse | sles) echo "opensuse" ;;
			centos | rhel | rocky | almalinux | ol) echo "centos" ;;
			fedora) echo "fedora" ;;
			*) echo "linux-unknown" ;;
			esac
		else
			echo "linux-unknown"
		fi
		;;
	Darwin) echo "macos" ;;
	*) echo "unknown" ;;
	esac
}

# Version comparison: GNU sort -V -C when available (BSD sort on macOS has
# neither flag — numeric field compare fallback).
if sort -V </dev/null >/dev/null 2>&1; then
	HAVE_SORT_V=1
else
	HAVE_SORT_V=0
fi
version_ge() {
	local have="$1" min="$2" hp mp
	if [ "$HAVE_SORT_V" = 1 ]; then
		printf '%s\n%s\n' "$min" "$have" | sort -V -C
		return
	fi
	while [ -n "$have" ] || [ -n "$min" ]; do
		hp="${have%%.*}"
		mp="${min%%.*}"
		if [ "$have" = "$hp" ]; then have=""; else have="${have#*.}"; fi
		if [ "$min" = "$mp" ]; then min=""; else min="${min#*.}"; fi
		hp=${hp:-0}
		mp=${mp:-0}
		if [ "$hp" -gt "$mp" ] 2>/dev/null; then
			return 0
		elif [ "$hp" -lt "$mp" ] 2>/dev/null; then
			return 1
		fi
	done
	return 0
}

# First version-looking token of a binary's version output. Tries --version,
# -V, -v (tmux only answers -V) and finally the bare subcommand `version`
# (zig and go have no --version); the caller-supplied regex lets suffix
# versions ("3.7b") survive — DEFAULT_VER_RE is plain X.Y. A tool that takes
# "version" as a positional instead just errors out (rc != 0 → skipped).
DEFAULT_VER_RE='[0-9]+\.[0-9]+'
extract_version() {
	local bin="$1" regex="${2:-$DEFAULT_VER_RE}" flag ver="" out
	for flag in --version -V -v version; do
		out=$("$bin" "$flag" 2>/dev/null) || out=""
		[ -n "$out" ] || continue
		ver=$(printf '%s\n' "$out" | grep -oE "$regex" | head -1)
		if [ -n "$ver" ]; then
			break
		fi
	done
	printf '%s' "$ver"
}

# Version gate for the INSTALL side (checkhealth's ver: specs are the
# checkhealth-side counterpart): binary present AND version >= min. Returns
# 1 on "absent" and "unparsable" alike — callers mean "old or missing".
bin_at_least() {
	local bin="$1" min="$2"
	have_native_cmd "$bin" || return 1
	local ver
	ver=$(extract_version "$bin" "${3:-$DEFAULT_VER_RE}")
	[ -n "$ver" ] || return 1
	version_ge "$ver" "$min"
}
