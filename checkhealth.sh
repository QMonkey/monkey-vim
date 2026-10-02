#!/usr/bin/env bash
set -euo pipefail

# ──────────────────────────────────────────────────────────────
# monkey-vim dependency check
#
# The check framework lives in scripts/ (a `git subtree` of
# github.com/QMonkey/monkey-scripts) — this file only declares WHAT to check.
# ──────────────────────────────────────────────────────────────

. "$(dirname "${BASH_SOURCE[0]:-$0}")/scripts/checkhealth.sh" || {
	echo "monkey-scripts not found — update this checkout (git pull / re-clone)," >&2
	echo "or run install.sh, which bootstraps monkey-scripts itself." >&2
	exit 1
}

# ──────────────────────── identity ────────────────────────
PROJECT=monkey-vim

# ──────────────────────── version gate ────────────────────────
MAIN_VERSION="vim|ver:9.1|vim|none"
MAIN_VERSION_TITLE="Vim version"

# ──────────────────────── required ────────────────────────
REQUIRED_CHECKS=(
	"@header|Required tools"
	"curl|bin|curl"
	"git|bin|git"
	"rg|bin|ripgrep"
	"ctags|bin|universal-ctags"
	"fzf|bin|fzf"
	"@header|python3${NC} (TIOCSTI injection)"
	"python3|bin|python3 (required by TIOCSTI injection)"
)

# ──────────────────────── recommended ────────────────────────
# fzf ships far newer via Homebrew than most distro repos — prefer brew
# when it exists (install_pkg splits the batch on these names).
BREW_FIRST=(fzf)
RECOMMENDED_NOTE="(Missing won't block monkey-vim, but will degrade preview / gtags experience)"
RECOMMENDED_CHECKS=(
	"@call|check_bat"
	"global|bin|global (GNU Global, for gtags)|pkg"
	"pygmentize|bin|pygments (gtags parser for non-C/C++ languages)|pkg"
	"python|bin|python (unversioned → python3, gtags pygments parser runtime)|python-unversioned"
)

# check_bat: the check is a project hook (Debian ships the bat binary as
# batcat); the install strategy lives in EXTRA_SPECS — installed, never listed.
EXTRA_SPECS=(
	"bat|bin|bat|pkg"
)
check_bat() {
	if have_native_cmd bat; then
		ok "bat"
	elif have_native_cmd batcat; then
		ok "  batcat (Debian alias for bat)"
	else
		fail "bat"
		record_missing recommended "bat"
	fi
}

# ──────────────────────── optional: LSP servers & language tools ─────────────
# Grouped by language (8th spec field); each entry's install strategy mirrors
# install_optional_bin upstream (system package first, brew/go/npm/pip after).
OPTIONAL_SECTION_TITLE="Optional: LSP servers & language tools"
OPTIONAL_INSTALL_TITLE="Installing optional LSP servers & tools"
OPTIONAL_SECTION_NOTE="(Install only what you need; missing servers won't block monkey-vim)"
INSTALL_OPTIONAL=1
OPTIONAL_ALL_PRESENT_MSG="All optional LSP servers & tools already installed."
OPTIONAL_DONE_MSG="Done with optional installs."
OPTIONAL_CHECKS=(
	"gcc|bin|gcc|pkg||||C/C++"
	"g++|bin|g++|pkg||||C/C++"
	"clangd|bin|clangd|pkg||||C/C++"
	"clang-tidy|bin|clang-tidy|pkg||||C/C++"
	"go|bin|go|pkg||||Go"
	"gopls|bin|gopls|go:golang.org/x/tools/gopls@latest||||Go"
	"staticcheck|bin|staticcheck|go:honnef.co/go/tools/cmd/staticcheck@latest||||Go"
	"python3|bin|python3|pkg||||Python"
	"pylsp|bin|pylsp|pkg,pip:python-lsp-server||||Python"
	"black|bin|black|pkg,pip:black||||Python"
	"zig|bin|zig|brew:zig,pkg||||Zig"
	"zls|bin|zls|brew:zls,pkg||||Zig"
	"cargo|bin|cargo|rustup||||Rust"
	"rust-analyzer|bin|rust-analyzer|rustup-component:rust-analyzer||||Rust"
	"lua-language-server|bin|lua-language-server|pkg,brew:lua-language-server||||Lua"
	"node|bin|node|pkg||||Shell"
	"bash-language-server|bin|bash-language-server|npm:bash-language-server||||Shell"
	"shfmt|bin|shfmt|go:mvdan.cc/sh/v3/cmd/shfmt@latest,pkg||||Shell"
	"node|bin|node|pkg||||Vim"
	"vim-language-server|bin|vim-language-server|npm:vim-language-server||||Vim"
	"node|bin|node|pkg||||JavaScript/TypeScript"
	"typescript-language-server|bin|typescript-language-server|npm:typescript-language-server typescript||||JavaScript/TypeScript"
	"tsc|bin|tsc|npm:typescript||||JavaScript/TypeScript"
	"node|bin|node|pkg||||JSON"
	"vscode-json-language-server|bin|vscode-json-language-server|npm:vscode-langservers-extracted||||JSON"
	"node|bin|node|pkg||||YAML"
	"yaml-language-server|bin|yaml-language-server|npm:yaml-language-server||||YAML"
	"marksman|bin|marksman|pkg,brew:marksman||||Markdown"
	"efm-langserver|bin|efm-langserver|go:github.com/mattn/efm-langserver@latest||||Markdown"
	"prettier|bin|prettier|npm:prettier||||Markdown"
	"markdownlint-cli2|bin|markdownlint-cli2|npm:markdownlint-cli2||||Markdown"
	"glow|bin|glow|pkg,brew:glow,go:github.com/charmbracelet/glow@latest||||Optional tools"
)

