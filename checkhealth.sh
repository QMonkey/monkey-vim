#!/usr/bin/env bash
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

PASS="[${GREEN}✓${NC}]"
FAIL="[${RED}✗${NC}]"
WARN="[${YELLOW}!${NC}]"

ALL_PASSED=true
INSTALL_MODE=false
SKIP_CONFIG_CHECKS=false

usage() {
	cat <<EOF
Usage: $0 [OPTIONS]

Check and optionally install dependencies for monkey-vim.

OPTIONS
  -i, --install    Install missing dependencies
  --skip-check-config
                   Skip config-file checks (install.sh passes this: the
                   config symlinks are linked after this script runs)
  -h, --help       Show this help

Exit code: 1 if any required dependency is missing, 0 otherwise.
EOF
	exit 0
}

parse_args() {
	while [[ $# -gt 0 ]]; do
		case "$1" in
		-i | --install) INSTALL_MODE=true ;;
		--skip-check-config) SKIP_CONFIG_CHECKS=true ;;
		-h | --help) usage ;;
		*)
			echo "Unknown option: $1"
			usage
			;;
		esac
		shift
	done
}

# ──────────────────────────── helpers ────────────────────────────

# WSL interop appends the WINDOWS PATH to ours, so tools installed on the
# Windows side (node, python, git, ...) appear as /mnt/c/... shims. They are
# NOT Linux binaries: `sudo` cannot even see them (secure_path drops /mnt/*),
# and a global `npm install -g` through the shim would land on the WINDOWS
# side, invisible to WSL vim. Treat /mnt/* resolutions as "not installed" so
# the real Linux packages get installed instead.
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

check_bin() {
	if have_native_cmd "$1"; then
		echo -e "  ${PASS} ${2:-$1}"
		return 0
	else
		echo -e "  ${FAIL} ${2:-$1}"
		return 1
	fi
}

check_cmd() {
	# Usage: check_cmd "description" -- command args...
	local desc="$1"
	shift
	if "$@" &>/dev/null; then
		echo -e "  ${PASS} ${desc}"
		return 0
	else
		echo -e "  ${FAIL} ${desc}"
		ALL_PASSED=false
		return 1
	fi
}

check_vim_version() {
	local ver
	ver=$(vim --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+' || true)
	if [[ -z "$ver" ]]; then
		echo -e "  ${FAIL} vim (not found)"
		ALL_PASSED=false
		return 1
	fi
	local major minor
	major=${ver%%.*}
	minor=${ver#*.}
	if ((major > 9 || (major == 9 && minor >= 1))); then
		echo -e "  ${PASS} vim ${ver}"
		return 0
	else
		echo -e "  ${FAIL} vim ${ver} (need >= 9.1)"
		ALL_PASSED=false
		return 1
	fi
}

os_detect() {
	case "$(uname -s)" in
	Linux)
		if [ -f /etc/os-release ]; then
			. /etc/os-release
			case "$ID" in
			ubuntu | debian | linuxmint | pop | elementary | zorin) echo "debian" ;;
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

OS=$(os_detect)

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

# Package names that should prefer Homebrew over the system package
# manager: system repos ship versions that lag far behind (fzf: 0.44 on
# Ubuntu noble vs current 0.7x). Append more names here as needed.
BREW_FIRST=(fzf)

# ────────────────── package index refresh ──────────────────
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

# System package manager install (no Homebrew). Returns non-zero when the
# OS is unknown or the manager fails, so callers can fall back to brew.
install_with_system_mgr() {
	refresh_pkg
	case "$OS" in
	debian) sudo_cmd apt-get install -y "$@" ;;
	arch) sudo_cmd pacman -S --noconfirm "$@" ;;
	opensuse) sudo_cmd zypper --non-interactive install -y "$@" ;;
	centos)
		# Some tools (universal-ctags, global, global-ctags, fzf, bat, pygments) come from EPEL
		sudo_cmd dnf install -y epel-release || true
		local -a _args=("$@")
		[[ " ${_args[*]} " =~ " global " ]] && _args+=(global-ctags)
		sudo_cmd dnf install -y "${_args[@]}"
		;;
	*) return 1 ;;
	esac
}

