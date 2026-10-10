# monkey-scripts/lib/common.sh — colors, logging, retry, platform probes.
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

# ────────────────────── nested-retry guard ──────────────────────
# Exported: the nesting crosses a PROCESS boundary (run_checkhealth retries
# `bash checkhealth.sh --install`, whose child re-enters retry). While any
# outer retry is active (count > 0), an inner retry runs its command ONCE —
# the outer loop already bounds the attempts.
RETRY_ACTIVE_COUNT=${RETRY_ACTIVE_COUNT:-0}
export RETRY_ACTIVE_COUNT

# Per-attempt timeout binary: GNU timeout, gtimeout on macOS, empty = run
# unguarded (a silent hang is recoverable by hand; a broken run is not).
if command -v timeout >/dev/null 2>&1; then
	TIMEOUT_BIN=timeout
elif command -v gtimeout >/dev/null 2>&1; then
	TIMEOUT_BIN=gtimeout
else
	TIMEOUT_BIN=""
fi

# Kill-after grace: SIGTERM alone can be ignored (pacman mid-write, brew's
# ruby) and would hang the timeout forever. Unset defaults to 30s; EMPTY
# disables the escalation (-k omitted entirely).
RETRY_KILL_AFTER=${RETRY_KILL_AFTER-30}

# Parallel-jobs default for source builds. An exported JOBS always wins.
JOBS=${JOBS:-$(nproc 2>/dev/null || echo 4)}

# retry's execution helper. $1 = timeout seconds ("0" disables), rest =
# command. timeout(1) can only exec binaries, so a function-first command
# re-enters through a child bash with the function (and its helpers)
# exported; everything else goes to the timeout binary directly.
_retry_run() {
	local t="$1"
	shift
	if [ -z "$TIMEOUT_BIN" ] || [ "$t" -eq 0 ]; then
		"$@"
		return
	fi
	local -a ka=()
	# -k only when configured: `-k ""` is rejected with rc 125.
	if [ -n "$RETRY_KILL_AFTER" ]; then
		ka=(-k "$RETRY_KILL_AFTER")
	fi
	if declare -F "$1" >/dev/null 2>&1; then
		local fn
		# The whitelist must carry the WHOLE dependency closure of the
		# wrapped command (sudo_cmd -> native_sudo -> have_native_cmd ->
		# native_bin_path -> is_wsl): one missing link made every exported
		# call die with "command not found" in the child.
		for fn in "$1" retry _retry_run native_sudo have_native_cmd native_bin_path is_wsl warn; do
			declare -F "$fn" >/dev/null 2>&1 && export -f "$fn"
		done
		"$TIMEOUT_BIN" ${ka[@]+"${ka[@]}"} "$t" bash -c '"$@"' _ "$@"
	else
		"$TIMEOUT_BIN" ${ka[@]+"${ka[@]}"} "$t" "$@"
	fi
}

