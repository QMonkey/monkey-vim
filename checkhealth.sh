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
	ver=$(vim --version 2>/dev/null | head -1 | grep -oP '\d+\.\d+' || true)
	if [[ -z "$ver" ]]; then
		echo -e "  ${FAIL} vim (not found)"
		ALL_PASSED=false
		return 1
	fi
	local major minor
	major=${ver%%.*}
	minor=${ver#*.}
	if ((major > 9 || (major == 9 && minor >= 0))); then
		echo -e "  ${PASS} vim ${ver}"
		return 0
	else
		echo -e "  ${FAIL} vim ${ver} (need >= 9.0)"
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

install_pkg() {
	if ! $INSTALL_MODE; then return 1; fi
	case "$OS" in
	debian) sudo_cmd apt-get install -y "$@" ;;
	arch) sudo_cmd pacman -S --noconfirm "$@" ;;
	macos) brew install "$@" ;;
	*) return 1 ;;
	esac
}

install_optional_bin() {
	local bin="$1"
	local ok=true
	case "$bin" in
		rg)
			install_pkg "$(pkg_name "$bin")" || cargo install ripgrep 2>/dev/null || ok=false
			;;
		gopls)
			go install golang.org/x/tools/gopls@latest
			;;
		pylsp)
			pip3 install python-lsp-server
			;;
		rust-analyzer)
			rustup component add rust-analyzer
			;;
		bash-language-server)
			npm install -g bash-language-server
			;;
		vim-language-server)
			npm install -g vim-language-server
			;;
		typescript-language-server)
			npm install -g typescript-language-server typescript
			;;
		tsc)
			npm install -g typescript
			;;
		vscode-json-language-server)
			npm install -g vscode-langservers-extracted
			;;
		yaml-language-server)
			npm install -g yaml-language-server
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
		*)
			install_pkg "$(pkg_name "$bin")" || ok=false
			;;
	esac
	$ok
}

get_install_hint() {
	case "$OS" in
	debian) echo "sudo apt-get install ${*}" ;;
	arch) echo "sudo pacman -S ${*}" ;;
	macos) echo "brew install ${*}" ;;
	*) echo "install ${*} manually" ;;
	esac
}

# ────────────────── dependency definitions ──────────────────

declare -A REQUIRED=()
REQUIRED["curl"]="curl"
REQUIRED["git"]="git"
REQUIRED["rg"]="ripgrep"
REQUIRED["ctags"]="universal-ctags"
REQUIRED["cmake"]="cmake"

# packages for each OS (maps binary -> package name)
declare -A APT_NAMES=(
	["rg"]="ripgrep"
	["ctags"]="universal-ctags"
	["clangd"]="clangd"
	["clang-format"]="clang-format"
	["gcc"]="gcc"
	["g++"]="g++"
	["go"]="golang-go"
	["python3"]="python3"
	["node"]="nodejs"
)
declare -A PACMAN_NAMES=(
	["rg"]="ripgrep"
	["ctags"]="ctags"
	["clangd"]="clang"
	["clang-format"]="clang"
	["gcc"]="gcc"
	["g++"]="gcc"
	["go"]="go"
	["python3"]="python"
	["node"]="nodejs"
	["lua-language-server"]="lua-language-server"
	["marksman"]="marksman"
	["glow"]="glow"
)
declare -A BREW_NAMES=(
	["ctags"]="universal-ctags"
	["clangd"]="llvm"
	["clang-format"]="llvm"
	["gcc"]="gcc"
	["g++"]="gcc"
	["go"]="go"
	["python3"]="python"
	["node"]="node"
	["lua-language-server"]="lua-language-server"
	["marksman"]="marksman"
	["glow"]="glow"
)

pkg_name() {
	local bin="$1"
	case "$OS" in
	debian) echo "${APT_NAMES[$bin]:-$bin}" ;;
	arch) echo "${PACMAN_NAMES[$bin]:-$bin}" ;;
	macos) echo "${BREW_NAMES[$bin]:-$bin}" ;;
	*) echo "$bin" ;;
	esac
}

# ──────────── language-grouped optional deps ────────────

declare -A DEPS_BY_GROUP
DEPS_BY_GROUP["C/C++"]="gcc g++ clangd clang-format"
DEPS_BY_GROUP["Go"]="go gopls"
DEPS_BY_GROUP["Python"]="python3 pylsp"
DEPS_BY_GROUP["Rust"]="cargo rust-analyzer"
DEPS_BY_GROUP["Lua"]="lua-language-server"
DEPS_BY_GROUP["Shell"]="node bash-language-server"
DEPS_BY_GROUP["Vim"]="node vim-language-server"
DEPS_BY_GROUP["JavaScript/TypeScript"]="node typescript-language-server tsc"
DEPS_BY_GROUP["JSON"]="node vscode-json-language-server"
DEPS_BY_GROUP["YAML"]="node yaml-language-server"
DEPS_BY_GROUP["Markdown"]="marksman"
DEPS_BY_GROUP["Optional tools"]="glow"

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
arch) echo -e "  Package manager: ${CYAN}pacman${NC}" ;;
macos) echo -e "  Package manager: ${CYAN}homebrew${NC}" ;;
*) echo -e "  ${WARN} Unsupported OS — install dependencies manually" ;;
esac
echo ""