install_pkg() {
	if ! $INSTALL_MODE; then return 1; fi
	# Split the request: names in BREW_FIRST go through Homebrew (when it
	# exists, falling back to the system manager on failure), everything
	# else through the OS package manager as before.
	local -a brew_pkgs=() rest=()
	local _rc=0
	local p
	for p in "$@"; do
		if [[ " ${BREW_FIRST[*]} " == *" $p "* ]] && have_native_cmd brew; then
			brew_pkgs+=("$p")
		else
			rest+=("$p")
		fi
	done
	# System-manager batch FIRST, Homebrew LAST: every `brew` invocation
	# resets the sudo timestamp (brew.sh runs `sudo --reset-timestamp` at
	# startup), so any sudo work after a brew call would re-prompt. Doing
	# all sudo work before brew keeps the run at one password entry.
	if ((${#rest[@]} > 0)); then
		install_with_system_mgr "${rest[@]}" ||
			brew install "${rest[@]}" ||
			_rc=1 # system manager failed — brew fallback
	fi
	if ((${#brew_pkgs[@]} > 0)); then
		brew install "${brew_pkgs[@]}" || install_with_system_mgr "${brew_pkgs[@]}" || _rc=1
	fi
	# Freshly installed binaries may be shadowed by bash's per-process
	# command hash cache (a /mnt shim executed earlier in this same run);
	# re-scan PATH. Run AFTER capturing _rc — hash -r must not mask the
	# install status.
	hash -r
	return "$_rc"
}

ensure_rust() {
	# Install Rust via rustup if not present
	if ! have_native_cmd rustup; then
		echo -e "  ${YELLOW}→ installing rustup...${NC}"
		curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs |
			sh -s -- -y 2>/dev/null || {
			echo -e "  ${RED}→ rustup install failed${NC}"
			return 1
		}
	fi
	if [ -f "$HOME/.cargo/env" ]; then
		# shellcheck disable=SC1091
		. "$HOME/.cargo/env"
	fi
	have_native_cmd cargo && return 0
}

ensure_go_env() {
	# 'go install' drops binaries in $(go env GOPATH)/bin (default ~/go/bin),
	# which is usually not on PATH — make them visible for this run.
	if have_native_cmd go; then
		local gopath
		gopath=$(go env GOPATH 2>/dev/null || echo "$HOME/go")
		export PATH="$gopath/bin:$PATH"
	fi
}

go_install() {
	# 'go install' is silent for its ENTIRE module download + compile, which
	# takes minutes on the first run — announce it so the wait is explainable.
	# The notice goes to stdout on purpose: call sites may discard stderr.
	echo -e "  ${CYAN}→ go install ${1%@*} (building, no output — may take a few minutes)${NC}"
	go install "$@"
}

ensure_npm() {
	# Debian/Ubuntu: `apt install nodejs` does NOT bring npm (it is only a
	# Suggests), so npm must be installed explicitly.
	have_native_cmd node && have_native_cmd npm && return 0
	echo -e "  ${YELLOW}→ installing npm...${NC}"
	install_pkg "$(pkg_name npm)" || true
	# Verify the install actually put a native npm on PATH: install_pkg can
	# return success ("already newest") while PATH still only resolves to a
	# Windows shim — fail loudly instead of silently using the shim.
	have_native_cmd npm || {
		echo -e "  ${RED}→ npm is still not a native Linux binary (Windows shim on PATH?)${NC}"
		return 1
	}
}

# Global npm install that works everywhere:
#   - user-writable prefix (e.g. Homebrew): no sudo — also avoids the sudo
#     secure_path problem, where root cannot see brew's npm at all;
#   - system prefix (e.g. /usr from apt): retry with sudo.
npm_install_g() {
	ensure_npm || return 1
	local prefix
	prefix=$(npm config get prefix 2>/dev/null)
	if [ -n "$prefix" ] && { [ -w "$prefix" ] || [ -w "$prefix/lib" ]; }; then
		npm install -g "$@"
	else
		sudo_cmd npm install -g "$@"
	fi
}

install_optional_bin() {
	local bin="$1"
	local ok=true
	ensure_go_env
	case "$bin" in
	rg)
		install_pkg "$(pkg_name "$bin")" ||
			{
				echo -e "  ${CYAN}→ cargo install ripgrep (source build, no output — may take several minutes)${NC}"
				cargo install ripgrep 2>/dev/null
			} ||
			ok=false
		;;
	gopls)
		go_install golang.org/x/tools/gopls@latest
		;;
	pylsp)
		install_pkg "$(pkg_name "$bin")" 2>/dev/null ||
			sudo_cmd pip3 install python-lsp-server 2>/dev/null ||
			pip3 install python-lsp-server 2>/dev/null ||
			ok=false
		;;
	cargo)
		ensure_rust || ok=false
		;;
	rust-analyzer)
		if ensure_rust; then
			rustup component add rust-analyzer
		else
			ok=false
		fi
		;;
	bash-language-server)
		npm_install_g bash-language-server
		;;
	shfmt)
		go_install mvdan.cc/sh/v3/cmd/shfmt@latest 2>/dev/null || install_pkg shfmt || ok=false
		;;
	staticcheck)
		go_install honnef.co/go/tools/cmd/staticcheck@latest 2>/dev/null || ok=false
		;;
	black)
		install_pkg "$(pkg_name "$bin")" 2>/dev/null ||
			sudo_cmd pip3 install black 2>/dev/null ||
			pip3 install black 2>/dev/null ||
			ok=false
		;;
	clang-tidy)
		install_pkg "$(pkg_name "$bin")" || ok=false
		;;
	vim-language-server)
		npm_install_g vim-language-server
		;;
	typescript-language-server)
		npm_install_g typescript-language-server typescript
		;;
	tsc)
		npm_install_g typescript
		;;
	vscode-json-language-server)
		npm_install_g vscode-langservers-extracted
		;;
	yaml-language-server)
		npm_install_g yaml-language-server
		;;
	lua-language-server)
		install_pkg "$(pkg_name "$bin")" || brew install lua-language-server 2>/dev/null || ok=false
		;;
	glow)
		install_pkg "$(pkg_name "$bin")" || brew install glow 2>/dev/null || go_install github.com/charmbracelet/glow@latest 2>/dev/null || ok=false
		;;
	marksman)
		install_pkg "$(pkg_name "$bin")" || brew install marksman 2>/dev/null || ok=false
		;;
	efm-langserver)
		go_install github.com/mattn/efm-langserver@latest 2>/dev/null || ok=false
		;;
	prettier)
		npm_install_g prettier
		;;
	markdownlint-cli2)
		npm_install_g markdownlint-cli2
		;;
	zig)
		brew install zig 2>/dev/null || install_pkg "$(pkg_name "$bin")" || ok=false
		;;
	zls)
		brew install zls 2>/dev/null || install_pkg "$(pkg_name "$bin")" || ok=false
		;;
	*)
		install_pkg "$(pkg_name "$bin")" || ok=false
		;;
	esac
	$ok
}

