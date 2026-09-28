# monkey-scripts/lib/pkg.sh — package index refresh, installs, Homebrew.
#
# Sourced by scripts/install.sh and scripts/checkhealth.sh.
#
# pkg_name() is a single mapping table for the system manager AND the brew
# fallback (brew validates every name up front and aborts the WHOLE batch
# when one is unknown — a lone apt-style "golang-go" would prevent even the
# brew-available fzf from installing). Projects override it AFTER sourcing
# the entry point: only entries that differ from the binary name need a case
# arm, everything else falls through. A case function instead of
# `declare -A`: macOS still ships bash 3.2, which has no associative arrays.
# Base table: names that differ from the binary name for SOME package
# manager. Editor/LSP/tooling names shared by monkey-nvim and monkey-vim live
# here; a repo with a one-off mapping (monkey-sway's swaymsg, monkey-hyprland's
# notif, ...) overrides pkg_name() after sourcing and delegates the rest to
# this function.
# openSUSE Python module packages carry the interpreter's ABI flavor
# prefix (python314-black, python314-python-lsp-server — NOT python3-*),
# and the flavor follows the default python3 version, so derive it at
# runtime. Prints nothing if python3 is unavailable.
python_flavor() {
	python3 -c 'import sys;print("python%d%d"%sys.version_info[:2])' 2>/dev/null
}

default_pkg_name() {
	case "${OS:-unknown}:$1" in
	# Go / Node / shell utilities
	debian:go | ubuntu:go) echo "golang-go" ;;
	centos:go | fedora:go) echo "golang" ;;
	debian:node | ubuntu:node | arch:node | opensuse:node | centos:node | fedora:node) echo "nodejs" ;;
	debian:which | ubuntu:which) echo "debianutils" ;;
	arch:python3 | macos:python3) echo "python" ;;
	# Editors / language servers / gtags tooling (monkey-nvim, monkey-vim)
	debian:rg | ubuntu:rg | arch:rg | macos:rg | opensuse:rg | centos:rg | fedora:rg) echo "ripgrep" ;;
	debian:ctags | ubuntu:ctags | macos:ctags | opensuse:ctags | centos:ctags) echo "universal-ctags" ;;
	arch:ctags | fedora:ctags) echo "ctags" ;; # Arch & Fedora ship universal-ctags as "ctags"
	debian:pygmentize | ubuntu:pygmentize) echo "python3-pygments" ;;
	arch:pygmentize) echo "python-pygments" ;;
	macos:pygmentize) echo "pygments" ;;
	opensuse:pygmentize) echo "$(python_flavor)-Pygments" ;;
	centos:pygmentize | fedora:pygmentize) echo "python3-pygments" ;;
	debian:pylsp | ubuntu:pylsp) echo "python3-pylsp" ;;
	arch:pylsp | macos:pylsp) echo "python-lsp-server" ;;
	opensuse:pylsp) echo "$(python_flavor)-python-lsp-server" ;;
	centos:pylsp | fedora:pylsp) echo "python3-lsp-server" ;;
	# Debian/Ubuntu split clangd & clang-tidy into their own (unversioned
	# metapackages — `clang` there ships only clang/clang++, so mapping them
	# to `clang` installs nothing the probes look for. Arch's `clang` DOES
	# ship both binaries; openSUSE's `clang` carries them too.
	arch:clangd | arch:clang-tidy | opensuse:clangd | opensuse:clang-tidy) echo "clang" ;;
	debian:clangd | ubuntu:clangd) echo "clangd" ;;
	debian:clang-tidy | ubuntu:clang-tidy) echo "clang-tidy" ;;
	macos:clangd | macos:clang-tidy) echo "llvm" ;;
	centos:clangd | centos:clang-tidy | fedora:clangd | fedora:clang-tidy) echo "clang-tools-extra" ;;
	arch:g++ | macos:g++) echo "gcc" ;;
	opensuse:g++ | centos:g++ | fedora:g++) echo "gcc-c++" ;;
	arch:black) echo "python-black" ;;
	opensuse:black) echo "$(python_flavor)-black" ;;
	centos:black | fedora:black) echo "python3-black" ;;
	*) echo "$1" ;;
	esac
}

pkg_name() {
	default_pkg_name "$1"
}

# Names that should prefer Homebrew over the system package manager: system
# repos ship versions that lag far behind (fzf: 0.44 on Ubuntu noble vs
# current 0.7x). Projects append names here.
BREW_FIRST=()

# ────────────────── package index refresh ──────────────────
# Refresh the package index before installing: a stale or missing index is
# the usual cause of "Unable to locate package" on freshly provisioned
# machines (and universe-only packages like fzf/zoxide/eza are invisible
# until the first update). Retried once for transient network failures; a
# failed refresh is never fatal — the install step still runs (dnf refreshes
# expired metadata on demand anyway, brew auto-updates). Guarded to at most
# one refresh per run: checkhealth installs in two batches (required +
# optional) and the index does not go stale between them — call freely
# before every install.
PKG_DB_REFRESHED=0
refresh_pkg() {
	[ "$PKG_DB_REFRESHED" -eq 1 ] && return 0
	PKG_DB_REFRESHED=1
	local attempt
	for attempt in 1 2; do
		case "$OS" in
		debian | ubuntu) sudo_cmd apt-get update ;;
		arch) sudo_cmd pacman -Sy ;;
		opensuse) sudo_cmd zypper --non-interactive refresh ;;
		centos | fedora) sudo_cmd dnf makecache -q ;;
		*) return 0 ;;
		esac && return 0
		[ "$attempt" -lt 2 ] && sleep 2
	done
	return 0
}

