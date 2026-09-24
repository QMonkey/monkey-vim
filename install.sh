#!/usr/bin/env bash
set -euo pipefail

# ──────────────────────────────────────────────────────────────
# monkey-vim one-shot installer
# Usage: curl -fsSL https://raw.githubusercontent.com/QMonkey/monkey-vim/master/install.sh | bash
# ──────────────────────────────────────────────────────────────

readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

readonly INSTALL_DIR="${INSTALL_DIR:-$HOME/Documents/monkey-vim}"
readonly VIM_SRC_DIR="${VIM_SRC_DIR:-$HOME/Documents/vim}"
readonly JOBS="${JOBS:-$(nproc 2>/dev/null || echo 4)}"
readonly SUDOERS_D_DIR="${SUDOERS_D_DIR:-/etc/sudoers.d}"
SUDO_NOPASSWD=0
readonly NOPASSWD_DROPIN="$SUDOERS_D_DIR/zz-monkey-vim-nopasswd"

# Never let a missing HOME fail later under `set -u`.
[ -n "${HOME:-}" ] || {
	echo "[FAIL] \$HOME is not set — cannot determine install locations." >&2
	exit 1
}

info() { echo -e "${CYAN}[INFO]${NC}  $*"; }
ok() { echo -e "${GREEN}[  OK]${NC}  $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC}  $*"; }
fail() {
	echo -e "${RED}[FAIL]${NC}  $*"
	exit 1
}

# ────────────────── OS / WSL detection ──────────────────

os_detect() {
	case "$(uname -s)" in
	Linux)
		if [ -f /etc/os-release ]; then
			# shellcheck disable=SC1091
			. /etc/os-release
			case "${ID:-}" in
			ubuntu | debian | linuxmint | pop | elementary | zorin) echo "debian" ;;
			arch | manjaro | endeavouros) echo "arch" ;;
			opensuse* | suse | sles) echo "opensuse" ;;
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

# True under WSL (1 or 2): both kernels carry "microsoft" in the release
# string (WSL1 "...-Microsoft", WSL2 "...-microsoft-standard-WSL2").
# uname -r works everywhere — macOS has no /proc and reports a Darwin
# release (no match). Unlike the WSL_* env vars it does not depend on the
# shell or exec context inheriting them.
is_wsl() {
	case "$(uname -r)" in
	*[Mm]icrosoft*) return 0 ;;
	*) return 1 ;;
	esac
}

