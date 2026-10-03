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

# ────────────────────── banner ──────────────────────
# 80-column box (the smallest standard terminal width); the title is
# centered inside it. The border is generated from WIDTH so the character
# count can never drift from the padding math again.
print_banner() {
	local title="$1" width=80 pad border right
	printf -v border '═%.0s' {1..80}
	pad=$(((width - ${#title}) / 2))
	[ "$pad" -gt 0 ] || pad=0
	right=$((width - pad - ${#title}))
	[ "$right" -gt 0 ] || right=0
	echo ""
	echo -e "${BOLD}╔${border}╗${NC}"
	echo -e "${BOLD}║$(printf '%*s' "$pad" '')${title}$(printf '%*s' "$right" '')║${NC}"
	echo -e "${BOLD}╚${border}╝${NC}"
	echo ""
}

# Nested-call guard, exported on purpose: the nesting crosses a PROCESS
# boundary — run_checkhealth retries `bash checkhealth.sh --install`, and
# that child process re-enters retry from refresh_pkg / install_sys_pkg /
# npm_install_g. A shell-local flag would not cross it, and unguarded
# nesting multiplies attempts (3×3=9) while stacking the backoff sleeps —
# on a down network one apt call could stall the install for many minutes.
# While any outer retry is active (count > 0), an inner retry runs its
# command ONCE: the outer loop already bounds the total attempts.
RETRY_ACTIVE_COUNT=${RETRY_ACTIVE_COUNT:-0}
export RETRY_ACTIVE_COUNT

# Per-attempt timeout: GNU timeout on Linux, gtimeout (coreutils) on macOS.
# Empty when neither exists — retry then runs commands unguarded rather
# than breaking the run (a silent hang is recoverable by hand; a broken
# run is not).
if command -v timeout >/dev/null 2>&1; then
	TIMEOUT_BIN=timeout
elif command -v gtimeout >/dev/null 2>&1; then
	TIMEOUT_BIN=gtimeout
else
	TIMEOUT_BIN=""
fi

# Kill-after grace for retry's per-attempt timeout: SIGTERM alone can be
# ignored (pacman mid-write, brew's ruby), and a command that survives TERM
# would hang its timeout forever — holding a package-manager lock for the
# rest of the install. After the TERM, timeout escalates to SIGKILL once
# the grace elapses, so the attempt ALWAYS ends. Unset (or any value)
# defaults to 30s; explicitly EMPTY disables the escalation — the -k flag
# is then omitted entirely (timeout implementations without -k, or a
# deliberate TERM-only policy).
RETRY_KILL_AFTER=${RETRY_KILL_AFTER-30}

# retry's execution helper. $1 = timeout seconds ("0" disables), rest =
# command. timeout(1) can only exec binaries — and retry IS handed a shell
# function (sudo_cmd) — so function-first commands re-enter through a
# child bash with the function and its own helpers exported. Everything
# else goes to the timeout binary directly.
_retry_run() {
	local t="$1"
	shift
	if [ -z "$TIMEOUT_BIN" ] || [ "$t" -eq 0 ]; then
		"$@"
		return
	fi
	# -k only when a kill-after grace is configured: an empty
	# RETRY_KILL_AFTER must reach timeout as a plain -t invocation, not as
	# `-k ""` (which timeout rejects with rc 125).
	local -a ka=()
	if [ -n "$RETRY_KILL_AFTER" ]; then
		ka=(-k "$RETRY_KILL_AFTER")
	fi
	if declare -F "$1" >/dev/null 2>&1; then
		local fn
		# The whitelist must carry the WHOLE dependency closure of the
		# wrapped command: have_native_cmd calls native_bin_path, which
		# calls is_wsl — missing one link makes every exported-function
		# call die with "command not found" inside the child (observed on
		# openSUSE: sudo_cmd -> native_sudo -> have_native_cmd ->
		# native_bin_path, which the old whitelist did not carry).
		for fn in "$1" retry _retry_run native_sudo have_native_cmd native_bin_path is_wsl; do
			# export -f: export the FUNCTION named by $fn's value (dynamic
			# by design — the wrapped command may be a framework function).
			declare -F "$fn" >/dev/null 2>&1 && export -f "$fn"
		done
		"$TIMEOUT_BIN" ${ka[@]+"${ka[@]}"} "$t" bash -c '"$@"' _ "$@"
	else
		"$TIMEOUT_BIN" ${ka[@]+"${ka[@]}"} "$t" "$@"
	fi
}

# ──────────────────────────── retry ────────────────────────────
# Reusable retry wrapper for every network-flavoured command (downloads,
# git, package managers). Runs <cmd> up to <attempts> times; between
# attempts it sleeps base * 2^(attempt-1) seconds (15s, 30s, 60s, 120s),
# capped at <max_delay>. Exponential backoff beats a fixed interval:
# transient failures (mirror hiccup, rate limit, flaky GitHub) rarely
# clear within a constant window, and the growing gaps cost nothing when
# the first retry already succeeds. With the defaults the wait before the
# LAST attempt is exactly 120s — the longest gap sits right before the
# final shot, where a longer pause buys the most.
#
# Every attempt also runs under a timeout: a black-holed connection
# (SYN sent, nothing back — the 135s git fetch stalls seen against
# github.com) would otherwise hang the installer forever with no output.
# rc 124 is timeout's own exit code and gets its own message.
#
# Usage: retry [-n attempts] [-d base_delay] [-m max_delay] [-t timeout]
#              [-s desc] cmd...
#   -n  total attempts, NOT retries (default 5)
#   -d  first sleep in seconds (default 15)
#   -m  sleep cap in seconds (default 120)
#   -t  per-attempt timeout in seconds (default 600; 0 disables) — pass a
#       larger value for operations that are legitimately long (package
#       installs, big clones) so a slow-but-alive transfer is not killed
#   -s  human description for the warning line (default: the command)
# Returns the command's last exit code (0 on success; 124 = timed out).
# Safe under set -e: the command runs inside an if-condition. cmd's own
# flags are untouched — getopts stops at the first non-option word (e.g.
# `curl`), so only the leading `-n/-d/-m/-t/-s` belong to retry.
retry() {
	# Defaults: 5 attempts, backoff 15s→30s→60s→120s (the last wait before
	# the final attempt is the 120s maximum).
	local attempts=5 base=15 max=120 timeout_s=600 desc=""
	local opt
	# A leading -- may guard a wrapped command that itself starts with an
	# option-looking word; strip it BEFORE parsing.
	[ "${1:-}" = "--" ] && shift
	# OPTIND=1 is required, not cosmetic: getopts resumes at $OPTIND on the
	# next call in the same shell, so without the reset a second retry()
	# call would start parsing at the previous call's position and
	# misparse everything.
	OPTIND=1
	while getopts ":n:d:m:t:s:" opt "$@"; do
		case "$opt" in
		n) attempts=$OPTARG ;;
		d) base=$OPTARG ;;
		m) max=$OPTARG ;;
		t) timeout_s=$OPTARG ;;
		s) desc=$OPTARG ;;
		*) return 2 ;;
		esac
	done
	shift $((OPTIND - 1))
	[ $# -gt 0 ] || return 2
	# Nested call (see RETRY_ACTIVE_COUNT above): run once, no sleeps —
	# the outer loop bounds the total attempts. The if/else keeps a failed
	# command set -e-safe, exactly like the normal path below.
	if [ "$RETRY_ACTIVE_COUNT" -gt 0 ]; then
		if _retry_run "$timeout_s" "$@"; then
			return 0
		else
			return "$?"
		fi
	fi
	RETRY_ACTIVE_COUNT=$((RETRY_ACTIVE_COUNT + 1))
	local attempt rc=1 wait_s
	for ((attempt = 1; attempt <= attempts; attempt++)); do
		if _retry_run "$timeout_s" "$@"; then
			RETRY_ACTIVE_COUNT=$((RETRY_ACTIVE_COUNT - 1))
			return 0
		else
			# Inside the else, $? is still the wrapped command's status —
			# after the if-statement it would already be reset to 0.
			rc=$?
		fi
		if [ "$attempt" -lt "$attempts" ]; then
			wait_s=$base
			[ "$wait_s" -gt "$max" ] && wait_s=$max
			if [ "$rc" -eq 124 ] && [ -n "$TIMEOUT_BIN" ] && [ "$timeout_s" -gt 0 ]; then
				warn "${desc:-$1} timed out after ${timeout_s}s (attempt $attempt/$attempts) — retrying in ${wait_s}s..."
			else
				warn "${desc:-$1} failed (attempt $attempt/$attempts) — retrying in ${wait_s}s..."
			fi
			sleep "$wait_s"
			base=$((base * 2))
		fi
	done
	RETRY_ACTIVE_COUNT=$((RETRY_ACTIVE_COUNT - 1))
	return "$rc"
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
	# Delegate to native_bin_path: ONE resolver owns the shim-skip logic
	# (no drift between this probe and path resolution), and it keeps
	# scanning past /mnt/* shims to a native candidate later in PATH
	# instead of rejecting on the first hit. This works inside _retry_run's
	# bash -c child because the export whitelist carries native_bin_path
	# and is_wsl (the openSUSE failure was exactly that missing link).
	native_bin_path "$1" >/dev/null
}

# Resolve <cmd> to a NATIVE (Linux) binary path. Under WSL interop the
# Windows PATH is injected with /mnt/* entries that can shadow the native
# one (a Windows npm's "global prefix" is the Windows tree — `npm i -g`
# there installs where Linux tools can never see it), so shim candidates
# are skipped and the next match in PATH wins; the shim pattern defaults
# to /mnt/*.
# Non-WSL: plain `command -v`. POSIX expansions only — also
# emitted into login profiles (may be zsh).
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

# Absolute path to a LINUX sudo, or non-zero. Windows 11 ships an optional
# sudo.exe that WSL interop exposes as /mnt/.../sudo.exe — running it from
# WSL would be meaningless.
native_sudo() {
	# native_bin_path (not plain `command -v`): resolves the sudo path while
	# skipping /mnt/* Windows shims, and keeps working when a distro shim
	# for sudo sits earlier in PATH than the real one.
	native_bin_path sudo
}

is_wsl() {
	case "$(uname -r)" in
	*[Mm]icrosoft*) return 0 ;;
	*) return 1 ;;
	esac
}