# Low-level path used inside install_pkg and as the brew-failure fallback —
# returns non-zero when the OS is unknown or the manager fails.
install_sys_pkg() {
	refresh_pkg
	case "$OS" in
	debian | ubuntu) sudo_cmd apt-get install -y "$@" ;;
	arch) sudo_cmd pacman -S --noconfirm "$@" ;;
	opensuse) sudo_cmd zypper --non-interactive install -y "$@" ;;
	centos)
		# Some tools (universal-ctags, global, fzf, bat, pygments) come from EPEL.
		sudo_cmd dnf install -y epel-release || true
		local -a _args=("$@")
		[[ " ${_args[*]} " =~ " global " ]] && _args+=(global-ctags)
		sudo_cmd dnf install -y "${_args[@]}"
		;;
	fedora)
		# No EPEL on Fedora — the names below ship in the base repos.
		# gtags needs the global-ctags subpackage (ctags back-end config),
		# same as CentOS; without it gtags is unusable.
		local -a _args=("$@")
		[[ " ${_args[*]} " =~ " global " ]] && _args+=(global-ctags)
		sudo_cmd dnf install -y "${_args[@]}"
		;;
	macos) return 1 ;; # Homebrew owns macOS — install_pkg routes there
	*) return 1 ;;
	esac
}

# System package install with Homebrew fallback. Gated on INSTALL_MODE
# (checkhealth.sh only installs under --install; install.sh always does);
# recycles bash's command hash so a freshly installed binary resolves.
install_pkg() {
	${INSTALL_MODE:-true} || return 1
	refresh_pkg
	# Split the request: names in BREW_FIRST go through Homebrew (when it
	# exists, falling back to the system manager on failure), everything else
	# through the OS package manager as before.
	local -a brew_pkgs=() rest=()
	local _rc=0 p b
	for p in "$@"; do
		if [[ " ${BREW_FIRST[*]-} " == *" $p "* ]] && have_native_cmd brew; then
			brew_pkgs+=("$p")
		else
			rest+=("$p")
		fi
	done
	# System-manager batch FIRST, Homebrew LAST: every `brew` invocation
	# resets the sudo timestamp (brew.sh runs `sudo --reset-timestamp` at
	# startup), so any sudo work after a brew call would re-prompt. Doing all
	# sudo work before brew keeps the run at one password entry.
	if ((${#rest[@]} > 0)); then
		install_sys_pkg "${rest[@]}" || {
			if have_native_cmd brew; then
				local -a bpkg=()
				for b in "${rest[@]}"; do bpkg+=("$(pkg_name "$b" brew)"); done
				brew install "${bpkg[@]}"
			else
				false
			fi
		} || _rc=1
	fi
	if ((${#brew_pkgs[@]} > 0)); then
		brew install "${brew_pkgs[@]}" || install_sys_pkg "${brew_pkgs[@]}" || _rc=1
	fi
	# Freshly installed binaries may be shadowed by bash's per-process
	# command hash cache (a /mnt shim executed earlier in this same run);
	# re-scan PATH. Run AFTER capturing _rc — hash -r must not mask the
	# install status.
	hash -r
	return "$_rc"
}

get_install_hint() {
	case "$OS" in
	debian | ubuntu) echo "sudo apt-get install ${*}" ;;
	arch) echo "sudo pacman -S ${*}" ;;
	opensuse) echo "sudo zypper install ${*}" ;;
	centos | fedora) echo "sudo dnf install ${*}" ;;
	macos) echo "brew install ${*}" ;;
	linux-unknown) echo "install ${*} manually or 'brew install ${*}'" ;;
	*) echo "install ${*} manually" ;;
	esac
}

# ────────────────── shared install steps ──────────────────
# git is needed BEFORE checkhealth.sh --install gets a chance to install it:
# the Homebrew installer clones the brew repository, and the scripts clone
# the monkey-* config — both happen earlier in the chain.
ensure_git() {
	if ! have_native_cmd git; then
		info "Installing git..."
		install_pkg git || :
	fi
	have_native_cmd git || fail "git installation failed — install it manually: $(get_install_hint git)."
}

# Install a binary from the system package manager if it is missing.
# Usage: ensure_system_bin <bin> <desc> — never fatal (the package may not be
# in the repos; checkhealth reports what is left afterwards).
ensure_system_bin() {
	local bin="$1" desc="${2:-$1}" ver
	if have_native_cmd "$bin"; then
		ver=$("$bin" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+' | head -1)
		ok "${desc} ${ver:+$ver }already installed."
		return 0
	fi
	info "Installing ${desc} via the system package manager..."
	if install_pkg "$(pkg_name "$bin")"; then
		ok "${desc} installed."
	else
		warn "${desc} install failed — install it manually: $(get_install_hint "$(pkg_name "$bin")")"
	fi
}

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
		# sed-patching the installer, but the temporary NOPASSWD drop-in makes
		# the timestamp irrelevant, so the official installer runs unmodified.
		# If the drop-in failed to install, the next privileged command simply
		# re-authenticates once (sudo_cmd).
		# Download fully before executing: `curl | bash` would run a truncated
		# script if the connection drops mid-stream.
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
		# Persist shellenv for future shells (login + interactive rc). Runs
		# even when brew pre-dates this run: without it, brew-installed tools
		# (node/npm/...) vanish from PATH in new shells. Idempotent —
		# append_env_block skips if the marker is already present. The case
		# guard makes re-sourcing (e.g. a login .profile sourcing .bashrc,
		# both carrying this block) a no-op instead of prepending brew's
		# bin/sbin to PATH twice.
		local line
		line="case \":\$PATH:\" in *\":${brew_prefix}/bin:\"*) ;; *) eval \"\$(${brew_prefix}/bin/brew shellenv)\" ;; esac"
		append_env_block "Homebrew shellenv" "$line"
	else
		warn "brew not found — continuing without Homebrew."
	fi
}