# WSL interop appends the WINDOWS PATH to ours, so tools installed on the
# Windows side (node, python, sudo.exe, ...) appear as /mnt/c/... shims.
# They are not Linux binaries and root's secure_path cannot see them —
# treat /mnt/* resolutions as "not installed" so the real Linux packages
# get installed instead.
have_native_cmd() {
	command -v "$1" &>/dev/null || return 1
	case "$(command -v "$1")" in
	/mnt/*) return 1 ;; # WSL Windows-interop shim
	esac
	return 0
}

# Absolute path to a LINUX sudo, or non-zero.
native_sudo() {
	local p
	have_native_cmd sudo || return 1
	p=$(command -v sudo)
	printf '%s' "$p"
}

OS=$(os_detect)
readonly OS

# TIOCSTI injection right: a chaining wrapper may pre-set this to its
# own name — then THIS script must not inject. Standalone runs self-claim.
readonly ACQUIRE_TIOCSTI="${ACQUIRE_TIOCSTI:-monkey-vim}"

sudo_cmd() {
	# Lazy re-auth: Homebrew resets the sudo timestamp on EVERY invocation
	# (brew.sh runs `sudo --reset-timestamp` at startup), so a ticket that
	# was valid a minute ago can be dead here. Re-authenticate proactively
	# with an explanatory prompt instead of letting the command fail or
	# spring a context-free password prompt. `-n true` never prompts; the
	# interactive `-v` only runs when the ticket is actually gone.
	local sudo_bin
	sudo_bin=$(native_sudo) || {
		"$@"
		return
	}
	if ! "$sudo_bin" -n true 2>/dev/null; then
		"$sudo_bin" -v -p "[monkey-vim] sudo credentials needed to continue — enter your password: " || return 1
	fi
	"$sudo_bin" "$@"
}

# ────────────────── TIOCSTI injection ──────────────────
# Type <cmd> + newline into the controlling terminal: the parent shell
# executes it as if the user had typed it — AFTER this script (and any
# wrapper chaining it) has fully exited, so injection can never disturb
# the run itself. Needs python3 or perl; any failure returns non-zero so
# callers can fall back to a printed hint. Never fatal.
inject_tty() {
	local cmd="$1" tiocsti
	[ -n "$cmd" ] || return 1
	# No writable controlling terminal (CI, nested pipes) — nothing to
	# inject into. access(W_OK) on /dev/tty fails with ENXIO when the
	# process has no controlling tty.
	[ -w /dev/tty ] || return 1
	# python3 first: termios.TIOCSTI carries the correct constant per
	# platform (Linux 0x5412, Darwin 0x80047412).
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

# Print the shell startup files for the detected shell. Two cases:
#   - zsh: profile ONLY (~/.zprofile). rc files like ~/.zshrc are often
#     repo-managed dotfiles — appending to them dirties the repo; non-login
#     zsh shells get the profile via a `source ~/.zprofile` guard in the rc file instead.
#   - bash: profile AND rc (~/.profile + ~/.bashrc). Non-login interactive
#     bash (WSL's wsl.exe, desktop terminal emulators, VS Code terminal)
#     only reads ~/.bashrc — .profile does not get pulled in there — so both files are needed.
shell_env_files() {
	# The TARGET login shell, queried from the user database: on a
	# zsh-default machine (or after the login shell has been switched to
	# zsh) it is zsh and the env blocks belong in ~/.zprofile; on bash
	# machines they land in the bash profile files. Falls back to $SHELL,
	# then bash (macOS has no getent; its $SHELL already reflects the
	# login shell).
	local shell
	# getent does not exist on macOS — guard the call, otherwise the
	# command-not-found failure (127) would trip `set -e` and kill the
	# script before the dscl fallback below ever runs.
	if have_native_cmd getent; then
		shell=$(getent passwd "$(id -un)" 2>/dev/null | cut -d: -f7)
	fi
	if [ -z "$shell" ] && [ "$(uname -s)" = Darwin ]; then
		# No getent on macOS — query the directory service instead ($SHELL
		# is a login-time snapshot and goes stale right after a chsh in
		# the same session).
		shell=$(dscl . -read /Users/"$(id -un)" UserShell 2>/dev/null | awk '{print $2}')
	fi
	shell=${shell:-${SHELL:-bash}}
	shell=${shell##*/}
	shell="${shell##*/}"
	case "$shell" in
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

# ────────────────── sudo setup (auth + drop-ins + keepalive) ──────────────────

SUDO_KEEPALIVE_PID=""
SUDO_BIN=""

cleanup_sudo() {
	# Kill the keepalive (if running) and remove the temporary NOPASSWD
	# drop-in. `sudo -n rm` works while NOPASSWD is still in place — the
	# file grants it, so removal never needs a password. State flags are
	# reset so a second call (explicit from main + the EXIT trap) is a
	# no-op. The `|| true` guards matter under set -e: `wait` reports
	# 128+SIGTERM for a killed keepalive and `kill` fails on an already
	# dead one — either would abort the drop-in removal below.
	if [ -n "$SUDO_KEEPALIVE_PID" ]; then
		kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true
		wait "$SUDO_KEEPALIVE_PID" 2>/dev/null || true
		SUDO_KEEPALIVE_PID=""
	fi
	if [ "$SUDO_NOPASSWD" -eq 1 ] && [ -n "$SUDO_BIN" ]; then
		"$SUDO_BIN" -n rm -f "$NOPASSWD_DROPIN" 2>/dev/null ||
			warn "could not remove the NOPASSWD drop-in — remove it manually: sudo rm $NOPASSWD_DROPIN"
	fi
	SUDO_NOPASSWD=0
}