get_install_hint() {
	case "$OS" in
	debian) echo "sudo apt-get install ${*}" ;;
	opensuse) echo "sudo zypper install ${*}" ;;
	centos) echo "sudo dnf install ${*}" ;;
	arch) echo "sudo pacman -S ${*}" ;;
	macos) echo "brew install ${*}" ;;
	linux-unknown) echo "install ${*} manually or 'brew install ${*}'" ;;
	*) echo "install ${*} manually" ;;
	esac
}

# Install hint for an optional binary (used outside --install mode).
hint_for() {
	case "$1" in
	clangd) echo "$(get_install_hint clangd)  # or clangd-15+" ;;
	gcc | g++ | python3) echo "$(get_install_hint "$1")" ;;
	go) echo "https://go.dev/dl/" ;;
	gopls) echo "go install golang.org/x/tools/gopls@latest" ;;
	pylsp) echo "$(get_install_hint "$(pkg_name pylsp)")  # or: pip install python-lsp-server" ;;
	cargo) echo "https://rustup.rs/  # then: rustup component add rust-analyzer" ;;
	rust-analyzer) echo "rustup component add rust-analyzer" ;;
	node) echo "https://nodejs.org/  # or: $(get_install_hint nodejs npm)" ;;
	bash-language-server) echo "npm install -g bash-language-server" ;;
	shfmt) echo "go install mvdan.cc/sh/v3/cmd/shfmt@latest" ;;
	staticcheck) echo "go install honnef.co/go/tools/cmd/staticcheck@latest" ;;
	black) echo "$(get_install_hint "$(pkg_name black)")  # or: pip3 install black" ;;
	clang-tidy) echo "$(get_install_hint clang-tidy)" ;;
	vim-language-server) echo "npm install -g vim-language-server" ;;
	typescript-language-server) echo "npm install -g typescript-language-server typescript" ;;
	tsc) echo "npm install -g typescript" ;;
	vscode-json-language-server) echo "npm install -g vscode-langservers-extracted" ;;
	yaml-language-server) echo "npm install -g yaml-language-server" ;;
	lua-language-server) echo "$(get_install_hint lua-language-server)" ;;
	efm-langserver) echo "go install github.com/mattn/efm-langserver@latest" ;;
	prettier) echo "npm install -g prettier" ;;
	markdownlint-cli2) echo "npm install -g markdownlint-cli2" ;;
	marksman) echo "$(get_install_hint marksman)" ;;
	zig) echo "brew install zig  # or: https://ziglang.org/download/" ;;
	zls) echo "brew install zls  # or: https://zigtools.org/zls/install/  (must match zig version)" ;;
	glow) echo "$(get_install_hint glow)  # or: go install github.com/charmbracelet/glow@latest" ;;
	esac
}