# ──────────────────────────── retry ────────────────────────────
# Retry wrapper for every network-flavoured command (downloads, git, package
# managers): exponential backoff (15s→30s→60s→120s) plus a per-attempt
# timeout — a black-holed connection would otherwise hang the installer
# forever. rc 124 is timeout's own exit code.
#
# Usage: retry [-n attempts] [-d base_delay] [-m max_delay] [-t timeout]
#              [-s desc] cmd...
#   -n  total attempts, NOT retries (default 5)
#   -d  first sleep in seconds (default 15)
#   -m  sleep cap in seconds (default 120)
#   -t  per-attempt timeout in seconds (default 600; 0 disables) — pass a
#       larger value for legitimately long operations (package installs,
#       big clones)
#   -s  human description for the warning line (default: the command)
# Returns the command's last exit code (124 = timed out). Safe under set -e;
# cmd's own flags are untouched — getopts stops at the first non-option
# word, so only the leading -n/-d/-m/-t/-s belong to retry.
retry() {
	local attempts=5 base=15 max=120 timeout_s=600 desc=""
	local opt
	# A leading -- may guard a wrapped command that itself starts with an
	# option-looking word; strip it BEFORE parsing.
	[ "${1:-}" = "--" ] && shift
	# OPTIND=1: getopts resumes at $OPTIND on the next call in the same
	# shell — without the reset a second retry() call misparses.
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
	# Nested call (see RETRY_ACTIVE_COUNT): run once, no sleeps.
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
			# Inside the else, $? is still the wrapped command's status.
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

# ──────────────────────────── platform ────────────────────────────
require_home() {
	# Never let a missing HOME fail later under `set -u`.
	[ -n "${HOME:-}" ] || die "\$HOME is not set — cannot determine install locations."
}

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

# ────────────── /run/user/$UID repair (sessionless environments) ──────────────
# $XDG_RUNTIME_DIR comes from pam_systemd at login (logind creates
# /run/user/$UID 0700). Sessionless shells — WSL2 (it registers a logind
# session only for the distro's DEFAULT user, falling back to root without
# a /etc/wsl.conf [user] default), containers, CI, `su` — have none, and
# tools that write runtime files there fail (nvim/vim serverstart,
# fzf-lua, ...). Keyed on the SYMPTOM, not is_wsl(); the real fix is a
# proper default user (see consuming repos' README, "Precautions" → WSL2).
# runtime_dir_path resolves the dir for the REAL current user: under
# `sudo bash` / `su` $XDG_RUNTIME_DIR points at the OTHER user's
# /run/user/$UID — unownable, and repairing it would end in the misleading
# "could not create /run/user/0".
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

	# Everything below needs root — report it here rather than letting the
	# user rediscover it later as a Lua/vim error with no causal trail.
	if [ "$uid" -ne 0 ] && ! have_native_cmd sudo; then
		warn "\$XDG_RUNTIME_DIR ($dir) is missing and no sudo is available — see README 'Precautions' (WSL2 default user)."
		return 0
	fi

	# ── Tier 0: fix the root cause ───────────────────────────────────────
	# WSL boots as root whenever /etc/wsl.conf has no [user] default;
	# declaring the current user gives future sessions a real logind
	# session. Only written when default= is absent; INI-aware (a
	# duplicated/misplaced section can break the boot). Effective after
	# `wsl.exe --shutdown`; tiers 1-2 repair the current boot.
	if is_wsl && [ "$uid" -ne 0 ]; then
		if sudo_cmd grep -Eq '^[[:space:]]*default[[:space:]]*=' "$wslconf" 2>/dev/null; then
			: # a default user is already declared — respect the existing choice
		elif sudo_cmd grep -q '^\[user\]' "$wslconf" 2>/dev/null; then
			# Insert right after the [user] header — appending at EOF would
			# land in the last section.
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

	# Tiers 1-2 need systemd; without it nothing can create /run/user here.
	have_native_cmd systemctl || return 0

	info "Repairing \$XDG_RUNTIME_DIR ($dir) — no login session here, so logind never created it."

	# Tier 1: enable lingering — user@$UID.service at boot pulls in
	# user-runtime-dir@$UID.service and creates the directory (0700), and
	# repairs the user manager (dbus, gpg-agent). loginctl fails with ENXIO
	# where the seat daemon is `seatd` (Debian 13, WSL has no VT): then
	# write the linger marker directly — it IS the on-disk state
	# enable-linger exists to produce.
	marker="/var/lib/systemd/linger/$user"
	if have_native_cmd loginctl && loginctl enable-linger "$user" >/dev/null 2>&1; then
		ok "Enabled lingering for $user."
	elif sudo_cmd mkdir -p "$(dirname "$marker")" >/dev/null 2>&1 &&
		sudo_cmd touch "$marker" >/dev/null 2>&1; then
		ok "Enabled lingering for $user via $marker."
	fi

	# Tier 2: create the directory now. Name the runtime-dir unit explicitly
	# (user@.service only ORDERS After=user-runtime-dir@%i) and fall back to
	# the user manager.
	sudo_cmd systemctl start "user-runtime-dir@$uid.service" >/dev/null 2>&1 ||
		sudo_cmd systemctl start "user@$uid.service" >/dev/null 2>&1 || true

	if [ -d "$dir" ] && [ -w "$dir" ]; then
		ok "\$XDG_RUNTIME_DIR is ready ($dir)."
		return 0
	fi

	# Both tiers failed (no logind/seatd) — spell out both fixes.
	warn "Could not create $dir — nvim/vim serverstart() will keep failing (fzf-lua and other RPC users)."
	warn "  Manual fix:  sudo touch $marker && sudo systemctl start user-runtime-dir@$uid.service"
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
# -V, -v (tmux only answers -V); the caller-supplied regex lets suffix
# versions ("3.7b") survive — default is plain X.Y.
extract_version() {
	local bin="$1" regex="${2:-[0-9]+\.[0-9]+}" flag ver="" out
	for flag in --version -V -v; do
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
	ver=$(extract_version "$bin" "${3:-[0-9]+\.[0-9]+}")
	[ -n "$ver" ] || return 1
	version_ge "$ver" "$min"
}

# ────────────────────── TIOCSTI injection ──────────────────────
# Type <cmd> + newline into the controlling terminal: the parent shell
# executes it after this script (and any wrapper chaining it) has fully
# exited, so injection can never disturb the run itself.
#   Linux: kernel 6.2+ gates TIOCSTI behind CAP_SYS_ADMIN (CONFIG_LEGACY_
#     TIOCSTI off — WSL2 ships it off), so the injection always runs under
#     sudo (silent under the NOPASSWD drop-in). The TARGET tty is resolved
#     by path (TIOCSTI_TTY), never /dev/tty: sudo >= 1.9.14 (use_pty) runs
#     the command in its own pty, and bytes injected into /dev/tty there
#     die with sudo — rc 0 regardless, which is how the silent no-op
#     slipped past every check (the bug the TIOCSTI_TTY plumbing fixes).
#   macOS: TIOCSTI exists and no kernel gate applies — verified injection
#     succeeding on an unsandboxed PTY (codex#45119); sandboxed/Seatbelt
#     contexts deny it with EPERM (surfaced as a failure). Plain run —
#     sudo would only add a password prompt.
# python3 first, perl as fallback, plain error when both are missing.

# ────────────────────── interactive-reader guard ──────────────────────
# A succeeding ioctl only proves the bytes entered the tty input queue —
# someone must READ it afterwards. Without an interactive shell behind the
# terminal (SSH one-shots, piped harness runs) the pty dies and the queued
# command evaporates while the log says OK (observed on an openSUSE
# Tumbleweed VM run, 2026-10). The guard walks the ancestor chain for an
# interactive shell whose fd 0 is our controlling tty, and refuses to
# inject without one. `ps` is the single source of truth on every platform
# (`args=` / `ppid=`; -ww disables width truncation).

_is_interactive_shell() {
	# Interactive = argv0 is a shell and every remaining argument is a pure
	# option flag (`zsh -i` sits at a prompt; `zsh -c cmd` never does).
	# Known limit: ps flattens quoting, so a flag with a SEPARATE value word
	# (zsh -o SOMETHING) reads as a positional — real interactive shells are
	# launched bare, so this never bites in practice.
	local -a words
	# Plain heredoc, NOT a herestring (`<<<`): legacy sh.vim (nvim/vim
	# without tree-sitter for sh) parses `<<<` as a heredoc BEGIN whose
	# delimiter never matches, rendering EVERY following line as one
	# unterminated heredoc (observed: the rest of this file highlighted as
	# shHereDoc, 2026-10). `read -a` splits on IFS whitespace identically.
	local ps_out
	ps_out=$(ps -ww -o args= -p "$1" 2>/dev/null)
	read -r -a words <<EOF
$ps_out
EOF
	((${#words[@]} > 0)) || return 1
	local prog="${words[0]##*/}" a
	prog="${prog#-}" # login shells carry a leading dash ("-zsh")
	case "$prog" in
	zsh | bash | sh | dash | ksh | mksh | fish | csh | tcsh) ;;
	*) return 1 ;;
	esac
	for a in "${words[@]:1}"; do
		case "$a" in
		-c | --command | --eval) return 1 ;;
		--) return 1 ;;
		-*) ;;         # pure flag (-i, -l, --norc, ...)
		*) return 1 ;; # positional: a script file or inline command
		esac
	done
	return 0
}

