#!/usr/bin/env bash
set -euo pipefail

# ──────────────────────────────────────────────────────────────
# monkey-vim one-shot installer
# Usage: curl -fsSL https://raw.githubusercontent.com/QMonkey/monkey-vim/master/install.sh | bash
#
# The shared installer (sudo, packages, clone, checkhealth, symlinks,
# completion) lives in scripts/ — a `git subtree` of
# github.com/QMonkey/monkey-scripts. On the curl|bash path there is no
# checkout at all, so install.sh clones THIS repo and runs the copy of
# install.sh inside it — that copy carries its own scripts/, so the
# installer and the framework it loads are always the same revision.
# ──────────────────────────────────────────────────────────────

# ──────────────────────── repository identity ────────────────────────
# Declared before the framework is sourced: the bootstrap below needs both
# values, and clones into the very directory clone_monkey_project would
# have used — one clone per run, not two.
PROJECT=monkey-vim
PROJECT_REPO=https://github.com/QMonkey/monkey-vim.git
INSTALL_DIR="${INSTALL_DIR:-$HOME/Documents/monkey-vim}"

# No scripts/ next to this file: either a checkout predating the subtree
# commit (pull it in and carry on) or `curl | bash`, which has no checkout
# at all. The latter clones THIS project and runs the install.sh from that
# checkout, so installer and scripts/ always come from the same revision.
# No scripts/ next to this file: either a checkout predating the subtree
# commit (pull it in and carry on), a .git-less directory (zip/tarball),
# or `curl | bash`, which has no checkout at all. The latter two bootstrap
# through INSTALL_DIR and run the install.sh from that checkout, so
# installer and scripts/ always come from the same revision.
_monkey_scripts="$(dirname "${BASH_SOURCE[0]:-$0}")/scripts"
if [ ! -f "$_monkey_scripts/install.sh" ]; then
	_monkey_self="${BASH_SOURCE[0]:-$0}"
	_monkey_dir="$(dirname "$_monkey_self")"
	if [ -f "$_monkey_self" ] && [ -d "$_monkey_dir/.git" ]; then
		# Outdated checkout: update it in place and keep running from it.
		git -C "$_monkey_dir" pull --ff-only || true
		if [ ! -f "$_monkey_dir/scripts/install.sh" ]; then
			echo "monkey-scripts missing from $_monkey_dir (no scripts/ subtree)." >&2
			echo "  git -C $_monkey_dir pull    # outdated checkout — or the repo never added the subtree" >&2
			exit 1
		fi
		_monkey_scripts="$_monkey_dir/scripts"
	else
		# curl|bash or a .git-less directory: the only path to a
		# same-revision scripts/ is the INSTALL_DIR checkout.
		# clone_monkey_project cannot do this job — it lives in the very
		# scripts/ being fetched. INSTALL_DIR is where the framework's clone
		# step would have put the checkout too, so that step only confirms it.
		if [ -d "$INSTALL_DIR/.git" ]; then
			# An install already lives here: update it, then run that one.
			git -C "$INSTALL_DIR" pull --ff-only || true
		elif [ -d "$INSTALL_DIR" ] && [ -n "$(ls -A "$INSTALL_DIR")" ]; then
			# git clone would refuse too, so say why in our own words.
			echo "$INSTALL_DIR is not empty and is not a git clone." >&2
			echo "  move it aside, delete it, or set INSTALL_DIR elsewhere." >&2
			exit 1
		else
			# Fresh clone — the ONLY sub-branch where git is hard-required:
			# the pull sub-branch above degrades gracefully without it, and
			# a zip/tarball must not fail here just for a missing git.
			if ! command -v git >/dev/null 2>&1; then
				echo "git is required to clone $PROJECT — install it first (e.g. sudo apt-get install git), then re-run." >&2
				exit 1
			fi
			# No retry() available yet — the framework loads only after this
			# clone succeeds — so inline the standard 3 attempts. A failed
			# clone leaves a partial directory behind; remove it so the next
			# attempt cannot trip over "already exists". This branch only
			# runs on a fresh install (INSTALL_DIR did not exist or was
			# empty), so the rm can never delete pre-existing data.
			_monkey_rc=1
			for _monkey_attempt in 1 2 3; do
				if git clone "$PROJECT_REPO" "$INSTALL_DIR"; then
					_monkey_rc=0
					break
				fi
				rm -rf "$INSTALL_DIR"
				if [ "$_monkey_attempt" -lt 3 ]; then
					sleep 2
				fi
			done
			[ "$_monkey_rc" -eq 0 ] || exit 1
		fi
		# </dev/null: on the curl|bash path stdin is the script pipe, and the
		# inner installer must not read what is left of the outer one.
		exec bash "$INSTALL_DIR/install.sh" "$@" </dev/null
	fi
fi
# shellcheck source=/dev/null
. "$_monkey_scripts/install.sh"

# ──────────────────────── layout & data ────────────────────────
VIM_SRC_DIR="${VIM_SRC_DIR:-$HOME/Documents/vim}" # kept for future updates
JOBS="${JOBS:-$(nproc 2>/dev/null || echo 4)}"
ACQUIRE_TIOCSTI="${ACQUIRE_TIOCSTI:-monkey-vim}"
INSTALL_INFO=(
	"vim source: ${CYAN}${VIM_SRC_DIR}${NC} (kept for future updates)"
)

