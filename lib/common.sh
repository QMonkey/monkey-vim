# monkey-scripts/lib/common.sh — colors, logging, platform probes, shell env.
#
# Sourced by scripts/install.sh and scripts/checkhealth.sh; never executed on
# its own. monkey-* repos pull it in through `git subtree add -P scripts ...`
# (see README.md).

# ──────────────────────────── colors ────────────────────────────
# Plain assignments, not `readonly`: a script may source the entry points
# more than once (tests, chained runs) and re-assigning a readonly aborts.
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ──────────────────────────── logging ────────────────────────────
# List-item helpers shared by install.sh and checkhealth.sh: 2-space indent,
# brackets outside the color span, the tag centered in 4 columns
# ([INFO] / [ OK ] / [WARN] / [FAIL]).
#
# fail() differs per entry point: install.sh aborts on the first failure
# (MONKEY_FAIL_EXITS=true), checkhealth.sh keeps going and summarizes
# (REQUIRED_FAILURES decides the exit status) — so there it must not abort
# and must stay status-neutral under `set -e`.
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

# Bold section title. A data-provided title may already carry ${NC} to end
# the bold span early ("python3${NC} (TIOCSTI injection)") — do not reset a
# second time, so the byte stream matches a hand-written header exactly.
print_bold_header() {
	case "$1" in
	*"${NC}"*) echo -e "${BOLD}$1" ;;
	*) echo -e "${BOLD}$1${NC}" ;;
	esac
}

# ──────────────────────────── platform ────────────────────────────
require_home() {
	# Never let a missing HOME fail later under `set -u`.
	[ -n "${HOME:-}" ] || die "\$HOME is not set — cannot determine install locations."
}

# WSL interop appends the WINDOWS PATH to ours, so tools installed on the
# Windows side (node, python, git, sudo.exe, ...) appear as /mnt/c/... shims.
# They are NOT Linux binaries: `sudo` cannot even see them (secure_path drops
# /mnt/*) and a global `npm install -g` through the shim would land on the
# WINDOWS side. Treat /mnt/* resolutions as "not installed" so the real Linux
# packages get installed instead.
have_native_cmd() {
	command -v "$1" &>/dev/null || return 1
	case "$(command -v "$1")" in
	/mnt/*) return 1 ;; # WSL Windows-interop shim
	esac
	return 0
}

# Absolute path to a LINUX sudo, or non-zero. Windows 11 ships an optional
# sudo.exe that WSL interop exposes as /mnt/.../sudo.exe — running it from
# WSL would be meaningless.
native_sudo() {
	local p
	have_native_cmd sudo || return 1
	p=$(command -v sudo)
	printf '%s' "$p"
}

is_wsl() {
	case "$(uname -r)" in
	*[Mm]icrosoft*) return 0 ;;
	*) return 1 ;;
	esac
}

# Granular OS id: debian | ubuntu | arch | opensuse | centos | macos |
# linux-unknown | unknown. Package-manager switching and most package-name
# lookups use OS_FAMILY instead — ubuntu is merged back into debian there,
# since only a couple of repos (hyprland) care about the split.
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
			centos | rhel | fedora | rocky | almalinux | ol) echo "centos" ;;
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

# Package-manager family: ubuntu → debian, everything else passes through.
os_family() {
	case "$1" in
	ubuntu) echo "debian" ;;
	*) echo "$1" ;;
	esac
}

# Human-readable package manager for the Platform section.
pkg_manager_name() {
	case "${OS_FAMILY:-$(os_family "${OS:-unknown}")}" in
	debian) echo "apt" ;;
	arch) echo "pacman" ;;
	opensuse) echo "zypper" ;;
	centos) echo "dnf" ;;
	macos) echo "homebrew" ;;
	*) echo "" ;;
	esac
}

print_platform() {
	echo -e "${BOLD}Platform${NC}"
	echo -e "  OS: ${CYAN}$(uname -s)${NC}"
	local pm
	pm=$(pkg_manager_name)
	if [ -n "$pm" ]; then
		echo -e "  Package manager: ${CYAN}${pm}${NC}"
	else
		warn "Unsupported OS — install dependencies manually"
	fi
	echo ""
}

# ────────────────────── shell env files / PATH ──────────────────────
shell_env_files() {
	# The TARGET login shell, queried from the user database: on a
	# zsh-default machine (or after the login shell was switched to zsh) it
	# is zsh and the env blocks belong in ~/.zprofile; on bash machines they
	# land in the bash profile files. Falls back to $SHELL, then bash (macOS
	# has no getent; its $SHELL already reflects the login shell).
	local shell_bin
	# getent does not exist on macOS — guard the call, otherwise the
	# command-not-found failure (127) would trip `set -e` and kill the script
	# before the dscl fallback below ever runs.
	if have_native_cmd getent; then
		shell_bin=$(getent passwd "$(id -un)" 2>/dev/null | cut -d: -f7)
	fi
	if [ -z "$shell_bin" ] && [ "$(uname -s)" = Darwin ]; then
		# No getent on macOS — query the directory service instead ($SHELL is
		# a login-time snapshot and goes stale right after a chsh in the same
		# session).
		shell_bin=$(dscl . -read /Users/"$(id -un)" UserShell 2>/dev/null | awk '{print $2}')
	fi
	shell_bin=${shell_bin:-${SHELL:-bash}}
	shell_bin=${shell_bin##*/}
	case "$shell_bin" in
	zsh)
		printf '%s\n' "$HOME/.zprofile"
		;;
	bash)
		if [ -f "$HOME/.bash_profile" ]; then
			printf '%s\n' "$HOME/.bash_profile"
		else
			printf '%s\n' "$HOME/.profile"
		fi
		printf '%s\n' "$HOME/.bashrc"
		;;
	*)
		printf '%s\n' "$HOME/.profile"
		;;
	esac
}