# _stdin_tty_of <pid> — what <pid> has open on fd 0, empty when unknown.
# lsof covers macOS too; Linux falls back to a /proc readlink.
_stdin_tty_of() {
	if command -v lsof >/dev/null 2>&1; then
		lsof -a -p "$1" -d 0 -Fn 2>/dev/null | sed -n 's/^n//p' | head -n 1
	elif [ -d "/proc/$1" ]; then
		readlink "/proc/$1/fd/0" 2>/dev/null
	fi
}

_has_interactive_reader() {
	# Block only on POSITIVE knowledge; any ps trouble means "cannot judge"
	# — inject as before.
	command -v ps >/dev/null 2>&1 || return 0
	local my_tty pid ppid fd0 n=0
	# Our controlling tty, exported as TIOCSTI_TTY: inject_tty must NOT
	# reopen /dev/tty under sudo — sudo >= 1.9.14 (use_pty) gives the child
	# a private pty, and bytes injected there die with sudo.
	my_tty=$(ps -o tty= -p "$$" 2>/dev/null)
	my_tty="${my_tty//[[:space:]]/}"
	TIOCSTI_TTY=""
	[ -n "$my_tty" ] && TIOCSTI_TTY="/dev/$my_tty"
	pid=$$
	while [ "$pid" -gt 1 ] && [ "$n" -lt 25 ]; do
		if _is_interactive_shell "$pid"; then
			# ...AND it must actually read the terminal: an interactive-
			# LOOKING shell with a pipe on fd 0 (`zsh -i < feeder`) never
			# consumes the tty queue — the false positive that logged
			# "injected (via sudo)" while nothing executed. An empty
			# _stdin_tty_of answer (dead/foreign PID) just fails the match.
			fd0=$(_stdin_tty_of "$pid")
			if [ -n "$my_tty" ] && { [ "$fd0" = "/dev/$my_tty" ] || [ "$fd0" = "/dev/tty" ]; }; then
				return 0
			fi
		fi
		ppid=$(ps -o ppid= -p "$pid" 2>/dev/null) || return 0
		ppid="${ppid//[!0-9]/}"
		[ -n "$ppid" ] || return 0
		pid=$ppid
		n=$((n + 1))
	done
	return 1
}