setup_sudo() {
	# Keep sudo credentials alive for the whole run: the gap between the first
	# sudo (build deps) and later ones (make install) can exceed the default
	# 15-min timestamp_timeout on slow downloads/compiles. A re-auth prompt
	# then aborts unattended runs (no TTY to answer it).
	# Skip when running as root or when no native sudo is available.
	SUDO_BIN=$(native_sudo) || return 0
	if [ "$(id -u)" -eq 0 ]; then
		return 0
	fi
	# Pre-authenticate so the password is entered at the very start instead
	# of mid-run after a long download/compile, then grant NOPASSWD for the
	# rest of the run:
	#
	# Probe first (`-n true`, a command): when credentials are already
	# valid — this run's own drop-in from a previous stage, or an outer
	# installer's grant — skip the authenticate step entirely; chained
	# stages never re-prompt. Failure means no valid grant exists and
	# `sudo -v` prompts for the one password of the run.
	#
	# Why the drop-in is NOPASSWD: authentication is granted by the rule
	# itself and the timestamp is never consulted, so brew's
	# --reset-timestamp, clock jumps and plain expiry are all harmless.
	# GNU sudo resolves conflicting rules last-match-wins, so this drop-in
	# (parsed after the distro's password-required rule) always wins.
	# sudo-rs would defeat this tag for VALIDATE (max_by_key picks the
	# password-required rule) — but every sudo in this script is a command
	# or the probe, where NOPASSWD wins on both implementations.
	if ! "$SUDO_BIN" -n true 2>/dev/null; then
		"$SUDO_BIN" -v || fail "sudo authorization failed — run this script in an interactive terminal."
	fi
	# Scoped to the invoking user and REMOVED on exit (incl. Ctrl-C);
	# if the script is SIGKILLed the file survives — remove manually with
	# `sudo rm $NOPASSWD_DROPIN`. If you prefer a permanent passwordless
	# sudo, add the same line to your own sudoers drop-in instead.
	if printf '%s ALL=(ALL) NOPASSWD: ALL\n' "$(id -un)" |
		"$SUDO_BIN" -n sh -c 'umask 077; cat >"$1" && chmod 0440 "$1" && visudo -c -f "$1" >/dev/null 2>&1 || { rm -f "$1"; exit 1; }' sh "$NOPASSWD_DROPIN" >/dev/null 2>&1; then
		SUDO_NOPASSWD=1
		ok "Temporary NOPASSWD drop-in installed for this run (auto-removed on exit)."
	else
		warn "could not install the temporary NOPASSWD drop-in — falling back to keepalive + lazy re-auth."
	fi
	if [ "$SUDO_NOPASSWD" -eq 0 ]; then
		# Fallback when NOPASSWD could not be installed: refresh the ticket
		# in the background so plain expiry does not prompt mid-run. It
		# cannot fully protect the run — brew resets the ticket by design
		# and WSL clock steps disable it — so when this stops, sudo_cmd()
		# re-authenticates lazily (one explanatory prompt) at the next
		# privileged call.
		(
			# 60s refresh against the 15-min default timeout leaves a 15x
			# margin; override via SUDO_KEEPALIVE_INTERVAL if needed.
			interval="${SUDO_KEEPALIVE_INTERVAL:-60}"
			# Kill the in-flight `sleep` child when TERMed, and wait() to
			# reap — WSL's init does not reap adopted zombies.
			trap 'kill $(jobs -p) 2>/dev/null; wait 2>/dev/null; exit 0' TERM
			while true; do
				sleep "$interval" &
				wait "$!" 2>/dev/null || exit 0
				if ! "$SUDO_BIN" -n true 2>/dev/null; then
					warn "sudo keepalive stopped — expected after a brew run; the next privileged command re-authenticates."
					exit 0
				fi
			done
		) &
		SUDO_KEEPALIVE_PID=$!
	fi
	# Recycle the background loop and drop the NOPASSWD grant on any exit
	# path (success, fail, Ctrl-C).
	trap cleanup_sudo EXIT
	trap 'exit 130' INT
	trap 'exit 143' TERM
}

# ────────────────── package index refresh & install ──────────────────
# Refresh the package index before installing: a stale or missing index is
# the usual cause of "Unable to locate package" on freshly provisioned
# machines. Retried once for transient network failures; a failed refresh
# is never fatal — the install step still runs. Guarded to at most one
# refresh per run — call freely before every install.
PKG_DB_REFRESHED=0
refresh_pkg() {
	[ "$PKG_DB_REFRESHED" -eq 1 ] && return 0
	PKG_DB_REFRESHED=1
	local attempt
	for attempt in 1 2; do
		case "$OS" in
		debian) sudo_cmd apt-get update ;;
		arch) sudo_cmd pacman -Sy ;;
		opensuse) sudo_cmd zypper --non-interactive refresh ;;
		centos) sudo_cmd dnf makecache -q ;;
		macos | *) return 0 ;;
		esac && return 0
		[ "$attempt" -lt 2 ] && sleep 2
	done
	return 0
}

# ────────────────── Step 1: Install build deps for Vim ──────────────────