append_env_block() {
	# Usage: append_env_block <marker> <block>
	# Appends <block> guarded by <marker> to every shell env file, once.
	local marker="$1"
	local block="$2"
	local f
	while IFS= read -r f; do
		[ -n "$f" ] || continue
		[ -f "$f" ] || touch "$f"
		if ! grep -qF -- "$marker" "$f" 2>/dev/null; then
			printf '\n# %s\n%b\n' "$marker" "$block" >>"$f"
			ok "Added '$marker' to $f"
		fi
	done < <(shell_env_files)
}

refresh_path() {
	# In-session PATH refresh so newly installed tools are found by this script.
	if have_native_cmd go; then
		local gopath
		gopath=$(go env GOPATH 2>/dev/null || echo "$HOME/go")
		export PATH="$gopath/bin:$PATH"
	fi
	# Not `[ ... ] && . ...`: when the file is missing the function returns
	# non-zero and, under set -e, silently aborts the whole script.
	if [ -f "$HOME/.cargo/env" ]; then . "$HOME/.cargo/env"; fi
}

# go install drops binaries in $(go env GOPATH)/bin (default ~/go/bin) and
# `cargo install` in ~/.cargo/bin — neither is guaranteed on PATH for this run.
ensure_go_env() {
	if have_native_cmd go; then
		local gopath
		gopath=$(go env GOPATH 2>/dev/null || echo "$HOME/go")
		case ":$PATH:" in *":$gopath/bin:"*) ;; *) export PATH="$gopath/bin:$PATH" ;; esac
	fi
}

# Version comparison. GNU sort -V -C is what the upstream scripts used; BSD
# sort (macOS) has neither flag, so fall back to a numeric field compare.
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

# ────────────────────── TIOCSTI injection ──────────────────────
# Type <cmd> + newline into the controlling terminal: the parent shell
# executes it as if the user had typed it — AFTER this script (and any
# wrapper chaining it) has fully exited, so injection can never disturb the
# run itself. Needs python3 or perl; any failure returns non-zero so callers
# can fall back to a printed hint. Never fatal.
inject_tty() {
	local cmd="$1" tiocsti
	[ -n "$cmd" ] || return 1
	# No writable controlling terminal (CI, nested pipes) — nothing to inject
	# into. access(W_OK) on /dev/tty fails with ENXIO when the process has no
	# controlling tty.
	[ -w /dev/tty ] || return 1
	# python3 first: termios.TIOCSTI carries the correct constant per platform
	# (Linux 0x5412, Darwin 0x80047412).
	if have_native_cmd python3; then
		python3 - "$cmd" <<'PYEOF' 2>/dev/null && return 0
import sys, os, fcntl, termios
cmd = sys.argv[1] + "\n"
try:
    fd = os.open("/dev/tty", os.O_WRONLY)
    ioctl = termios.TIOCSTI
except (OSError, AttributeError):
    sys.exit(1)
for ch in cmd:
    try:
        fcntl.ioctl(fd, ioctl, ord(ch))
    except OSError:
        sys.exit(1)
PYEOF
	fi
	# perl fallback: macOS ships /usr/bin/perl, Debian/Ubuntu perl-base is
	# Essential. TIOCSTI's value differs per platform.
	tiocsti=0x5412
	[ "$(uname -s)" = "Darwin" ] && tiocsti=0x80047412
	perl -e '
		my ($cmd, $tio) = @ARGV;
		open(my $tty, ">", "/dev/tty") or exit 1;
		for my $ch (split //, $cmd . "\n") {
			ioctl($tty, hex($tio), ord($ch)) or exit 1;
		}
	' "$cmd" "$tiocsti" 2>/dev/null && return 0
	return 1
}

# ────────────────────── banner ──────────────────────
# Fixed 40-column box; the title is centered inside it.
print_banner() {
	local title="$1" pad
	pad=$(( (40 - ${#title}) / 2 ))
	[ "$pad" -gt 0 ] || pad=0
	echo ""
	echo -e "${BOLD}╔══════════════════════════════════════════╗${NC}"
	echo -e "${BOLD}║$(printf '%*s' "$pad" '')${title}$(printf '%*s' $(( 40 - pad - ${#title} )) '')║${NC}"
	echo -e "${BOLD}╚══════════════════════════════════════════╝${NC}"
	echo ""
}