# ──── required tools ────
echo -e "${BOLD}Required tools${NC}"
MISSING_REQUIRED=()
for bin in curl git rg ctags cmake; do
	if check_bin "$bin" "${REQUIRED[$bin]}"; then
		:
	else
		MISSING_REQUIRED+=("$bin")
		ALL_PASSED=false
	fi
done
echo ""

if $INSTALL_MODE && [[ ${#MISSING_REQUIRED[@]} -gt 0 ]]; then
	echo -e "${YELLOW}Installing: ${MISSING_REQUIRED[*]}...${NC}"
	pkgs=()
	for b in "${MISSING_REQUIRED[@]}"; do pkgs+=("$(pkg_name "$b")"); done
	if install_pkg "${pkgs[@]}"; then
		echo -e "${GREEN}Done.${NC}"
	else
		echo -e "${RED}Failed. Run: $(get_install_hint "${pkgs[*]}")${NC}"
	fi
	echo ""
fi

if $INSTALL_MODE; then
	MISSING_OPTIONAL=()
	for group in "C/C++" "Go" "Python" "Rust" "Lua" "Shell" "Vim" "JavaScript/TypeScript" "JSON" "YAML" "Markdown" "Optional tools"; do
		for bin in ${DEPS_BY_GROUP[$group]}; do
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

if ! $INSTALL_MODE; then
	declare -A INSTALL_HINTS
	INSTALL_HINTS["clangd"]="$(get_install_hint clangd)  # or clangd-15+"
	INSTALL_HINTS["clang-format"]="$(get_install_hint clang-format)"
	INSTALL_HINTS["gcc"]="$(get_install_hint gcc)"
	INSTALL_HINTS["g++"]="$(get_install_hint g++)"
	INSTALL_HINTS["go"]="https://go.dev/dl/"
	INSTALL_HINTS["gopls"]="go install golang.org/x/tools/gopls@latest"
	INSTALL_HINTS["python3"]="$(get_install_hint python3)"
	INSTALL_HINTS["pylsp"]="pip install python-lsp-server"
	INSTALL_HINTS["cargo"]="https://rustup.rs/  # then: rustup component add rust-analyzer"
	INSTALL_HINTS["rust-analyzer"]="rustup component add rust-analyzer"
	INSTALL_HINTS["node"]="https://nodejs.org/  # or: $(get_install_hint nodejs npm)"
	INSTALL_HINTS["bash-language-server"]="npm install -g bash-language-server"
	INSTALL_HINTS["vim-language-server"]="npm install -g vim-language-server"
	INSTALL_HINTS["typescript-language-server"]="npm install -g typescript-language-server typescript"
	INSTALL_HINTS["tsc"]="npm install -g typescript"
	INSTALL_HINTS["vscode-json-language-server"]="npm install -g vscode-langservers-extracted"
	INSTALL_HINTS["yaml-language-server"]="npm install -g yaml-language-server"
	INSTALL_HINTS["lua-language-server"]="$(get_install_hint lua-language-server)"
	INSTALL_HINTS["marksman"]="$(get_install_hint marksman)"
	INSTALL_HINTS["glow"]="$(get_install_hint glow)  # or: go install github.com/charmbracelet/glow@latest"
fi

for group in "C/C++" "Go" "Python" "Rust" "Lua" "Shell" "Vim" "JavaScript/TypeScript" "JSON" "YAML" "Markdown" "Optional tools"; do
	echo -e "  ${BOLD}${group}${NC}"
	for bin in ${DEPS_BY_GROUP[$group]}; do
		status=0
		check_bin "$bin" &>/dev/null || status=$?
		if [[ $status -eq 0 ]]; then
			echo -e "    ${PASS} ${bin}"
		else
			echo -e "    ${FAIL} ${bin}  ${NC}${INSTALL_HINTS[$bin]}"
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
	echo -e "  ${FAIL} .vimrc not found (run: ln -s $(pwd)/.vimrc ~/.vimrc)"
	ALL_PASSED=false
fi

if [[ -n "$REPO_DIR" ]]; then
	if [[ -L "${HOME}/.clang-format" ]]; then
		CF_TARGET=$(readlink -f "${HOME}/.clang-format")
		echo -e "  ${PASS} .clang-format → ${CF_TARGET}"
	elif [[ -f "${HOME}/.clang-format" ]]; then
		echo -e "  ${WARN} .clang-format exists but is not a symlink (run: ln -sf ${REPO_DIR}/configs/.clang-format ~/.clang-format)"
	else
		echo -e "  ${WARN} .clang-format not found (run: ln -sf ${REPO_DIR}/configs/.clang-format ~/.clang-format)"
	fi
elif [[ -f "${HOME}/.clang-format" ]]; then
	echo -e "  ${PASS} .clang-format exists"
fi

SWAP_DIR="${HOME}/.vim/swap"
if [ -d "$SWAP_DIR" ]; then
	echo -e "  ${PASS} swap/ dir exists"
else
	echo -e "  ${WARN} swap/ dir not found (auto-created on first vim launch)"
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