install_vim_build_deps() {
	info "Installing Vim build dependencies..."
	refresh_pkg
	case "$OS" in
	debian)
		common=(git curl build-essential
			libwayland-dev libcairo2-dev
			libgpm-dev libncurses-dev
			python3-dev lua5.4 liblua5.4-dev
			perl libperl-dev ruby ruby-dev)
		if is_wsl; then
			gui=(libgtk-3-dev libx11-dev libxt-dev libxpm-dev)
		else
			# Non-WSL: prefer GTK4 (no X11 dependency)
			gui=(libgtk-4-dev)
		fi
		sudo_cmd apt-get install -y "${common[@]}" "${gui[@]}"
		;;
	arch)
		common=(base-devel git curl
			wayland gpm ncurses
			lua perl python ruby)
		if is_wsl; then
			gui=(gtk3 libx11 libxt libxpm)
		else
			gui=(gtk4)
		fi
		sudo_cmd pacman -S --needed --noconfirm "${common[@]}" "${gui[@]}"
		;;
	opensuse)
		sudo_cmd zypper --non-interactive install -y -t pattern devel_basis
		# Leap 16 names: python-devel and perl-devel do not exist (python3
		# needs -devel-suffixed python3-devel only; perl headers ship in the
		# main perl package), and xorg-x11-devel was removed — use the
		# individual libX*-devel packages. One unknown name aborts the whole
		# zypper transaction, so these must resolve exactly.
		common=(git curl
			wayland-devel cairo-devel
			gpm-devel ncurses-devel
			python3-devel
			ruby-devel lua-devel perl)
		if is_wsl; then
			gui=(gtk3-devel libX11-devel libXpm-devel libXt-devel)
		else
			gui=(gtk4-devel)
		fi
		sudo_cmd zypper --non-interactive install -y "${common[@]}" "${gui[@]}"
		;;
	centos)
		sudo_cmd dnf install -y epel-release || true
		common=(gcc make git curl
			wayland-devel cairo-devel
			gpm-devel ncurses-devel
			python3-devel ruby-devel lua-devel
			perl perl-devel perl-ExtUtils-ParseXS
			perl-ExtUtils-CBuilder perl-ExtUtils-Embed)
		if is_wsl; then
			gui=(gtk3-devel libX11-devel libXpm-devel libXt-devel)
		else
			gui=(gtk4-devel)
		fi
		sudo_cmd dnf install -y "${common[@]}" "${gui[@]}"
		;;
	macos)
		# Terminal-only build (--enable-gui=no); no gtk/cairo needed. git is
		# required regardless — build_vim and clone_monkey_vim both clone.
		if have_native_cmd brew; then
			brew install git python3 ruby lua
		else
			warn "Homebrew not found — cannot install vim build deps. Install it first: https://brew.sh"
		fi
		;;
	*)
		warn "Unknown OS ($OS). Attempting to continue with whatever is available."
		;;
	esac
	hash -r # re-scan PATH: fresh binaries must not be shadowed by cached shim paths
	ok "Build dependencies installed."
}

# ────────────────── Step 2: Install Homebrew / Linuxbrew ──────────────────

install_linuxbrew() {
	local brew_prefix="" cand
	if have_native_cmd brew; then
		brew_prefix="$(dirname "$(dirname "$(command -v brew)")")"
		ok "Homebrew already installed at $brew_prefix."
	else
		# brew may exist at a standard prefix without being on PATH — an
		# earlier monkey-* component installed it and this process did not
		# inherit the profile. Adopt it instead of re-downloading.
		for cand in /home/linuxbrew/.linuxbrew /opt/homebrew /usr/local; do
			if [ -x "$cand/bin/brew" ]; then
				brew_prefix="$cand"
				ok "Homebrew found at $brew_prefix (not on PATH — adopting)."
				break
			fi
		done
	fi
	if [ -z "$brew_prefix" ]; then
		info "Installing Homebrew/Linuxbrew..."
		# NOTE: the installer's exit trap runs `sudo -k` (and the `brew`
		# commands it spawns reset the timestamp too) — that used to require
		# sed-patching the installer, but the temporary NOPASSWD drop-in
		# makes the timestamp irrelevant, so the official installer runs
		# unmodified. If the NOPASSWD drop-in failed to install, the next
		# privileged command simply re-authenticates once (sudo_cmd).
		# Download fully before executing: `curl | bash` would run a
		# truncated script if the connection drops mid-stream.
		local installer="/tmp/homebrew_install.$$.sh"
		local fetched=0 attempt
		# `curl -fsSL -o` is silent: on a slow network the download (and its
		# retries) would look like a hang without this line.
		info "Downloading the Homebrew installer..."
		for attempt in 1 2 3; do
			if curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh -o "$installer"; then
				fetched=1
				break
			fi
			sleep 2
		done
		if [ "$fetched" != 1 ]; then
			warn "Homebrew installer download failed — continuing without Homebrew."
			return 0
		fi
		NONINTERACTIVE=1 /bin/bash "$installer" ||
			warn "Homebrew installer failed — continuing without Homebrew."
		rm -f "$installer"

		for cand in /home/linuxbrew/.linuxbrew /opt/homebrew /usr/local; do
			if [ -x "$cand/bin/brew" ]; then
				brew_prefix="$cand"
				break
			fi
		done
	fi

	if [ -n "$brew_prefix" ]; then
		eval "$("$brew_prefix/bin/brew" shellenv)"
		ok "Homebrew/Linuxbrew ready at $brew_prefix."
		# Persist shellenv for future shells (login + interactive rc).
		# Runs even when brew pre-dates this run: without it, brew-installed
		# tools (node/npm/...) vanish from PATH in new shells. Idempotent —
		# append_env_block skips if the marker is already present.
		# The case guard makes re-sourcing (e.g. a login .profile sourcing
		# .bashrc, both carrying this block) a no-op instead of prepending
		# brew's bin/sbin to PATH twice.
		local line
		line="case \":\$PATH:\" in *\":${brew_prefix}/bin:\"*) ;; *) eval \"\$(${brew_prefix}/bin/brew shellenv)\" ;; esac"
		append_env_block "Homebrew shellenv" "$line"
	else
		warn "brew not found — continuing without Homebrew."
	fi
}