# Granular OS id: debian | ubuntu | arch | opensuse | centos | fedora |
# macos | linux-unknown | unknown. Every supported distro is its own id:
# nothing is folded into a neighbour (Ubuntu is NOT Debian, Fedora is NOT
# CentOS), so the package tables below can give each one the names its own
# repositories use. Derivative distros are normalised here, at the only
# place that reads /etc/os-release.
#
# This is also the one place to fold an id into a sibling's rows: an RHEL
# rebuild whose package names match CentOS belongs on the `centos` line
# above, and every package table follows automatically.
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

# Human-readable package manager for the Platform section.
pkg_manager_name() {
	case "${OS:-unknown}" in
	debian | ubuntu) echo "apt" ;;
	arch) echo "pacman" ;;
	opensuse) echo "zypper" ;;
	centos | fedora) echo "dnf" ;;
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

# ────────────── /run/user/$UID repair (sessionless environments) ──────────────
# Where $XDG_RUNTIME_DIR is supposed to come from: at login, pam_systemd
# registers the session with systemd-logind, which creates /run/user/$UID
# (0700, owned by the user) and injects $XDG_RUNTIME_DIR into the session
# environment. No logind session → no directory → tools that write runtime
# files there fail (nvim/vim serverstart, fzf-lua at require time, ...).
#
# WSL2 with `systemd=true` runs systemd as PID 1, but WSL only registers a
# logind session for the distro's DEFAULT user — and WSL falls back to root
# whenever /etc/wsl.conf has no [user] default (arch, anything installed via
# `wsl --import`). Sessionless shells then carry a broken $XDG_RUNTIME_DIR.
#
# Keyed on the symptom rather than on is_wsl(): every sessionless
# environment (WSL, containers, CI, `su` from a root session) hits this, and
# a symptom test survives WSL changing its behaviour on a version bump. On
# an ordinary Linux login session pam_systemd has already created the
# directory and the first test returns — which is the entire point of
# putting it at the top. The real fix is a proper default user — see the
# consuming repos' README, "Precautions" → WSL2.
# The runtime dir for the REAL current user. $XDG_RUNTIME_DIR is inherited
# correctly on normal logins, but under `sudo bash` / `su` it points at the
# OTHER user's /run/user/$UID (root's /run/user/0 behind a sudo install.sh) —
# the repair below would then try to create and verify a directory the real
# user can never own, ending in the misleading "could not create /run/user/0".
runtime_dir_path() {
	local uid
	uid=$(id -u)
	case "$XDG_RUNTIME_DIR" in
	"" | "/run/user/$uid") echo "${XDG_RUNTIME_DIR:-/run/user/$uid}" ;;
	# Another user's /run/user/N: unownable for this uid — ignore it.
	/run/user/*) echo "/run/user/$uid" ;;
	# A deliberate custom path (containers, custom setups): respect it.
	*) echo "$XDG_RUNTIME_DIR" ;;
	esac
}

ensure_xdg_runtime_dir() {
	local uid user dir marker wslconf
	uid=$(id -u)
	user=$(id -un)
	dir=$(runtime_dir_path)
	wslconf=/etc/wsl.conf

	# Already usable — the free path on every normal Linux login.
	if [ -d "$dir" ] && [ -w "$dir" ]; then
		return 0
	fi

	# Everything below needs root — report it once here rather than leaving
	# the user to rediscover it later as a Lua/vim error with no causal
	# trail.
	if [ "$uid" -ne 0 ] && ! have_native_cmd sudo; then
		warn "\$XDG_RUNTIME_DIR ($dir) is missing and no sudo is available — see README 'Precautions' (WSL2 default user)."
		return 0
	fi

	# ── Tier 0: fix the root cause, not just this session ────────────────
	# On WSL the distro boots as root whenever /etc/wsl.conf has no [user]
	# default; declaring the current user (the installer runs as them, so
	# it is the right name) makes future WSL sessions start directly into
	# a real logind session for that user. Only written when default= is
	# absent — an existing configuration (root on purpose, or a different
	# user) is respected. INI-aware, not a blind append: a duplicated or
	# misplaced section can break the distro at boot. Takes effect after
	# `wsl.exe --shutdown`; tiers 1-2 below still repair the current boot.
	if is_wsl && [ "$uid" -ne 0 ]; then
		if sudo_cmd grep -Eq '^[[:space:]]*default[[:space:]]*=' "$wslconf" 2>/dev/null; then
			: # a default user is already declared — respect the existing choice
		elif sudo_cmd grep -q '^\[user\]' "$wslconf" 2>/dev/null; then
			# [user] section exists without a default: insert right after
			# its header — appending at EOF would land in the last section.
			info "WSL boots as root (no default user) — setting $user in $wslconf..."
			if sudo_cmd sed -i "/^\[user\]/a default=${user}" "$wslconf"; then
				ok "WSL default user set to $user — effective after 'wsl.exe --shutdown'; the tiers below still repair the current boot."
			else
				warn "could not update $wslconf — add '[user] default=$user' manually (see README 'Precautions' → WSL2)."
			fi
		else
			info "WSL boots as root (no default user) — setting $user in $wslconf..."
			if printf '\n[user]\ndefault=%s\n' "$user" | sudo_cmd tee -a "$wslconf" >/dev/null; then
				ok "WSL default user set to $user — effective after 'wsl.exe --shutdown'; the tiers below still repair the current boot."
			else
				warn "could not update $wslconf — add '[user] default=$user' manually (see README 'Precautions' → WSL2)."
			fi
		fi
	fi

	# Tiers 1-2 need systemd: without it there is no logind to create
	# /run/user at all — that variant is wsl-init's problem (stop
	# exporting $XDG_RUNTIME_DIR for a directory that is never created).
	have_native_cmd systemctl || return 0

	info "Repairing \$XDG_RUNTIME_DIR ($dir) — no login session here, so logind never created it."

	# Tier 1: enable lingering for this user. That makes systemd-logind
	# start user@$UID.service at boot, which pulls in
	# user-runtime-dir@$UID.service and gets the directory created with
	# logind's own 0700 mode — and repairs the user manager, so user dbus
	# and gpg-agent work afterwards too. loginctl is the supported
	# interface but registers the change against a seat, and WSL has no
	# VT: on Debian 13 the seat daemon is the separate `seatd` package, so
	# enable-linger fails with ENXIO ("No such device or address"). When it
	# does, write the marker it would have written: that file IS the
	# on-disk state enable-linger exists to produce, and systemd-logind
	# reads it back at boot without ever consulting a seat.
	marker="/var/lib/systemd/linger/$user"
	if have_native_cmd loginctl && loginctl enable-linger "$user" >/dev/null 2>&1; then
		ok "Enabled lingering for $user."
	elif sudo_cmd mkdir -p "$(dirname "$marker")" >/dev/null 2>&1 &&
		sudo_cmd touch "$marker" >/dev/null 2>&1; then
		ok "Enabled lingering for $user via $marker."
	fi

	# Tier 2: create the directory now rather than at the next boot.
	# user@.service only orders itself After=user-runtime-dir@%i.service —
	# ordering, not a dependency — so name the runtime-dir unit explicitly
	# and fall back to the user manager, which logind handles either way.
	sudo_cmd systemctl start "user-runtime-dir@$uid.service" >/dev/null 2>&1 ||
		sudo_cmd systemctl start "user@$uid.service" >/dev/null 2>&1 || true

	if [ -d "$dir" ] && [ -w "$dir" ]; then
		ok "\$XDG_RUNTIME_DIR is ready ($dir)."
		return 0
	fi

	# Only reachable when both tiers failed outright (no logind/seatd): the
	# directory stays broken for this session, so spell out both the
	# boot-time fix and the immediate one.
	warn "Could not create $dir — nvim/vim serverstart() will keep failing (fzf-lua and other RPC users)."
	warn "  Manual fix:  sudo touch $marker && sudo systemctl start user-runtime-dir@$uid.service"
}

# Insert <dir> into $PATH immediately BEFORE the WSL interop section (the
# /mnt/* entries WSL appends at session start). Brew tools then beat Windows
# shims (npm/node: the Windows npm's "global prefix" is the Windows tree —
# `npm i -g` there installs where Linux tools can never see it), while
# system paths keep precedence over brew (the append design's whole point).
# Falls back to a plain append when the PATH carries no Windows section
# (non-WSL, or interop disabled). Idempotent. POSIX expansions only: the
# same loop is emitted into login profiles, which may be zsh (no word
# splitting on unquoted $PATH).
path_add_pre_win() {
	local d="$1"
	case ":$PATH:" in *":$d:"*) return 0 ;; esac
	case $PATH in
	# Windows interop section present: insert brew right before it.
	# %%:/mnt/* keeps everything before the FIRST Windows entry; ${PATH#
	# "$pre":} keeps the Windows section itself. PATH entries cannot
	# contain colons, so the ":/mnt/" boundary is exact.
	*:/mnt/*)
		local pre=${PATH%%:/mnt/*}
		PATH="$pre:$d:${PATH#"$pre":}"
		;;
	# PATH starts inside the Windows section (no Linux entries): brew wins
	# over it by simply going first.
	/mnt/*) PATH="$d:$PATH" ;;
	# No interop section: plain append.
	*) PATH="$PATH:$d" ;;
	esac
	export PATH
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
# run itself.
#
# macOS: TIOCSTI exists (0x80017472 — codex#45119 verified injection
# succeeding on an unsandboxed PTY) and no kernel gate applies, so macOS runs
# the PLAIN attempts — no sudo needed. Sandboxed/Seatbelt contexts deny it
# with EPERM; the surfaced error covers that.
# Linux: the injection ALWAYS runs under sudo — kernel 6.2+ gates TIOCSTI
# behind CAP_SYS_ADMIN (CONFIG_LEGACY_TIOCSTI off — WSL2 ships it off),
# which root carries in the initial namespace, so the sudo run works on
# gated and ungated kernels alike, silently under the installer's NOPASSWD
# drop-in. The controlling terminal survives sudo, so the keys land in the
# same terminal. python3 first, perl as fallback, plain error when both
# are missing.
inject_tty() {
	local cmd="$1" err py3 perlx tiocsti=0x5412 label=""
	[ -n "$cmd" ] || return 1
	# No writable controlling terminal (CI, nested pipes) — nothing to
	# inject into. access(W_OK) on /dev/tty fails with ENXIO when the
	# process has no controlling tty.
	if ! [ -w /dev/tty ]; then
		warn "inject_tty: /dev/tty is not writable — no controlling terminal to inject into."
		return 1
	fi
	py3=$(command -v python3 2>/dev/null)
	perlx=$(command -v perl 2>/dev/null)
	# One implementation, two platforms — only the PREFIX and the perl
	# constant differ:
	#   Linux: kernel 6.2+ gates TIOCSTI behind CAP_SYS_ADMIN
	#          (CONFIG_LEGACY_TIOCSTI off — WSL2 ships it off), so the
	# injection is prefixed with sudo — root carries the capability,
	# and the NOPASSWD drop-in keeps it silent during installs.
	#   macOS: no gate — plain run; sudo would only add a password prompt.
	# The controlling terminal survives sudo, so the keys land in the same
	# terminal either way.
	local -a runner=()
	if [ "$(uname -s)" != Darwin ] && have_native_cmd sudo; then
		runner=(sudo_cmd)
		label=" (via sudo)"
	fi
	[ "$(uname -s)" = Darwin ] && tiocsti=0x80017472
	if [ -n "$py3" ]; then
		# termios.TIOCSTI carries the per-platform constant automatically.
		if err=$(${runner[@]+"${runner[@]}"} "$py3" -c 'import sys,os,fcntl,termios
cmd = sys.argv[1] + "\n"
fd = os.open("/dev/tty", os.O_WRONLY)
for b in cmd.encode():
    buf = bytearray(1); buf[0] = b
    fcntl.ioctl(fd, termios.TIOCSTI, buf)' "$cmd" 2>&1); then
			ok "injected${label}."
			return 0
		fi
	fi
	if [ -n "$perlx" ]; then
		if err=$(${runner[@]+"${runner[@]}"} "$perlx" -e '
			my ($cmd, $tio) = @ARGV;
			open(my $tty, ">", "/dev/tty") or die "open /dev/tty: $!\n";
			for my $ch (split //, $cmd . "\n") {
				ioctl($tty, hex($tio), $ch) or die "TIOCSTI ioctl failed: $!\n";
			}
		' "$cmd" "$tiocsti" 2>&1); then
			ok "injected${label}."
			return 0
		fi
	fi
	warn "inject_tty failed: ${err:-python3/perl not found}"
	return 1
}
