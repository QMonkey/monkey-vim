#!/usr/bin/env bash
set -euo pipefail

# ──────────────────────────────────────────────────────────────
# monkey-vim one-shot installer
# Usage: curl -fsSL https://raw.githubusercontent.com/QMonkey/monkey-vim/master/install.sh | bash
# ──────────────────────────────────────────────────────────────

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

INSTALL_DIR="${INSTALL_DIR:-$HOME/Documents/monkey-vim}"
VIM_SRC_DIR="${VIM_SRC_DIR:-$HOME/Documents/vim}"
JOBS="${JOBS:-$(nproc 2>/dev/null || echo 4)}"

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

is_wsl() {
	[[ -n "${WSL_DISTRO_NAME:-}" || -n "${WSL_INTEROP:-}" ]]
}

OS=$(os_detect)

sudo_cmd() {
	if command -v sudo &>/dev/null; then
		sudo "$@"
	else
		"$@"
	fi
}

# Print login profile + interactive rc file for the detected shell.
# Login files (.profile/.zprofile/.bash_profile) cover login shells (SSH,
# macOS Terminal); rc files (.bashrc/.zshrc) cover non-login interactive
# shells (Linux desktop terminals). We write to both so tools are on PATH
# everywhere.
shell_env_files() {
	local shell="${SHELL:-bash}"
	shell="${shell##*/}"
	case "$shell" in
	zsh)
		printf '%s\n' "$HOME/.zprofile"
		printf '%s\n' "$HOME/.zshrc"
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
	if command -v go &>/dev/null; then
		local gopath
		gopath=$(go env GOPATH 2>/dev/null || echo "$HOME/go")
		export PATH="$gopath/bin:$PATH"
	fi
	# Not `[ ... ] && . ...`: when the file is missing the function returns
	# non-zero and, under set -e, silently aborts the whole script.
	if [ -f "$HOME/.cargo/env" ]; then . "$HOME/.cargo/env"; fi
}

# ────────────────── sudo keepalive ──────────────────

SUDO_KEEPALIVE_PID=""

start_sudo_keepalive() {
	# Keep sudo credentials alive for the whole run: the gap between the first
	# sudo (build deps) and later ones (make install) can exceed the default
	# 15-min timestamp_timeout on slow downloads/compiles. A re-auth prompt
	# then aborts unattended runs (no TTY to answer it).
	# Skip when running as root or when sudo is unavailable.
	if [ "$(id -u)" -eq 0 ] || ! command -v sudo &>/dev/null; then
		return 0
	fi
	# Pre-authenticate once so the password is entered at the very start
	# instead of mid-run after a long download/compile.
	sudo -v || fail "sudo authorization failed — run this script in an interactive terminal."
	(
		# Test hook; also lets users tune the refresh rate.
		interval="${SUDO_KEEPALIVE_INTERVAL:-60}"
		# Kill the in-flight `sleep` child when we get TERMed, so no orphan
		# sleep survives the script.
		trap 'kill $(jobs -p) 2>/dev/null; exit 0' TERM
		while true; do
			sleep "$interval" &
			wait "$!" 2>/dev/null || exit 0
			# Non-interactive refresh: never prompts. If the timestamp has
			# fully expired this fails and the loop exits; later sudo calls
			# then prompt normally — no worse than without the keepalive.
			sudo -n true 2>/dev/null || exit 0
		done
	) &
	SUDO_KEEPALIVE_PID=$!
	# Recycle the background loop on any exit path (success, fail, Ctrl-C).
	trap 'kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true' EXIT
}

# ────────────────── Step 1: Install build deps for Vim ──────────────────

install_vim_build_deps() {
	info "Installing Vim build dependencies..."
	case "$OS" in
	debian)
		sudo_cmd apt-get update -qq
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
		common=(git curl
			wayland-devel cairo-devel
			gpm-devel ncurses-devel
			python-devel python3-devel
			ruby-devel lua-devel perl perl-devel)
		if is_wsl; then
			gui=(gtk3-devel xorg-x11-devel libXpm-devel libXt-devel)
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
		# Terminal-only build (--enable-gui=no); no gtk/cairo needed.
		if command -v brew &>/dev/null; then
			brew install python3 ruby lua
		else
			warn "Homebrew not found — cannot install vim build deps. Install it first: https://brew.sh"
		fi
		;;
	*)
		warn "Unknown OS ($OS). Attempting to continue with whatever is available."
		;;
	esac
	ok "Build dependencies installed."
}

# ────────────────── Step 2: Install Homebrew / Linuxbrew ──────────────────

