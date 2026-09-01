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

usage() {
	cat <<EOF
Usage: $0 [OPTIONS]

Check and optionally install dependencies for monkey-vim.

OPTIONS
  -i, --install    Install missing dependencies
  -h, --help       Show this help

Exit code: 1 if any required dependency is missing, 0 otherwise.
EOF
	exit 0
}

while [[ $# -gt 0 ]]; do
	case "$1" in
	-i | --install) INSTALL_MODE=true ;;
	-h | --help) usage ;;
	*)
		echo "Unknown option: $1"
		usage
		;;
	esac
	shift
done

# ──────────────────────────── helpers ────────────────────────────

check_bin() {
	if command -v "$1" &>/dev/null; then
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
	if command -v sudo &>/dev/null; then
		sudo "$@"
	else
		"$@"
	fi
}

# Package names that should prefer Homebrew over the system package
# manager: system repos ship versions that lag far behind (fzf: 0.44 on
# Ubuntu noble vs current 0.7x). Append more names here as needed.
BREW_FIRST=(fzf)

install_pkg() {
	if ! $INSTALL_MODE; then return 1; fi
	# Split the request: names in BREW_FIRST go through Homebrew (when it
	# exists, falling back to the system manager on failure), everything
	# else through the OS package manager as before.
	local -a brew_pkgs=() rest=()
	local p
	for p in "$@"; do
		if [[ " ${BREW_FIRST[*]} " == *" $p "* ]] && command -v brew &>/dev/null; then
			brew_pkgs+=("$p")
		else
			rest+=("$p")
		fi
	done
	if ((${#brew_pkgs[@]} > 0)); then
		if ! brew install "${brew_pkgs[@]}"; then
			rest+=("${brew_pkgs[@]}") # brew failed — fall back to the system manager
		fi
	fi
	if ((${#rest[@]} > 0)); then
		case "$OS" in
		debian) sudo_cmd apt-get install -y "${rest[@]}" || brew install "${rest[@]}" ;;
		arch) sudo_cmd pacman -S --noconfirm "${rest[@]}" || brew install "${rest[@]}" ;;
		opensuse) sudo_cmd zypper --non-interactive install -y "${rest[@]}" || brew install "${rest[@]}" ;;
		centos)
			# Some tools (universal-ctags, global, global-ctags, fzf, bat, pygments) come from EPEL
			sudo_cmd dnf install -y epel-release || true
			local -a _args=("${rest[@]}")
			[[ " ${_args[*]} " =~ " global " ]] && _args+=(global-ctags)
			sudo_cmd dnf install -y "${_args[@]}" || brew install "${rest[@]}"
			;;
		macos) brew install "${rest[@]}" ;;
		*) brew install "${rest[@]}" 2>/dev/null || return 1 ;;
		esac
	fi
}

ensure_rust() {
	# Install Rust via rustup if not present
	if ! command -v rustup &>/dev/null; then
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
	command -v cargo &>/dev/null
}

ensure_go_env() {
	# 'go install' drops binaries in $(go env GOPATH)/bin (default ~/go/bin),
	# which is usually not on PATH — make them visible for this run.
	if command -v go &>/dev/null; then
		local gopath
		gopath=$(go env GOPATH 2>/dev/null || echo "$HOME/go")
		export PATH="$gopath/bin:$PATH"
	fi
}

ensure_npm() {
	# Debian/Ubuntu: `apt install nodejs` does NOT bring npm (it is only a
	# Suggests), so npm must be installed explicitly.
	command -v npm &>/dev/null && return 0
	echo -e "  ${YELLOW}→ installing npm...${NC}"
	install_pkg "$(pkg_name npm)"
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
		install_pkg "$(pkg_name "$bin")" || cargo install ripgrep 2>/dev/null || ok=false
		;;
	gopls)
		go install golang.org/x/tools/gopls@latest
		;;
	pylsp)
		install_pkg "$(pkg_name "$bin")" 2>/dev/null ||
			sudo pip3 install python-lsp-server 2>/dev/null ||
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
		go install mvdan.cc/sh/v3/cmd/shfmt@latest 2>/dev/null || install_pkg shfmt || ok=false
		;;
	staticcheck)
		go install honnef.co/go/tools/cmd/staticcheck@latest 2>/dev/null || ok=false
		;;
	black)
		install_pkg "$(pkg_name "$bin")" 2>/dev/null ||
			sudo pip3 install black 2>/dev/null ||
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
		install_pkg "$(pkg_name "$bin")" || brew install glow 2>/dev/null || go install github.com/charmbracelet/glow@latest 2>/dev/null || ok=false
		;;
	marksman)
		install_pkg "$(pkg_name "$bin")" || brew install marksman 2>/dev/null || ok=false
		;;
	efm-langserver)
		go install github.com/mattn/efm-langserver@latest 2>/dev/null || ok=false
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

# ────────────────── dependency definitions ──────────────────
# NOTE: no `declare -A` anywhere — macOS still ships bash 3.2, which does
# not support associative arrays. Bin→name and bin→package lookups are
# done with case functions instead, and all collections are plain indexed
# arrays (supported since bash 2.0).

REQUIRED_BINS=(curl git rg ctags fzf)
RECOMMENDED_BINS=(bat global pygmentize)

# Human-readable name for a dependency binary.
dep_name() {
	case "$1" in
	rg) echo "ripgrep" ;;
	ctags) echo "universal-ctags" ;;
	global) echo "global (GNU Global, for gtags)" ;;
	pygmentize) echo "pygments (gtags parser for non-C/C++ languages)" ;;
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