# ────────────────── Step 3: Build Vim from source ──────────────────

check_vim_version() {
	have_native_cmd vim || return 1
	local ver
	ver=$(vim --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+' || true)
	if [[ -z "$ver" ]]; then
		return 1
	fi
	local major minor
	major=${ver%%.*}
	minor=${ver#*.}
	((major > 9 || (major == 9 && minor >= 1)))
}

# Core features every build must have — mirrors our --enable-* flags.
# fontset is deliberately NOT required: it only enables guifontset (multi-font
# sets for the X11/GUI), useless to terminal Vim and often disabled in
# GUI-less distro builds. Clipboard requirements are platform-dependent and
# handled separately below.
VIM_REQUIRED_FEATURES=(cscope lua multi_byte perl python3 ruby terminal)

has_vim_feature() {
	# [+]<feature> must be followed by whitespace or end-of-line, so
	# "clipboard" does not false-match "clipboard_provider".
	# NOT `grep -q`: -q exits on the first match and closes the pipe; if vim
	# is still writing --version output it dies with SIGPIPE (141) and, under
	# pipefail, the feature is falsely reported as missing. Plain grep with
	# stdout to /dev/null reads all input, so vim's writes always succeed.
	vim --version 2>/dev/null | grep -E "[+]${1}([[:space:]]|\$)" >/dev/null
}

# Clipboard requirement per scenario, mirroring what build_vim produces for
# this machine:
#   mac          → +clipboard                 (Darwin/AppKit, no X11/Wayland)
#   WSL          → +clipboard + +xterm_clipboard  (GTK3 --with-x, via XWayland)
#   Linux gtk4   → +clipboard + +wayland_clipboard (GTK4 forces --without-x)
#   Linux gtk3   → +clipboard + (+wayland_clipboard OR +xterm_clipboard)
#   Linux no GUI → +clipboard + +clipboard_provider (OSC 52, --with-osc52)
vim_features_ok() {
	local f
	for f in "${VIM_REQUIRED_FEATURES[@]}"; do
		has_vim_feature "$f" || return 1
	done
	has_vim_feature clipboard || return 1
	# osc52/tmux clipboard providers and 'clipmethod' (.vimrc) need the
	# clipboard provider feature (9.1.1857+); distro builds between 9.1.0
	# and 9.1.1846 lack it, so require it on every platform.
	has_vim_feature clipboard_provider || return 1
	case "$OS" in
	macos) return 0 ;;
	esac
	if is_wsl; then
		has_vim_feature xterm_clipboard
	elif pkg-config --exists gtk4 2>/dev/null; then
		has_vim_feature wayland_clipboard
	elif pkg-config --exists gtk+-3.0 2>/dev/null; then
		has_vim_feature wayland_clipboard || has_vim_feature xterm_clipboard
	else
		has_vim_feature clipboard_provider
	fi
}

vim_missing_features() {
	local req f
	req=("${VIM_REQUIRED_FEATURES[@]}" clipboard clipboard_provider)
	if [ "$OS" != macos ]; then
		if is_wsl; then
			req+=(xterm_clipboard)
		elif pkg-config --exists gtk4 2>/dev/null; then
			req+=(wayland_clipboard)
		elif pkg-config --exists gtk+-3.0 2>/dev/null; then
			req+=(wayland_clipboard xterm_clipboard) # either one suffices
		fi
	fi
	for f in "${req[@]}"; do
		has_vim_feature "$f" || printf '%s ' "$f"
	done
}

build_vim() {
	if check_vim_version; then
		local ver
		# `|| true`: head -1 can close the pipe before vim finishes writing,
		# making vim die with SIGPIPE (141) and, under pipefail + set -e,
		# silently abort the whole script after a successful build.
		ver=$(vim --version | head -1 | grep -oE '[0-9]+\.[0-9]+' || true)
		if vim_features_ok; then
			ok "Vim ${ver} already installed and meets requirement (>= 9.1, full features). Skipping build."
			return 0
		fi
		warn "Vim ${ver} is >= 9.1 but missing feature(s): $(vim_missing_features)— rebuilding from source."
	else
		warn "Vim 9.1+ not found or vim not in PATH — building from source."
	fi

	info "Building Vim from source (this may take a few minutes)..."
	if [ -d "$VIM_SRC_DIR/.git" ]; then
		info "Vim source already exists at $VIM_SRC_DIR — pulling latest..."
		git -C "$VIM_SRC_DIR" pull --ff-only || warn "git pull failed — building from existing source."
	else
		git clone https://github.com/vim/vim.git "$VIM_SRC_DIR"
	fi

	pushd "$VIM_SRC_DIR" >/dev/null

	local configure_args=(
		--with-features=huge
		--enable-python3interp
		--enable-luainterp
		--enable-perlinterp
		--enable-rubyinterp
		--enable-multibyte
		--enable-terminal
		--enable-fontset
		--enable-cscope
		--enable-fail-if-missing
	)

	case "$OS" in
	macos)
		# Terminal-only build. The macOS system clipboard comes from the
		# Darwin/Cocoa (AppKit) feature, which is enabled by default — do
		# NOT pass --disable-darwin. No GTK/Motif/Athena dev libs are
		# installed, so 'auto' and 'no' are equivalent; be explicit. gpm
		# (Linux console mouse) doesn't exist on macOS and would abort
		# configure under --enable-fail-if-missing.
		configure_args+=(--enable-gui=no --disable-gpm)
		;;
	*)
		configure_args+=(--enable-gpm)
		if is_wsl; then
			# WSLg clipboard goes through XWayland — must keep GTK3 + --with-x
			configure_args+=(--enable-gui=gtk3 --with-x --with-wayland)
		elif pkg-config --exists gtk4 2>/dev/null; then
			# Non-WSL: GTK4 preferred (forces --without-x, so no --with-x)
			configure_args+=(--enable-gui=gtk4 --with-wayland)
		elif pkg-config --exists gtk+-3.0 2>/dev/null; then
			configure_args+=(--enable-gui=gtk3)
			pkg-config --exists x11 2>/dev/null && configure_args+=(--with-x)
			pkg-config --exists wayland-client 2>/dev/null && configure_args+=(--with-wayland)
		else
			# No GTK4/GTK3 (hence no X11/Wayland clipboard stack): fall
			# back to the OSC 52 clipboard provider (+clipboard_provider,
			# --with-osc52) so yanks still reach the terminal — works over
			# ssh/kmscon in terminals that implement OSC 52.
			configure_args+=(--enable-gui=no --with-osc52)
			warn "No GTK4/GTK3 found — building without GUI; no system clipboard, using OSC 52 clipboard provider instead."
		fi
		;;
	esac

	info "Configuring Vim..."
	./configure "${configure_args[@]}" 2>&1 | tee /tmp/vim-configure.log || {
		fail "Vim configure failed. Check /tmp/vim-configure.log"
	}

	info "Compiling Vim with ${JOBS} jobs..."
	make -j"$JOBS" 2>&1 | tee /tmp/vim-make.log || {
		fail "Vim build failed. Check /tmp/vim-make.log"
	}

	info "Installing Vim..."
	sudo_cmd make install 2>&1 | tee /tmp/vim-install.log || {
		fail "Vim install failed. Check /tmp/vim-install.log"
	}

	popd >/dev/null

	# Update PATH so the newly built vim is found
	export PATH="/usr/local/bin:$PATH"

	if check_vim_version; then
		local ver
		ver=$(vim --version | head -1 | grep -oE '[0-9]+\.[0-9]+' || true)
		ok "Vim ${ver} built and installed successfully."
	else
		fail "Vim build completed but vim is not found in PATH."
	fi
}