install_linuxbrew() {
	local brew_prefix=""
	if command -v brew &>/dev/null; then
		brew_prefix="$(dirname "$(dirname "$(command -v brew)")")"
		ok "Homebrew already installed at $brew_prefix."
	else
		info "Installing Homebrew/Linuxbrew..."
		NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" ||
			warn "Homebrew installer failed — continuing without Homebrew."

		local cand
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
	req=("${VIM_REQUIRED_FEATURES[@]}" clipboard)
	if [ "$OS" != macos ]; then
		if is_wsl; then
			req+=(xterm_clipboard)
		elif pkg-config --exists gtk4 2>/dev/null; then
			req+=(wayland_clipboard)
		elif pkg-config --exists gtk+-3.0 2>/dev/null; then
			req+=(wayland_clipboard xterm_clipboard) # either one suffices
		else
			req+=(clipboard_provider)
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
	else
		info "Cloning monkey-vim to $INSTALL_DIR..."
		git clone https://github.com/QMonkey/monkey-vim.git "$INSTALL_DIR"
	fi
	ok "monkey-vim ready at $INSTALL_DIR."
}

# ────────────────── Step 5: Run checkhealth.sh --install ──────────────────

run_checkhealth() {
	info "Running checkhealth.sh --install to install dependencies..."
	bash "$INSTALL_DIR/checkhealth.sh" --install || {
		warn "Some dependencies could not be installed automatically."
		warn "Run 'cd $INSTALL_DIR && ./checkhealth.sh' to review remaining items."
	}
	ok "Dependency check complete."
}

# ────────────────── Step 6: Persist PATH (go/bin, cargo/bin) ──────────────────

persist_path() {
	# go install drops binaries in $(go env GOPATH)/bin (default ~/go/bin);
	# rustup installs cargo & rust-analyzer to ~/.cargo/bin; built vim lives
	# in /usr/local/bin. None is guaranteed to be on PATH, so persist exports
	# for the detected shell (zsh→.zprofile + .zshrc, bash→.profile/.bash_profile + .bashrc).
	local block='case ":$PATH:" in *":/usr/local/bin:"*) ;; *) export PATH="/usr/local/bin:$PATH" ;; esac
case ":$PATH:" in *":$HOME/go/bin:"*) ;; *) export PATH="$HOME/go/bin:$PATH" ;; esac
case ":$PATH:" in *":$HOME/.cargo/bin:"*) ;; *) export PATH="$HOME/.cargo/bin:$PATH" ;; esac'
	append_env_block "monkey-vim PATH" "$block"
	ok "PATH persistence added for /usr/local/bin, go/bin and cargo/bin."
}

# ────────────────── Step 7: Set up symlinks & runtime dirs ──────────────────

setup_symlinks() {
	info "Setting up configuration symlinks..."
	ln -sf "$INSTALL_DIR/.vimrc" "$HOME/.vimrc"
	ok ".vimrc → $INSTALL_DIR/.vimrc"

	mkdir -p "$HOME/.vim/swap"
	ok "created $HOME/.vim/swap"

	mkdir -p "$HOME/.cache/sessions"
	ok "created $HOME/.cache/sessions"

	if [ -d "$INSTALL_DIR/configs" ]; then
		if [ -f "$INSTALL_DIR/configs/.clang-format" ]; then
			if [ -e "$HOME/.clang-format" ] || [ -L "$HOME/.clang-format" ]; then
				info "~/.clang-format already exists — skipping."
			else
				ln -s "$INSTALL_DIR/configs/.clang-format" "$HOME/.clang-format"
				ok ".clang-format → $INSTALL_DIR/configs/.clang-format"
			fi
		fi
		if [ -d "$INSTALL_DIR/configs/efm-langserver" ]; then
			if [ -e "$HOME/.config/efm-langserver" ] || [ -L "$HOME/.config/efm-langserver" ]; then
				info "efm-langserver config already exists — skipping."
			else
				mkdir -p "$HOME/.config"
				ln -s "$INSTALL_DIR/configs/efm-langserver" "$HOME/.config/efm-langserver"
				ok "efm-langserver config → $HOME/.config/efm-langserver"
			fi
		fi
	fi
}

# ────────────────── Step 8: Install plugins via vim-plug ──────────────────

install_plugins() {
	info "Installing Vim plugins (vim-plug)..."
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

	start_sudo_keepalive

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
	echo -e "  ${YELLOW}New PATH takes effect in NEW shells. To use it in this terminal now:${NC}"
	echo -e "    ${CYAN}source ${env_file}${NC}    ${YELLOW}# or simply: ${CYAN}exec \$SHELL${NC}"
	echo ""
}

main "$@"