# ────────────────── dependency definitions ──────────────────
# NOTE: no `declare -A` anywhere — macOS still ships bash 3.2, which does
# not support associative arrays. Bin→name and bin→package lookups are
# done with case functions instead, and all collections are plain indexed
# arrays (supported since bash 2.0).

REQUIRED_BINS=(curl git rg ctags fzf)
RECOMMENDED_BINS=(bat global pygmentize python)

# Human-readable name for a dependency binary.
dep_name() {
	case "$1" in
	rg) echo "ripgrep" ;;
	ctags) echo "universal-ctags" ;;
	global) echo "global (GNU Global, for gtags)" ;;
	pygmentize) echo "pygments (gtags parser for non-C/C++ languages)" ;;
	python) echo "python (unversioned → python3, gtags pygments parser runtime)" ;;
	*) echo "$1" ;;
	esac
}

# Package name for a binary on the detected OS. Only entries that differ
# from the binary name need a case arm; everything else falls through.
pkg_name() {
	local bin="$1"
	case "$OS:$bin" in
	# Debian / apt
	debian:rg) echo "ripgrep" ;;
	debian:ctags) echo "universal-ctags" ;;
	debian:pygmentize) echo "python3-pygments" ;;
	debian:go) echo "golang-go" ;;
	debian:node) echo "nodejs" ;;
	debian:pylsp) echo "python3-pylsp" ;;
	# Arch / pacman
	arch:rg) echo "ripgrep" ;;
	arch:clangd | arch:clang-tidy) echo "clang" ;;
	arch:g++) echo "gcc" ;;
	arch:python3) echo "python" ;;
	arch:node) echo "nodejs" ;;
	arch:pylsp) echo "python-lsp-server" ;;
	arch:pygmentize) echo "python-pygments" ;;
	arch:black) echo "python-black" ;;
	# macOS / brew
	macos:ctags) echo "universal-ctags" ;;
	macos:clangd | macos:clang-tidy) echo "llvm" ;;
	macos:g++) echo "gcc" ;;
	macos:python3) echo "python" ;;
	macos:pylsp) echo "python-lsp-server" ;;
	macos:pygmentize) echo "pygments" ;;
	# openSUSE / zypper
	opensuse:rg) echo "ripgrep" ;;
	opensuse:ctags) echo "universal-ctags" ;;
	opensuse:pygmentize) echo "python3-Pygments" ;;
	opensuse:clangd | opensuse:clang-tidy) echo "clang" ;;
	opensuse:g++) echo "gcc-c++" ;;
	opensuse:node) echo "nodejs" ;;
	opensuse:pylsp) echo "python-python-lsp-server" ;;
	opensuse:black) echo "python3-black" ;;
	# CentOS-family / dnf
	centos:rg) echo "ripgrep" ;;
	centos:ctags) echo "universal-ctags" ;;
	centos:pygmentize) echo "python3-pygments" ;;
	centos:clangd | centos:clang-tidy) echo "clang-tools-extra" ;;
	centos:g++) echo "gcc-c++" ;;
	centos:go) echo "golang" ;;
	centos:node) echo "nodejs" ;;
	centos:pylsp) echo "python3-lsp-server" ;;
	centos:black) echo "python3-black" ;;
	*)
		echo "$bin"
		;;
	esac
}