# ──────────────────────── install steps ────────────────────────
# Verbatim upstream: batch-install the missing package names, then
# re-run the required checks (re-print) and hint at what is left.


# Verbatim upstream install table and hints: the generic strategy
# chain cannot reproduce upstream's per-binary fallbacks (e.g. the
# gopls arm reports success unconditionally) nor its curated FAIL
# hints, so both are carried over as-is.

go_install() {
	# 'go install' is silent for its ENTIRE module download + compile, which
	# takes minutes on the first run — announce it so the wait is explainable.
	# The notice goes to stdout on purpose: call sites may discard stderr.
	echo -e "  ${CYAN}→ go install ${1%@*} (building, no output — may take a few minutes)${NC}"
	go install "$@"
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
				retry -t 1800 -s "cargo install ripgrep" cargo install ripgrep
			} ||
			ok=false
		;;
	gopls)
		go_install golang.org/x/tools/gopls@latest
		;;
	pylsp)
		install_pkg "$(pkg_name "$bin")" 2>/dev/null ||
		{
			ensure_pip &&
				{ retry -t 1800 -s "pip3 install python-lsp-server" sudo_cmd pip3 install python-lsp-server ||
					retry -t 1800 -s "pip3 install python-lsp-server" pip3 install python-lsp-server; }
		} ||
			ok=false
		;;
	cargo)
		ensure_rust || ok=false
		;;
	rust-analyzer)
		if ensure_rust; then
			retry -t 1800 -s "rustup component add rust-analyzer" rustup component add rust-analyzer
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
		{
			ensure_pip &&
				{ retry -t 1800 -s "pip3 install black" sudo_cmd pip3 install black ||
					retry -t 1800 -s "pip3 install black" pip3 install black; }
		} ||
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
		install_pkg "$(pkg_name "$bin")" || retry -t 1800 -s "brew install lua-language-server" brew install lua-language-server || ok=false
		;;
	glow)
		install_pkg "$(pkg_name "$bin")" || retry -t 1800 -s "brew install glow" brew install glow || go_install github.com/charmbracelet/glow@latest 2>/dev/null || ok=false
		;;
	marksman)
		install_pkg "$(pkg_name "$bin")" || retry -t 3600 -s "brew install marksman" brew install marksman || ok=false
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
		retry -t 3600 -s "brew install zig" brew install zig || install_pkg "$(pkg_name "$bin")" || ok=false
		;;
	zls)
		retry -t 3600 -s "brew install zls" brew install zls || install_pkg "$(pkg_name "$bin")" || ok=false
		;;
	*)
		install_pkg "$(pkg_name "$bin")" || ok=false
		;;
	esac
	$ok
}

optional_hint() {
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

# ──────────────────────── config ────────────────────────
# src|dst|desc|mode|name|hint — .vimrc is a repo file; the cache dirs are
# auto-created on first launch, so they are advisory hints below. hint
# reproduces upstream's verbatim missing-fail text (ln -sf, not -sfn).
CONFIG_LINKS=(
	"$(pwd)/.vimrc|$HOME/.vimrc|.vimrc||.vimrc|.vimrc not found (run: ln -sf $(pwd)/.vimrc ~/.vimrc)"
)
# type|params|ok|incomplete|missing
CONFIG_HINTS=(
	"path|$HOME/.cache/vim/swap|swap/ dir exists||swap/ dir not found (auto-created on first vim launch)"
	"any|$HOME/.config/efm-langserver $HOME/.config/efm-langserver/config.yaml !$(pwd)/configs/efm-langserver|efm-langserver config|efm-langserver config not linked (run: ln -sfn $(pwd)/configs/efm-langserver ~/.config/efm-langserver)|"
	"path|$HOME/.cache/vim/sessions|session cache dir exists||session cache dir not found (auto-created on first session save)"
	"path|$HOME/.cache/vim/viminfo|viminfo dir exists||viminfo dir not found (auto-created on first vim launch)"
)

# ──────────────────────── terminal ────────────────────────
CHECK_TERMINAL_CAPS=1
TERMCAPS_STYLE=colorterm
CHECK_LANG=1
CHECK_CLIPBOARD=display

checkhealth_main "$@"
