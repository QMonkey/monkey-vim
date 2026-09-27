# monkey-scripts/lib/optional.sh — optional-tooling helpers.
#
# Sourced by scripts/checkhealth.sh (the installer flow also runs through
# checkhealth, so install.sh gets these via the checkhealth run).
#
# The functions here are the *strategies* referenced by the `install` field
# of a dependency spec (npm:x, go:x, cargo:x, rustup, python-unversioned...).
# The per-binary hint printed next to a missing optional tool is derived from
# the same strategy chain — a project may override `optional_hint` after
# sourcing this file.

# Install rustup (if needed) and make cargo/rust-analyzer available.
ensure_rust() {
	if ! have_native_cmd rustup; then
		info "installing rustup..."
		curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs |
			sh -s -- -y 2>/dev/null || {
			warn "rustup install failed"
			return 1
		}
	fi
	if [ -f "$HOME/.cargo/env" ]; then
		# shellcheck disable=SC1091
		. "$HOME/.cargo/env"
		export PATH="$HOME/.cargo/bin:$PATH"
	fi
	have_native_cmd cargo && return 0
}

# Debian/Ubuntu: `apt install nodejs` does NOT bring npm (it is only a
# Suggests), so npm must be installed explicitly. Verify afterwards: install_pkg
# can return success while PATH still resolves to a Windows shim.
ensure_npm() {
	have_native_cmd node && have_native_cmd npm && return 0
	info "installing npm..."
	install_pkg "$(pkg_name npm)" || true
	have_native_cmd npm || {
		warn "npm is still not a native Linux binary (Windows shim on PATH?)"
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

# 'go install' is silent for its ENTIRE module download + compile, which
# takes minutes on the first run — announce it so the wait is explainable.
go_install() {
	info "go install ${1%@*} (building, no output — may take a few minutes)"
	go install "$@"
}

# `python` must exist as well as `python3` (global tooling such as gtags
# runs on the unversioned name). Debian/Ubuntu ship python-is-python3;
# elsewhere symlink /usr/local/bin/python to python3.
install_python_for_gtags() {
	have_native_cmd python && return 0
	if [ "$OS_FAMILY" = "debian" ]; then
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

# ──────────────────────── hints ────────────────────────
# Human command for one strategy step ("" when unknown).
_strategy_hint() {
	local kind="$1" args="$2" b
	case "$kind" in
	pkg)
		if [ -n "$args" ]; then
			for b in $args; do
				get_install_hint "$b"
			done | tr '\n' ' '
		else
			get_install_hint "$SPEC_ID"
		fi
		;;
	npm)
		echo "npm install -g $args"
		;;
	go)
		echo "go install $args"
		;;
	cargo)
		echo "cargo install $args"
		;;
	pip)
		echo "pip3 install $args"
		;;
	brew)
		echo "brew install $args"
		;;
	rustup)
		echo "https://rustup.rs/"
		;;
	rustup-component)
		echo "rustup component add $args"
		;;
	python-unversioned)
		echo "ln -s \$(command -v python3) /usr/local/bin/python"
		;;
	esac
}

# Default hint: join the hints of every strategy step with "# or:".
# Projects may define their own `optional_hint` after sourcing this file.
optional_hint() {
	local bin="$1" spec strategy rest step kind args h out=""
	spec=$(find_spec "$bin") || spec="$bin"
	parse_spec "$spec"
	strategy="${SPEC_INSTALL:-pkg}"
	rest="$strategy"
	while [ -n "$rest" ]; do
		step="${rest%%,*}"
		if [ "$rest" = "$step" ]; then
			rest=""
		else
			rest="${rest#*,}"
		fi
		kind="${step%%:*}"
		args=""
		if [ "$step" != "$kind" ]; then
			args="${step#*:}"
		fi
		h=$(_strategy_hint "$kind" "$args")
		[ -n "$h" ] || continue
		if [ -z "$out" ]; then
			out="$h"
		else
			out="$out # or: $h"
		fi
	done
	case "$bin" in
	# Wording/comments the pure strategy chain cannot express.
	clangd) out="${out}  # or clangd-15+" ;;
	zig) out="${out}  # or: https://ziglang.org/download/" ;;
	zls) out="${out}  # or: https://zigtools.org/zls/install/  (must match zig version)" ;;
	cargo) out="https://rustup.rs/  # then: rustup component add rust-analyzer" ;;
	rust-analyzer) out="rustup component add rust-analyzer" ;;
	go) out="https://go.dev/dl/" ;;
	node) out="https://nodejs.org/  # or: $(get_install_hint nodejs npm)" ;;
	esac
	printf '%s' "$out"
}