# ──────────── language-grouped optional deps ────────────

# Note: NOT named GROUPS — that is a special (effectively readonly) bash
# array holding the current user's group IDs.
DEP_GROUPS=("C/C++" "Go" "Python" "Zig" "Rust" "Lua" "Shell" "Vim" "JavaScript/TypeScript" "JSON" "YAML" "Markdown" "Optional tools")

# Space-separated binaries for each language group.
deps_for_group() {
	case "$1" in
	"C/C++") echo "gcc g++ clangd clang-tidy" ;;
	"Go") echo "go gopls staticcheck" ;;
	"Python") echo "python3 pylsp black" ;;
	"Zig") echo "zig zls" ;;
	"Rust") echo "cargo rust-analyzer" ;;
	"Lua") echo "lua-language-server" ;;
	"Shell") echo "node bash-language-server shfmt" ;;
	"Vim") echo "node vim-language-server" ;;
	"JavaScript/TypeScript") echo "node typescript-language-server tsc" ;;
	"JSON") echo "node vscode-json-language-server" ;;
	"YAML") echo "node yaml-language-server" ;;
	"Markdown") echo "marksman efm-langserver prettier markdownlint-cli2" ;;
	"Optional tools") echo "glow" ;;
	esac
}

# ──────────────────── phases ────────────────────

print_header() {
	echo -e "${BOLD}monkey-vim dependency check${NC}"
	echo ""
}

print_vim_version() {
	echo -e "${BOLD}Vim version${NC}"
	check_vim_version
	echo ""
}

print_platform() {
	echo -e "${BOLD}Platform${NC}"
	echo -e "  OS: ${CYAN}$(uname -s)${NC}"
	case "$OS" in
	debian) echo -e "  Package manager: ${CYAN}apt${NC}" ;;
	opensuse) echo -e "  Package manager: ${CYAN}zypper${NC}" ;;
	centos) echo -e "  Package manager: ${CYAN}dnf${NC}" ;;
	arch) echo -e "  Package manager: ${CYAN}pacman${NC}" ;;
	macos) echo -e "  Package manager: ${CYAN}homebrew${NC}" ;;
	*) echo -e "  ${WARN} Unsupported OS — install dependencies manually" ;;
	esac
	echo ""
}