# ──────────────────── main ────────────────────

echo -e "${BOLD}monkey-vim dependency check${NC}"
echo ""

echo -e "${BOLD}Vim version${NC}"
check_vim_version
echo ""

# Check the OS
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

# ──── required tools ────
echo -e "${BOLD}Required tools${NC}"
MISSING_REQUIRED=()
for bin in "${REQUIRED_BINS[@]}"; do
	if check_bin "$bin" "$(dep_name "$bin")"; then
		:
	else
		MISSING_REQUIRED+=("$bin")
	fi
done
echo ""

if $INSTALL_MODE && [[ ${#MISSING_REQUIRED[@]} -gt 0 ]]; then
	echo -e "${YELLOW}Installing: ${MISSING_REQUIRED[*]}...${NC}"
	pkgs=()
	for b in "${MISSING_REQUIRED[@]}"; do pkgs+=("$(pkg_name "$b")"); done
	if install_pkg "${pkgs[@]}"; then
		MISSING_REQUIRED=()
		for bin in "${REQUIRED_BINS[@]}"; do
			if command -v "$bin" &>/dev/null; then
				echo -e "  ${PASS} $(dep_name "$bin") installed"
			else
				MISSING_REQUIRED+=("$bin")
				echo -e "  ${FAIL} $(dep_name "$bin") still missing"
			fi
		done
		if [[ ${#MISSING_REQUIRED[@]} -eq 0 ]]; then
			echo -e "${GREEN}All required tools now available.${NC}"
		else
			echo -e "${RED}Run: $(get_install_hint "$(for b in "${MISSING_REQUIRED[@]}"; do pkg_name "$b"; done | tr '\n' ' ')")${NC}"
		fi
	else
		echo -e "${RED}Install command failed. Run: $(get_install_hint "${pkgs[*]}")${NC}"
	fi
	echo ""
fi

if [[ ${#MISSING_REQUIRED[@]} -gt 0 ]]; then
	ALL_PASSED=false
fi

# ──── recommended tools ────
echo -e "${BOLD}Recommended tools${NC}"
echo "  (Missing won't block monkey-vim, but will degrade preview / gtags experience)"
MISSING_RECOMMENDED=()
for bin in "${RECOMMENDED_BINS[@]}"; do
	if check_bin "$bin" "$(dep_name "$bin")"; then
		:
	else
		if [[ "$bin" == "bat" ]] && command -v batcat &>/dev/null; then
			echo -e "    ${PASS} batcat (Debian alias for bat)"
		else
			echo -e "    ${FAIL} $(dep_name "$bin")"
			MISSING_RECOMMENDED+=("$bin")
		fi
	fi
done
echo ""

if $INSTALL_MODE && [[ ${#MISSING_RECOMMENDED[@]} -gt 0 ]]; then
	echo -e "${YELLOW}Installing: ${MISSING_RECOMMENDED[*]}...${NC}"
	pkgs=()
	for b in "${MISSING_RECOMMENDED[@]}"; do pkgs+=("$(pkg_name "$b")"); done
	if install_pkg "${pkgs[@]}"; then
		echo -e "${GREEN}Done.${NC}"
	else
		echo -e "${RED}Failed. Run: $(get_install_hint "${pkgs[*]}")${NC}"
	fi
	echo ""
fi

if $INSTALL_MODE; then
	MISSING_OPTIONAL=()
	for group in "${DEP_GROUPS[@]}"; do
		for bin in $(deps_for_group "$group"); do
			if ! command -v "$bin" &>/dev/null; then
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
fi

# ──── optional LSP servers ────
echo -e "${BOLD}Optional: LSP servers & language tools${NC}"
echo "  (Install only what you need; missing servers won't block monkey-vim)"
echo ""

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

# ──── terminal capabilities ────
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

# ──── config files ────
echo -e "${BOLD}Config files${NC}"
VIMRC="${HOME}/.vimrc"
REPO_DIR=""
if [[ -L "$VIMRC" ]]; then
	TARGET=$(readlink -f "$VIMRC" 2>/dev/null || readlink "$VIMRC")
	REPO_DIR=$(dirname "$TARGET")
	echo -e "  ${PASS} .vimrc → ${TARGET}"
elif [[ -f "$VIMRC" ]]; then
	echo -e "  ${WARN} .vimrc exists but is not a symlink"
else
	echo -e "  ${FAIL} .vimrc not found (run: ln -sf $(pwd)/.vimrc ~/.vimrc)"
	ALL_PASSED=false
fi

SWAP_DIR="${HOME}/.vim/swap"
if [ -d "$SWAP_DIR" ]; then
	echo -e "  ${PASS} swap/ dir exists"
else
	echo -e "  ${WARN} swap/ dir not found (auto-created on first vim launch)"
fi

if [ -L "${HOME}/.config/efm-langserver" ] || [ -f "${HOME}/.config/efm-langserver/config.yaml" ]; then
	echo -e "  ${PASS} efm-langserver config"
elif [ -d "configs/efm-langserver" ]; then
	echo -e "  ${WARN} efm-langserver config not linked (run: ln -sf $(pwd)/configs/efm-langserver ~/.config/efm-langserver)"
fi

CACHE_DIR="${HOME}/.cache/sessions"
if [ -d "$CACHE_DIR" ]; then
	echo -e "  ${PASS} session cache dir exists"
else
	echo -e "  ${WARN} session cache dir not found (auto-created on first session save)"
fi

echo ""

# ──── summary ────
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
