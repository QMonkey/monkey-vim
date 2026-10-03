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
		# Download fully before executing, with retries — `curl | sh` would
		# run a truncated script if the connection drops mid-stream (same
		# pattern as the wezterm installer's rustup setup).
		local rustup_init="/tmp/rustup_init.$$.sh"
		if retry -t 1800 -s "rustup installer download" curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs -o "$rustup_init"; then
			# The -y run downloads the whole toolchain (hundreds of MB) —
			# long timeout, and retried: rustup-init is idempotent, a retry
			# continues instead of starting over.
			retry -t 3600 -s "rustup toolchain install" sh "$rustup_init" -y ||
				{
					warn "rustup install failed"
					return 1
				}
			rm -f "$rustup_init"
		else
			warn "rustup installer download failed"
			return 1
		fi
	fi
	if [ -f "$HOME/.cargo/env" ]; then
		# shellcheck disable=SC1091
		. "$HOME/.cargo/env"
		export PATH="$HOME/.cargo/bin:$PATH"
	fi
	have_native_cmd cargo && return 0
}

# ─────────────────────────── npm / node ───────────────────────────
# WSL interop injects the Windows PATH after the Linux one but BEFORE the
# brew append lands (login shells build PATH: interop, then profile blocks)
# — so a plain `npm` can resolve to a /mnt/* Windows shim whose "global
# prefix" is the Windows tree: `npm i -g` installs where Linux tools can
# never see it. Every npm/node lookup that matters goes through
# native_bin_path, which skips shim candidates (its shim pattern defaults
# pattern.
# Debian/Ubuntu: `apt install nodejs` does NOT bring npm (it is only a
# Suggests), so npm must be installed explicitly. Verify afterwards: install_pkg
# can return success while PATH still resolves to a Windows shim.
ensure_npm() {
	# have_native_cmd is shim-aware (it wraps native_bin_path): a /mnt/*
	# Windows shim counts as "not installed", so the native node/npm below
	# get installed even when the Windows tree carries its own. PATH
	# ordering — brew before the Windows shims, system before brew — is
	# guaranteed by path_add_pre_win (common.sh) in the preseed, re-expose
	# and persisted-profile layers, so a plain `npm` call in npm_install_g
	# resolves to the native binary everywhere.
	if have_native_cmd npm && have_native_cmd node; then
		return 0
	fi
	info "installing npm..."
	install_pkg "$(pkg_name npm)" || true
	# openSUSE has no standalone npm name on some releases — the unversioned
	# nodejs package pulls the matching npm as a dependency, so installing
	# node repairs npm without dragging brew's node in (which used to be the
	# outcome here: every global package then landed in the brew prefix).
	if ! have_native_cmd npm && ! have_native_cmd node; then
		install_pkg "$(pkg_name node)" || true
	fi
	if ! have_native_cmd npm && have_native_cmd brew; then
		# Last native source on distros whose index has no nodejs/npm —
		# and whose only npm would otherwise be the Windows shim.
		retry -t 1800 -s "brew install node" brew install node || true
	fi
	if have_native_cmd npm && have_native_cmd node; then
		return 0
	fi
	warn "npm is still not available as a native binary — npm-based tools cannot be installed."
	return 1
}

# Global npm install that works everywhere:
#   - user-writable prefix (Homebrew node, nvm, an adopted ~/.npm-global):
#     installed directly, never through sudo — brew's npm is invisible to
#     root via secure_path, and the postinstall scripts allow-listed below
#     must not run as root anyway;
#   - system prefix (e.g. /usr from apt): a plain `npm i -g` would die with
#     EACCES (npm does NOT fall back to a user directory on its own), so
#     the prefix is redirected ONCE to ~/.npm-global via a user-level
#     npmrc — this install and every later `npm i -g` (ours or the user's)
#     then run unprivileged. persist_path puts ~/.npm-global/bin on PATH
#     for future shells; the current session is exported here.
#   - npm >= 11.19 gates install scripts behind an allow-list (warn-only
#     for now — a future major will hard-block). tree-sitter-cli's install
#     script downloads its native binary from GitHub releases; a blocked
#     script yields a CLI without a binary, so scripts are allowed for
#     exactly the packages being handed in (the flag's own semantics —
#     nothing third-party gets whitelisted). The list is comma-separated
#     (docs + verified: a space-joined value does not match). The flag is
#     unknown to older npm, hence the version gate. Global installs only:
#     npm errors when --allow-scripts is passed to a project-scoped install.
npm_install_g() {
	ensure_npm || return 1
	# ensure_npm has verified a NATIVE npm (shims rejected via
	# have_native_cmd — see native_bin_path) and the PATH ordering puts it
	# first, so the plain name resolves to it.
	local prefix in_brew=false
	prefix=$(npm config get prefix 2>/dev/null)
	# A prefix inside Homebrew's tree (node installed via the brew fallback)
	# is user-writable, but npm globals must not live there: they would be
	# wiped with the Cellar on a brew upgrade/reinstall of node, and
	# ~/.npm-global keeps them user-owned and independent of which node
	# currently owns /usr/bin or brew/bin (observed on openSUSE Tumbleweed:
	# every global package landed in /home/linuxbrew/.linuxbrew).
	if have_native_cmd brew; then
		local brew_prefix
		brew_prefix="$(brew --prefix 2>/dev/null)"
		case "$prefix" in
		"$brew_prefix" | "$brew_prefix"/*) in_brew=true ;;
		esac
	fi
	if [ -z "$prefix" ] || { [ ! -w "$prefix" ] && [ ! -w "$prefix/lib" ]; } || [ "$in_brew" = true ]; then
		info "npm prefix ${prefix:-<unset>} is not user-owned — switching global installs to $HOME/.npm-global."
		# --location=user: write ~/.npmrc, never a project-local npmrc.
		npm config set prefix "$HOME/.npm-global" --location=user || return 1
		prefix="$HOME/.npm-global"
		case ":$PATH:" in *":$prefix/bin:"*) ;; *) export PATH="$prefix/bin:$PATH" ;; esac
	fi
	local npmver joined
	npmver=$(npm --version 2>/dev/null)
	local -a flags=()
	if [ -n "$npmver" ] && version_ge "$npmver" "11.19"; then
		joined=$(
			IFS=,
			printf '%s' "$*"
		)
		flags+=(--allow-scripts="$joined")
	fi
	# Retried like every other network op. Inside run_checkhealth's outer
	# retry this runs once per outer attempt (the RETRY_ACTIVE_COUNT
	# guard), so the attempts stay bounded.
	retry -t 1800 -s "npm install -g $*" npm install -g ${flags[@]+"${flags[@]}"} "$@"
	# Freshly installed binaries may be shadowed by bash's command hash.
	hash -r
}

# 'go install' is silent for its ENTIRE module download + compile, which
# takes minutes on the first run — announce it so the wait is explainable.
# The module download is a network fetch: retried (go caches modules, so a
# retry resumes instead of restarting).
go_install() {
	info "go install ${1%@*} (building, no output — may take a few minutes)"
	retry -t 1800 -s "go install ${1%@*}" go install "$@"
}

# `python` must exist as well as `python3` (global tooling such as gtags
# runs on the unversioned name). Debian/Ubuntu ship python-is-python3;
# elsewhere symlink /usr/local/bin/python to python3.
install_python_for_gtags() {
	have_native_cmd python && return 0
	case "$OS" in
	debian | ubuntu)
		install_pkg python-is-python3 && return 0
		;;
	*)
		install_pkg "$(pkg_name python3)" || true
		;;
	esac
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