inject_tty() {
	local cmd="$1" err py3 perlx tiocsti=0x5412 label=""
	[ -n "$cmd" ] || return 1
	# Reader guard first: without a consumer the injection is a silent
	# no-op, however many ioctls "succeed".
	if ! _has_interactive_reader; then
		warn "no interactive shell is attached to this terminal — skipping injection; run: $cmd"
		return 1
	fi
	# No writable controlling terminal (CI, nested pipes).
	if ! [ -w /dev/tty ]; then
		warn "inject_tty: /dev/tty is not writable — no controlling terminal to inject into."
		return 1
	fi
	py3=$(command -v python3 2>/dev/null)
	perlx=$(command -v perl 2>/dev/null)
	# One implementation, two platforms — only the prefix (sudo_cmd on
	# Linux) and the perl constant differ. The TARGET is TIOCSTI_TTY, never
	# /dev/tty under sudo (see _has_interactive_reader).
	local target="${TIOCSTI_TTY:-/dev/tty}"
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
fd = os.open(sys.argv[2], os.O_WRONLY)
for b in cmd.encode():
    buf = bytearray(1); buf[0] = b
    fcntl.ioctl(fd, termios.TIOCSTI, buf)' "$cmd" "$target" 2>&1); then
			ok "injected via python3${label}."
			return 0
		fi
	fi
	if [ -n "$perlx" ]; then
		if err=$(${runner[@]+"${runner[@]}"} "$perlx" -e '
			my ($cmd, $tio, $tty_path) = @ARGV;
			open(my $tty, ">", $tty_path) or die "open $tty_path: $!\n";
			for my $ch (split //, $cmd . "\n") {
				ioctl($tty, hex($tio), $ch) or die "TIOCSTI ioctl failed: $!\n";
			}
		' "$cmd" "$tiocsti" "$target" 2>&1); then
			ok "injected via perl${label}."
			return 0
		fi
	fi
	warn "inject_tty failed: ${err:-python3/perl not found}"
	return 1
}