# Sets MISSING_REQUIRED.
check_required_tools() {
	echo -e "${BOLD}Required tools${NC}"
	MISSING_REQUIRED=()
	local bin
	for bin in "${REQUIRED_BINS[@]}"; do
		if check_bin "$bin" "$(dep_name "$bin")"; then
			:
		else
			MISSING_REQUIRED+=("$bin")
		fi
	done
	echo ""
}

check_python3() {
	# TIOCSTI injection (install.sh's end-of-run terminal activation) needs
	# python3 — system perl is the runtime fallback, never installed here,
	# so it is not detected.
	echo -e "${BOLD}python3${NC} (TIOCSTI injection)"
	check_bin python3 "python3 (required by TIOCSTI injection)" || MISSING_REQUIRED+=("python3")
	echo ""
}

# The required checks, in ONE place: main runs them up front, and
# install_missing_required re-runs them after installing — the install
# changed the world, so the verdict (ALL_PASSED / MISSING_REQUIRED) is
# always recomputed from here and never carried over stale.
run_required_checks() {
	ALL_PASSED=true
	MISSING_REQUIRED=()
	print_vim_version
	check_required_tools
	check_python3
	# check_bin records into MISSING_REQUIRED without poisoning — the
	# verdict must also reflect what the checks recorded.
	[[ ${#MISSING_REQUIRED[@]} -eq 0 ]] || ALL_PASSED=false
}

install_missing_required() {
	if ! $INSTALL_MODE || [[ ${#MISSING_REQUIRED[@]} -eq 0 ]]; then
		return 0
	fi
	echo -e "${YELLOW}Installing: ${MISSING_REQUIRED[*]}...${NC}"
	local pkgs=() bin b
	for b in "${MISSING_REQUIRED[@]}"; do pkgs+=("$(pkg_name "$b")"); done
	if install_pkg "${pkgs[@]}"; then
		run_required_checks
		if [[ ${#MISSING_REQUIRED[@]} -eq 0 ]]; then
			echo -e "${GREEN}All required tools now available.${NC}"
		else
			echo -e "${RED}Run: $(get_install_hint "$(for b in "${MISSING_REQUIRED[@]}"; do pkg_name "$b"; done | tr '\n' ' ')")${NC}"
		fi
	else
		echo -e "${RED}Install command failed. Run: $(get_install_hint "${pkgs[*]}")${NC}"
	fi
	echo ""
}

# Sets MISSING_RECOMMENDED.
check_recommended_tools() {
	echo -e "${BOLD}Recommended tools${NC}"
	echo "  (Missing won't block monkey-vim, but will degrade preview / gtags experience)"
	MISSING_RECOMMENDED=()
	local bin
	for bin in "${RECOMMENDED_BINS[@]}"; do
		if check_bin "$bin" "$(dep_name "$bin")"; then
			:
		else
			if [[ "$bin" == "bat" ]] && have_native_cmd batcat; then
				echo -e "    ${PASS} batcat (Debian alias for bat)"
			else
				echo -e "    ${FAIL} $(dep_name "$bin")"
				MISSING_RECOMMENDED+=("$bin")
			fi
		fi
	done
	echo ""
}

install_missing_recommended() {
	if ! $INSTALL_MODE || [[ ${#MISSING_RECOMMENDED[@]} -eq 0 ]]; then
		return 0
	fi
	echo -e "${YELLOW}Installing: ${MISSING_RECOMMENDED[*]}...${NC}"
	local pkgs=() b
	for b in "${MISSING_RECOMMENDED[@]}"; do
		# python needs a distro-specific install (see install_python_for_gtags)
		[[ "$b" == python ]] && continue
		pkgs+=("$(pkg_name "$b")")
	done
	if ((${#pkgs[@]} > 0)); then
		if install_pkg "${pkgs[@]}"; then
			echo -e "${GREEN}Done.${NC}"
		else
			echo -e "${RED}Failed. Run: $(get_install_hint "${pkgs[*]}")${NC}"
		fi
	fi
	if [[ " ${MISSING_RECOMMENDED[*]} " == *" python "* ]]; then
		if install_python_for_gtags; then
			echo -e "  ${GREEN}✓ python available${NC}"
		else
			echo -e "  ${RED}✗ failed to set up unversioned python${NC}"
			echo -e "    hint: $(get_install_hint python-is-python3) or: sudo ln -sf "$(command -v python3)" /usr/local/bin/python"
		fi
	fi
	echo ""
}

# gtags pygments parser plugins invoke unversioned `python`, but there is
# no reliable cross-distro package for it: Debian ships /usr/bin/python only
# through the python-is-python3 shim; openSUSE provides none; the RHEL/Fedora
# python-unversioned-command package is missing on some releases (CentOS 7)
# — so: install python3, then fall back to a /usr/local/bin/python symlink.
# /usr/bin/python3 is distro-managed and stable everywhere, and /usr/local/bin
# precedes /usr/bin on PATH.
install_python_for_gtags() {
	have_native_cmd python && return 0
	if [[ "$OS" == debian ]]; then
		install_pkg python-is-python3 && return 0
	else
		install_pkg "$(pkg_name python3)" || true
	fi
	have_native_cmd python && return 0
	local py3
	py3=$(command -v python3 2>/dev/null) || return 1
	sudo_cmd ln -sf "$py3" /usr/local/bin/python
	hash -r
	have_native_cmd python
}

install_optional_deps() {
	if ! $INSTALL_MODE; then
		return 0
	fi
	MISSING_OPTIONAL=()
	local group bin
	for group in "${DEP_GROUPS[@]}"; do
		for bin in $(deps_for_group "$group"); do
			if ! have_native_cmd "$bin"; then
				MISSING_OPTIONAL+=("$bin")
			fi
		done
	done

	if [[ ${#MISSING_OPTIONAL[@]} -gt 0 ]]; then
		echo -e "${YELLOW}Installing optional LSP servers & tools: ${MISSING_OPTIONAL[*]}...${NC}"
		for bin in "${MISSING_OPTIONAL[@]}"; do
			echo -e "  ${YELLOW}→ installing ${bin}...${NC}"
			if install_optional_bin "$bin"; then
				echo -e "  ${GREEN}✓ ${bin} installed${NC}"
			else
				echo -e "  ${RED}✗ failed to install ${bin}${NC}"
				echo -e "    hint: $(get_install_hint "${bin}")"
			fi
		done
		echo -e "${GREEN}Done with optional installs.${NC}"
	else
		echo -e "${GREEN}All optional LSP servers & tools already installed.${NC}"
	fi
	echo ""
}

check_optional_listing() {
	echo -e "${BOLD}Optional: LSP servers & language tools${NC}"
	echo "  (Install only what you need; missing servers won't block monkey-vim)"
	echo ""

	local group bin status
	for group in "${DEP_GROUPS[@]}"; do
		echo -e "  ${BOLD}${group}${NC}"
		for bin in $(deps_for_group "$group"); do
			status=0
			check_bin "$bin" &>/dev/null || status=$?
			if [[ $status -eq 0 ]]; then
				echo -e "    ${PASS} ${bin}"
			else
				echo -e "    ${FAIL} ${bin}  ${NC}$(hint_for "$bin")"
			fi
		done
		echo ""
	done
}

check_terminal_caps() {
	echo -e "${BOLD}Terminal capabilities${NC}"
	if [[ -n "${COLORTERM:-}" ]]; then
		echo -e "  ${PASS} COLORTERM=${COLORTERM}"
	elif [[ "$TERM" =~ (256color|tmux|screen|alacritty|kitty|wezterm|xterm-kitty) ]]; then
		echo -e "  ${PASS} TERM=${TERM} (true color capable)"
	else
		echo -e "  ${WARN} TERM=${TERM} — true color may not work"
	fi
	if [[ -n "${DISPLAY:-}" || -n "${WAYLAND_DISPLAY:-}" || "$OS" == "macos" ]]; then
		echo -e "  ${PASS} Clipboard support available"
	else
		echo -e "  ${WARN} No display server — clipboard may be unavailable"
	fi
	if [[ "$LANG" == *".UTF-8" || "$LANG" == *".utf8" ]]; then
		echo -e "  ${PASS} LANG=${LANG}"
	else
		echo -e "  ${WARN} LANG=${LANG} (UTF-8 recommended)"
	fi
	echo ""
}

check_config_files() {
	# --skip-check-config (passed by install.sh): the config symlinks are
	# linked AFTER this script runs, so judging them here would fail every
	# chained run and burn all three retries. Standalone runs (the manual
	# diagnosis entry point) still get the full check.
	if $SKIP_CONFIG_CHECKS; then
		echo -e "  ${WARN} config checks skipped (handled by the installer)"
		return 0
	fi
	echo -e "${BOLD}Config files${NC}"
	local vimrc="${HOME}/.vimrc" swap_dir="${HOME}/.cache/vim/swap"
	local cache_dir="${HOME}/.cache/vim/sessions" viminfo_dir="${HOME}/.cache/vim/viminfo"
	if [[ -L "$vimrc" ]]; then
		local target
		target=$(readlink -f "$vimrc" 2>/dev/null || readlink "$vimrc")
		echo -e "  ${PASS} .vimrc → ${target}"
	elif [[ -f "$vimrc" ]]; then
		echo -e "  ${WARN} .vimrc exists but is not a symlink"
	else
		echo -e "  ${FAIL} .vimrc not found (run: ln -sf $(pwd)/.vimrc ~/.vimrc)"
		ALL_PASSED=false
	fi

	if [ -d "$swap_dir" ]; then
		echo -e "  ${PASS} swap/ dir exists"
	else
		echo -e "  ${WARN} swap/ dir not found (auto-created on first vim launch)"
	fi

	if [ -L "${HOME}/.config/efm-langserver" ] || [ -f "${HOME}/.config/efm-langserver/config.yaml" ]; then
		echo -e "  ${PASS} efm-langserver config"
	elif [ -d "configs/efm-langserver" ]; then
		echo -e "  ${WARN} efm-langserver config not linked (run: ln -sfn $(pwd)/configs/efm-langserver ~/.config/efm-langserver)"
	fi

	if [ -d "$cache_dir" ]; then
		echo -e "  ${PASS} session cache dir exists"
	else
		echo -e "  ${WARN} session cache dir not found (auto-created on first session save)"
	fi

	if [ -d "$viminfo_dir" ]; then
		echo -e "  ${PASS} viminfo dir exists"
	else
		echo -e "  ${WARN} viminfo dir not found (auto-created on first vim launch)"
	fi

	echo ""
}

print_summary() {
	if $ALL_PASSED; then
		echo -e "${GREEN}${BOLD}All required dependencies satisfied.${NC}"
		exit 0
	else
		echo -e "${RED}${BOLD}Some required dependencies are missing.${NC}"
		if ! $INSTALL_MODE; then
			echo -e "Run ${CYAN}$0 --install${NC} to install them automatically."
		fi
		exit 1
	fi
}

# ──────────────────── main ────────────────────

main() {
	parse_args "$@"
	OS=$(os_detect)
	print_header
	print_platform
	run_required_checks
	install_missing_required
	check_recommended_tools
	install_missing_recommended
	install_optional_deps
	check_optional_listing
	check_terminal_caps
	check_config_files
	print_summary
}

main "$@"
