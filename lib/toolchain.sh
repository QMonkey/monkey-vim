# monkey-scripts/lib/toolchain.sh — language-ecosystem toolchains: each
# section ensures the ecosystem's OWN installer works (rustup, go, npm, pip)
# and installs into it, bypassing the distro repositories (whose packages
# lag far behind). Sourced by lib/bootstrap.sh (both entry points); called
# from install_strategy_step (lib/pkg.sh) and by project install steps.
#
# Shared conventions:
#   - every network step goes through retry (lib/retry.sh);
#   - installs land in user-space bin dirs that export_path (lib/env.sh)
#     seeds — cargo/bin, GOPATH/bin, ~/.npm-global/bin;
#   - WSL: npm/node lookups MUST go through have_native_cmd — a /mnt/*
#     Windows shim would install into the Windows tree.

# ──────────────────────────── rust / cargo ────────────────────────────
# ensure_rust — rustup + cargo, idempotent. Download the official installer
# FULLY before executing (`curl | sh` would run a truncated script), then
# the -y toolchain install (rustup-init is idempotent, so a retry continues
# instead of starting over). Non-fatal: warns and returns 1 so
# install_strategy can try the next step; a plain caller under `set -e`
# still aborts on the non-zero return.
ensure_rust() {
	if have_native_cmd rustup && have_native_cmd cargo; then
		ok "rust toolchain already installed."
		return 0
	fi
	info "installing rustup..."
	local rustup_init="/tmp/rustup_init.$$.sh"
	if ! retry -t "$RETRY_T_NET" -s "rustup installer download" curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs -o "$rustup_init"; then
		rm -f "$rustup_init"
		warn "rustup install failed — install it manually: https://rust-lang.org/tools/install/"
		return 1
	fi
	if ! retry -t "$RETRY_T_HEAVY" -s "rustup toolchain install" sh "$rustup_init" -y; then
		rm -f "$rustup_init"
		warn "rustup install failed — install it manually: https://rust-lang.org/tools/install/"
		return 1
	fi
	rm -f "$rustup_init"
	# ~/.cargo/bin (or $CARGO_HOME/bin) now exists — export_path seeds it.
	have_native_cmd cargo
}

# ──────────────────────────── go ────────────────────────────
# 'go install' is silent for its entire module download + compile (minutes
# on the first run) — announce it. Retried; go caches modules, so a retry
# resumes instead of restarting.
go_install() {
	info "go install ${1%@*} (building, no output — may take a few minutes)"
	retry -t "$RETRY_T_NET" -s "go install ${1%@*}" go install "$@"
}

# ──────────────────────────── npm ────────────────────────────
# A plain `npm` can resolve to a /mnt/* Windows shim whose global prefix is
# the Windows tree; every npm/node lookup here goes through native_bin_path.
# Debian/Ubuntu: `apt install nodejs` does NOT bring npm (Suggests only), so
# npm must be installed explicitly and verified afterwards.
ensure_npm() {
	if have_native_cmd npm && have_native_cmd node; then
		# Brew's node (often a transitive formula dependency, e.g. mako
		# dragging node into the Cellar on CentOS) is acceptable here: it
		# satisfies npm tooling, and if a brew operation on that chain
		# ever removes it, the NEXT ensure_npm call no longer early-returns
		# and installs the distro nodejs instead — self-healing.
		return 0
	fi
	info "installing npm..."
	install_pkg "$(pkg_name npm)" || true
	# openSUSE has no standalone npm on some releases — the unversioned
	# nodejs package pulls the matching npm, so installing node repairs npm
	# without dragging brew's node in.
	if ! have_native_cmd npm && ! have_native_cmd node; then
		install_pkg "$(pkg_name node)" || true
	fi
	if ! have_native_cmd npm && have_native_cmd brew; then
		# Last native source on distros whose index has no nodejs/npm.
		brew_install_retry "$RETRY_T_NET" "brew install node" node || true
	fi
	if have_native_cmd npm && have_native_cmd node; then
		return 0
	fi
	warn "npm is still not available as a native binary — npm-based tools cannot be installed."
	return 1
}

# Global npm install that works everywhere:
#   - user-writable prefix: install directly, never through sudo (brew's npm
#     is invisible to root via secure_path);
#   - system prefix (e.g. /usr from apt): `npm i -g` would die with EACCES,
#     so the prefix is redirected ONCE to ~/.npm-global via a user-level
#     npmrc — this and every later global install run unprivileged.
#     persist_path puts ~/.npm-global/bin on PATH for future shells;
#   - npm >= 11.19 gates install scripts behind an allow-list (comma-
#     separated). tree-sitter-cli needs its script to fetch the native
#     binary, so scripts are allowed for exactly the packages handed in.
npm_install_g() {
	ensure_npm || return 1
	local prefix in_brew=false
	prefix=$(npm config get prefix 2>/dev/null)
	# npm globals must not live inside Homebrew's tree: they would be wiped
	# with the Cellar on a brew upgrade/reinstall of node (observed on
	# openSUSE Tumbleweed).
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
	# Retried like every other network op (bounded by RETRY_ACTIVE_COUNT
	# inside an outer retry).
	retry -t "$RETRY_T_NET" -s "npm install -g $*" npm install -g ${flags[@]+"${flags[@]}"} "$@"
	# Freshly installed binaries may be shadowed by bash's command hash.
	hash -r
}

# ──────────────────────────── pip / python ────────────────────────────
# pip3 must exist (and RUN) before any `pip:` install strategy — it is a
# separate package on every distro, and Leap 16's repos do not package
# python-lsp-server at all, so pylsp depends on the pip fallback.
ensure_pip() {
	if ! have_native_cmd pip3; then
		info "Installing pip3 via the system package manager..."
		install_pkg "$(pkg_name pip3)" || return 1
		have_native_cmd pip3 || return 1
	fi
	# A pip3 that exists but crashes on import must not short-circuit the
	# repair (observed on Leap 16: python3.13 built against a newer libexpat
	# than the installed runtime — pip dies at startup, or --version is
	# green but the first install crashes importing pyexpat). Both heal by
	# updating libexpat1. The pyexpat probe is openSUSE-gated.
	pip_ok() {
		pip3 --version >/dev/null 2>&1 || return 1
		[ "${OS:-}" = opensuse ] || return 0
		python3 -c 'import pyexpat' >/dev/null 2>&1
	}
	if ! pip_ok; then
		warn "pip3 is installed but fails to run — runtime library mismatch on a not-fully-updated system?"
		if [ "${OS:-}" = opensuse ] && have_native_cmd zypper; then
			info "updating libexpat1 (the known Leap 16 victim)..."
			sudo_cmd zypper update -y libexpat1 >/dev/null 2>&1 || true
			# The targeted update may not be enough when python3 came from a
			# newer snapshot than the rest of the system — a full upgrade
			# heals every such version skew at once.
			if ! pip_ok; then
				info "libexpat1 alone did not fix it — running a full system upgrade (this can take a while)..."
				retry -t "$RETRY_T_HEAVY" -s "zypper update (full)" sudo_cmd zypper update -y --auto-agree-with-licenses >/dev/null 2>&1 || true
			fi
		fi
		if ! pip_ok; then
			warn "pip3 still not runnable — update the system packages and re-run."
			return 1
		fi
	fi
	ok "pip3 ready."
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