# src|dst — the swap/sessions/viminfo dirs under .cache are auto-created on
# first launch, so only .vimrc is linked.
SYMLINKS=(
	"$INSTALL_DIR/.vimrc|$HOME/.vimrc"
)
ENSURE_DIRS=(
	"$HOME/.cache/vim/swap"
	"$HOME/.cache/vim/sessions"
	"$HOME/.cache/vim/viminfo"
)

# PATH exports land in the profile but only apply to shells started later —
# the original installer persists them BEFORE linking (same output block).
PERSIST_PATH=1
PERSIST_POS=before_links
SUMMARY_LINES=(
	"  Config:   ${CYAN}$INSTALL_DIR/.vimrc${NC} → ${CYAN}~/.vimrc${NC}"
	"  Plugins:  ${CYAN}~/.vim/bundle/${NC}"
	""
	"  Run ${CYAN}vim${NC} to start."
	"  Update vim: ${CYAN}cd $VIM_SRC_DIR && git pull && make -j$JOBS && sudo make install${NC}"
	"  Update monkey-vim: ${CYAN}cd $INSTALL_DIR && git pull${NC}"
)

# ──────────────────────── project steps ────────────────────────

install_print_info() {
	if is_wsl; then
		info "Detected WSL — building Vim with GTK3 + X11 (WSLg clipboard)."
	fi
}

install_vim_build_deps() {
	info "Installing Vim build dependencies..."
	refresh_pkg
	case "$OS" in
	debian | ubuntu)
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
		retry -t 1800 -s "apt-get install" sudo_cmd apt-get install -y "${common[@]}" "${gui[@]}"
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
		retry -t 1800 -s "pacman install" sudo_cmd pacman -S --needed --noconfirm "${common[@]}" "${gui[@]}"
		;;
	opensuse)
		retry -t 1800 -s "zypper pattern" sudo_cmd zypper --non-interactive install -y -t pattern devel_basis
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
		retry -t 1800 -s "zypper install" sudo_cmd zypper --non-interactive install -y "${common[@]}" "${gui[@]}"
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
		retry -t 1800 -s "dnf install" sudo_cmd dnf install -y "${common[@]}" "${gui[@]}"
		;;
	fedora)
		# No EPEL on Fedora — the same names ship in the base repos.
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
		retry -t 1800 -s "dnf install" sudo_cmd dnf install -y "${common[@]}" "${gui[@]}"
		;;
	macos)
		# Terminal-only build (--enable-gui=no); no gtk/cairo needed. git is
		# required regardless — build_vim and the clone both pull sources.
		if have_native_cmd brew; then
			retry -t 1800 -s "brew install build deps" brew install git python3 ruby lua
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

# ──────────────────────── build Vim from source ────────────────────────

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
		# silently aborting the whole script after a successful build.
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
		retry -s "git pull" git -C "$VIM_SRC_DIR" pull --ff-only ||
			warn "git pull failed — building from existing source."
	else
		# A failed clone leaves a partial directory behind, which would make
		# every later attempt (and re-run) fail with "already exists" — clean
		# it up before giving up, but only when git created it (.git inside)
		# or it is empty, never when it holds pre-existing user data.
		if ! retry -t 1800 -s "git clone vim" git clone https://github.com/vim/vim.git "$VIM_SRC_DIR"; then
			if [ -d "$VIM_SRC_DIR" ] && { [ -z "$(ls -A "$VIM_SRC_DIR")" ] || [ -d "$VIM_SRC_DIR/.git" ]; }; then
				rm -rf "$VIM_SRC_DIR"
			fi
			fail "vim source clone failed after 3 attempts."
		fi
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

# ──────────────────────── extra links (same block as the symlinks step) ──────

# .clang-format and the efm-langserver config are repo-side files: link them
# once, never touch an existing target (the repo may not even ship them).
install_step_symlinks() {
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

# ──────────────────────── plugins ────────────────────────

install_plugins() {
	# Headless `vim -es` swallows vim-plug's window output, so cloning the
	# plugins produces NO output at all — spell out that the wait is normal
	# instead of looking like a hang.
	info "Installing Vim plugins (vim-plug) — no output below until done, may take a few minutes..."
	# vim-plug is auto-bootstrapped by .vimrc on first launch.
	# We run vim headless to trigger PlugInstall. Retried like every other
	# network download — the run clones every plugin; a retry resumes
	# (already-cloned repos are skipped by vim-plug).
	retry -t 3600 -s "headless PlugInstall" \
		vim -es -u "$HOME/.vimrc" \
		+"PlugInstall --sync" \
		+qall 2>/dev/null || {
		warn "Headless PlugInstall failed. Plugins will be installed on first launch."
	}
	ok "Plugins installed."
}

# ──────────────────────── hooks ────────────────────────
# A hook prints its own trailing blank line when it produced output.
install_step_prepare() {
	# First: make $XDG_RUNTIME_DIR usable — vim's server features
	# (--servername/--serverlist) write runtime files there and fail on a
	# sessionless WSL (root default user). See README 'Precautions' → WSL2.
	ensure_xdg_runtime_dir
	install_vim_build_deps
	echo ""
	install_linuxbrew
	echo ""
}
install_step_tool() {
	build_vim
	echo ""
}
install_step_after() {
	install_plugins
	echo ""
}

install_main "$@"