# ────────────────── Step 4: Clone monkey-vim ──────────────────

clone_monkey_vim() {
	if [ -d "$INSTALL_DIR/.git" ]; then
		info "monkey-vim already exists at $INSTALL_DIR — pulling latest..."
		git -C "$INSTALL_DIR" pull --ff-only || warn "git pull failed — keeping existing version."
	elif [ -e "$INSTALL_DIR" ]; then
		# Existing non-git dir is fine (e.g. git clone with .git removed).
		warn "$INSTALL_DIR exists but is not a git repository — using it as-is."
	else
		info "Cloning monkey-vim to $INSTALL_DIR..."
		git clone https://github.com/QMonkey/monkey-vim.git "$INSTALL_DIR"
	fi
	ok "monkey-vim ready at $INSTALL_DIR."
}

# ────────────────── Step 5: Run checkhealth.sh --install ──────────────────

run_checkhealth() {
	# PATH preseed before detection: checkhealth runs as a subprocess and
	# only inherits the current shell's env. persist_path writes the
	# go/bin & cargo/bin blocks to the profile LATER in main, so on a
	# first run freshly go/cargo-installed binaries would be reported
	# missing and re-installed by the retry loop. Export only — nothing
	# is written to any profile here.
	case ":$PATH:" in *":$HOME/go/bin:"*) ;; *) export PATH="$HOME/go/bin:$PATH" ;; esac
	case ":$PATH:" in *":$HOME/.cargo/bin:"*) ;; *) export PATH="$HOME/.cargo/bin:$PATH" ;; esac
	info "Running checkhealth.sh --install to install remaining dependencies..."
	# --install checks first and installs after; transient failures
	# (network blips, apt locks, aborted downloads) heal on retry. After
	# the first pass everything installed is skipped, so retries are
	# cheap verifications. Three attempts, exit code 0 wins.
	local attempt ok=0
	for attempt in 1 2 3; do
		if bash "$INSTALL_DIR/checkhealth.sh" --install --skip-check-config; then
			ok=1
			break
		fi
		if [ "$attempt" -lt 3 ]; then
			warn "checkhealth attempt $attempt/3 failed — retrying..."
			sleep 2
		fi
	done
	if [ "$ok" = 1 ]; then
		ok "Dependency check complete."
	else
		warn "Some dependencies could not be installed automatically."
		warn "Run 'cd $INSTALL_DIR && ./checkhealth.sh' to review remaining items."
	fi
}

# ────────────────── Step 6: Persist PATH (go/bin, cargo/bin) ──────────────────

persist_path() {
	# go install drops binaries in $(go env GOPATH)/bin (default ~/go/bin);
	# rustup installs cargo & rust-analyzer to ~/.cargo/bin; built vim lives
	# in /usr/local/bin. None is guaranteed to be on PATH, so persist exports
	# for the detected shell (zsh→.zprofile, bash→.profile/.bash_profile).
	local block='case ":$PATH:" in *":/usr/local/bin:"*) ;; *) export PATH="/usr/local/bin:$PATH" ;; esac
case ":$PATH:" in *":$HOME/go/bin:"*) ;; *) export PATH="$HOME/go/bin:$PATH" ;; esac
case ":$PATH:" in *":$HOME/.cargo/bin:"*) ;; *) export PATH="$HOME/.cargo/bin:$PATH" ;; esac'
	append_env_block "monkey PATH" "$block"
	ok "PATH persistence added for /usr/local/bin, go/bin and cargo/bin."
}

# ────────────────── Step 7: Set up symlinks & runtime dirs ──────────────────

setup_symlinks() {
	info "Setting up configuration symlinks..."
	ln -sf "$INSTALL_DIR/.vimrc" "$HOME/.vimrc"
	ok ".vimrc → $INSTALL_DIR/.vimrc"

	mkdir -p "$HOME/.cache/vim/swap"
	ok "created $HOME/.cache/vim/swap"

	mkdir -p "$HOME/.cache/vim/sessions"
	ok "created $HOME/.cache/vim/sessions"

	mkdir -p "$HOME/.cache/vim/viminfo"
	ok "created $HOME/.cache/vim/viminfo"

	if [ -d "$INSTALL_DIR/configs" ]; then
		if [ -f "$INSTALL_DIR/configs/.clang-format" ]; then
			if [ -e "$HOME/.clang-format" ] || [ -L "$HOME/.clang-format" ]; then
				info "~/.clang-format already exists — skipping."
			else
				ln -sf "$INSTALL_DIR/configs/.clang-format" "$HOME/.clang-format"
				ok ".clang-format → $INSTALL_DIR/configs/.clang-format"
			fi
		fi
		if [ -d "$INSTALL_DIR/configs/efm-langserver" ]; then
			if [ -e "$HOME/.config/efm-langserver" ] || [ -L "$HOME/.config/efm-langserver" ]; then
				info "efm-langserver config already exists — skipping."
			else
				mkdir -p "$HOME/.config"
				ln -sfn "$INSTALL_DIR/configs/efm-langserver" "$HOME/.config/efm-langserver"
				ok "efm-langserver config → $HOME/.config/efm-langserver"
			fi
		fi
	fi
}

# ────────────────── Step 8: Install plugins via vim-plug ──────────────────

install_plugins() {
	# Headless `vim -es` swallows vim-plug's window output, so cloning the
	# plugins produces NO output at all — spell out that the wait is normal
	# instead of looking like a hang.
	info "Installing Vim plugins (vim-plug) — no output below until done, may take a few minutes..."
	# vim-plug is auto-bootstrapped by .vimrc on first launch.
	# We run vim headless to trigger PlugInstall.
	vim -es -u "$HOME/.vimrc" \
		+"PlugInstall --sync" \
		+qall 2>/dev/null || {
		warn "Headless PlugInstall failed. Plugins will be installed on first launch."
	}
	ok "Plugins installed."
}

# ────────────────── Main ──────────────────

main() {
	echo ""
	echo -e "${BOLD}╔══════════════════════════════════════════╗${NC}"
	echo -e "${BOLD}║       monkey-vim installer               ║${NC}"
	echo -e "${BOLD}╚══════════════════════════════════════════╝${NC}"
	echo ""

	info "Detected OS: ${CYAN}${OS}${NC}"
	if is_wsl; then
		info "Detected WSL — building Vim with GTK3 + X11 (WSLg clipboard)."
	fi
	info "monkey-vim: ${CYAN}${INSTALL_DIR}${NC}"
	info "vim source: ${CYAN}${VIM_SRC_DIR}${NC} (kept for future updates)"
	echo ""

	setup_sudo

	install_vim_build_deps
	echo ""

	install_linuxbrew
	echo ""

	build_vim
	echo ""

	clone_monkey_vim
	echo ""

	run_checkhealth
	echo ""

	refresh_path

	persist_path
	echo ""

	setup_symlinks
	echo ""

	install_plugins
	echo ""

	echo -e "${GREEN}${BOLD}monkey-vim installation complete!${NC}"
	echo ""
	echo -e "  Config:   ${CYAN}$INSTALL_DIR/.vimrc${NC} → ${CYAN}~/.vimrc${NC}"
	echo -e "  Plugins:  ${CYAN}~/.vim/bundle/${NC}"
	echo ""
	echo -e "  Run ${CYAN}vim${NC} to start."
	echo -e "  Update vim: ${CYAN}cd $VIM_SRC_DIR && git pull && make -j$JOBS && sudo make install${NC}"
	echo -e "  Update monkey-vim: ${CYAN}cd $INSTALL_DIR && git pull${NC}"
	echo ""
	# PATH exports were written to shell rc files, but they only apply to
	# shells started AFTER this point. A child process can never change the
	# parent shell's environment, so spell out how to pick it up now.
	local env_file
	env_file="$(shell_env_files | head -1)"
	# ACQUIRE_TIOCSTI protocol: only the script that claimed the injection
	# right acts. When chained, the wrapper holds the right and injects once
	# at its own end — per-component hints would be redundant there.
	if [ "$ACQUIRE_TIOCSTI" != "monkey-vim" ]; then
		: # wrapper holds the injection right
	elif inject_tty "source ${env_file}"; then
		echo -e "  ${GREEN}Injected 'source ${env_file}' into the current terminal.${NC}"
	else
		echo -e "  ${YELLOW}New PATH takes effect in NEW shells. To use it in this terminal now:${NC}"
		echo -e "    ${CYAN}source ${env_file}${NC}    ${YELLOW}# or simply: ${CYAN}exec \$SHELL${NC}"
	fi
	echo ""
}

main "$@"
