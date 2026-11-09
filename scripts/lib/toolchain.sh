# monkey-scripts/lib/toolchain.sh — language-ecosystem toolchains: each
# section ensures the ecosystem's OWN installer works (rustup, go, npm, pip)
# and installs into it, bypassing the distro repositories (whose packages
# lag far behind). Sourced by lib/bootstrap.sh (both entry points); called
# from install_strategy_step (lib/pkg.sh) and by project install steps.
#
# These are NOT lanes of the install chain (lib/pkg.sh): their target is a
# coordinate a package name cannot imply — a module path, a PyPI
# distribution, an npm package — so they only ever run as explicit spec
# steps, and the chain never routes a bare name into them.
#
# Shared conventions:
#   - every network step goes through retry (lib/retry.sh);
#   - installs land in user-space bin dirs that export_path (lib/env.sh)
#     seeds — cargo/bin, GOPATH/bin, ~/.npm-global/bin;
#   - ensure_* returns "usable", never "fatal": callers decide what a
#     missing toolchain costs, and a strategy step that fails only means the
#     next step runs;
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
# ensure_go — the Go toolchain, idempotent: a spec declaring go:x must not
# dead-end on a host with no go (`go install` there would die with
# command-not-found and leave the wreckage to the spec's next step).
# Provisioned through the CHAIN, not an upstream tarball: the distro golang
# package and the brew formula are current on every supported OS, so a
# second bootstrap path would mean version detection and archive extraction
# (plus a checksum policy) that no spec asks for yet. rc = "go is usable";
# install_strategy runs every step with `|| true`, so a failure here costs
# this lane and never the run.
ensure_go() {
	have_native_cmd go && return 0
	info "installing the go toolchain..."
	install_pkg "$(pkg_name go)" || true
	if ! have_native_cmd go && have_native_cmd brew; then
		# Last native source on distros whose index has no golang.
		brew_install go || true
	fi
	if have_native_cmd go; then
		ok "go ready ($(go version 2>/dev/null))."
		return 0
	fi
	warn "go is still not available — install it manually: $(get_install_hint go)"
	return 1
}

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
ensure_node_and_npm() {
	if have_native_cmd npm && have_native_cmd node; then
		# Brew's node (often a transitive formula dependency, e.g. mako
		# dragging node into the Cellar on CentOS) is acceptable here: it
		# satisfies npm tooling, and if a brew operation on that chain
		# ever removes it, the NEXT ensure_node_and_npm call no longer
		# early-returns and installs the distro nodejs instead —
		# self-healing.
		return 0
	fi
	# Node first: it is the root dependency — the distro nodejs package
	# pulls the matching npm (openSUSE ships no standalone npm on some
	# releases), and brew's node formula includes it. npm second, for the
	# distros that split it from nodejs (Debian).
	if ! have_native_cmd node; then
		info "installing node..."
		# One call, one chain: the bottle route for a distro index that has
		# no nodejs is the chain's own brew lane, so this needs no second,
		# hand-written `brew install node` behind it. (ensure_node_at_least
		# below DOES keep its own bottle call — that one is about the
		# VERSION the index offers, which no chain can infer.)
		install_pkg "$(pkg_name node)" || true
	fi
	if ! have_native_cmd npm; then
		info "installing npm..."
		install_pkg "$(pkg_name npm)" || true
	fi
	if have_native_cmd node && have_native_cmd npm; then
		return 0
	fi
	warn "node/npm are still not available as native binaries — npm-based tools cannot be installed."
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
# ensure_node_at_least <major.minor> — provision a Node.js meeting a
# version floor (a bare ensure_node_and_npm only guarantees EXISTENCE:
# distro indexes ship 18/20 on older releases, and npm merely warns on
# engines mismatch). Routes, in order: whatever is already installed;
# the distro npm/node packages (ensure_node_and_npm); Homebrew — which
# ships a CURRENT node on every platform, covering hosts whose distro
# index is too old (brew's bin dir is auto-linked; keg-only does not
# apply to the node formula). rc 0 only when bin_at_least node <min>
# passes afterwards; otherwise the caller warns and handles.
ensure_node_at_least() {
	local min="$1"
	ensure_node_and_npm || true
	bin_at_least node "$min" && return 0
	if have_native_cmd brew; then
		info "Node.js $min+ required — the distro index is too old; installing via Homebrew..."
		brew_install node || true
		# On Linux the brew bin dir sits late on PATH (and a distro node 18/20
		# may shadow it): this link is the point of the step, not a fallback
		# side effect — the spec asked for a node the distro index does not
		# offer, so the fresh node/npm go into ~/.local/bin (seeded at the
		# FRONT of PATH by export_path) and node resolves to the brew install.
		# That is why this calls brew_link_bins directly instead of relying on
		# brew_install. On macOS the step needs no link at all — the prefix is
		# prepended there (lib/env.sh), so the brew node already wins; the call
		# is kept for the Linux side and declines itself on the mac one.
		brew_link_bins node npm
		hash -r
		bin_at_least node "$min" && return 0
	fi
	warn "Node.js $min+ is still not available (found: $(node -v 2>/dev/null || printf '%s\n' none)) — install it manually: $(get_install_hint node)"
	return 1
}

npm_install_g() {
	ensure_node_and_npm || return 1
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
# install_pip_pkgs <pypi-dist>... — the pip step's installer, moved out of
# the strategy dispatcher so pkg.sh stays free of Python-domain knowledge
# (its header says the core routes and reports; this is the "how").
#
# USER-SPACE install (~/.local/lib/python3.X) first: pip installs here are
# editor-grade user tools, and a sudo prompt inside this retried command
# would die of SIGTTIN (sudo_cmd fails the attempt). User site stays on this
# interpreter's sys.path (distro pylsp loads the plugin), is
# user-owned/removable, and matches the npm/cargo/go convention; console
# scripts land in ~/.local/bin (bin_dirs seeds it at the front of PATH). The
# sudo route is the fallback.
#
# PEP 668: Fedora 38+ / Debian 12+ / Ubuntu 23.04+ / Tumbleweed mark the
# system python EXTERNALLY-MANAGED — pip refuses ALL installs into it,
# --user included. Old pips reject the flag itself, so add it only when this
# pip knows it AND the marker is present. venv/pipx are NOT options: pylsp
# loads plugins via entry points from ITS OWN interpreter, so isolation
# hides them; pipx-ing the whole pylsp stack would overturn the
# distro-package-first policy for one plugin gap.
#
# stderr stays visible on purpose — a silently swallowed pip error is what
# made the Leap 16 pylsp failure undiagnosable.
install_pip_pkgs() {
	# ensure_pip first: the fallback dies with command-not-found when pip3 is
	# missing (Leap 16).
	ensure_pip || return 1
	local user_flags="--user" sys_flags=""
	if pip3 install --help 2>/dev/null | grep -q -- --break-system-packages &&
		[ -f "$(python3 -c 'import sysconfig; print(sysconfig.get_path("stdlib"))' 2>/dev/null)/EXTERNALLY-MANAGED" ]; then
		user_flags="$user_flags --break-system-packages"
		sys_flags="--break-system-packages"
	fi
	retry -t "$RETRY_T_NET" -s "pip3 install $*" pip3 install $user_flags "$@" ||
		retry -t "$RETRY_T_NET" -s "pip3 install $*" sudo_cmd pip3 install $sys_flags "$@"
}

# ensure_pip — pip3 must exist (and RUN) before any `pip:` install strategy:
# it is a separate package on every distro, and Leap 16's repos do not
# package python-lsp-server at all, so pylsp depends on the pip fallback.
ensure_pip() {
	if ! have_native_cmd pip3; then
		info "Installing pip3 via the system package manager..."
		install_pkg "$(pkg_name pip3)" || return 1
		have_native_cmd pip3 || return 1
	fi
	# A pip3 that exists but crashes on import must not short-circuit the
	# repair (observed on Leap 16: the interpreter is built against a newer
	# libexpat than the installed runtime — pip dies at startup, or
	# --version is green but the first install crashes importing pyexpat).
	# Both heal by updating libexpat1. The pyexpat probe is openSUSE-gated.
	pip_ok() {
		pip3 --version >/dev/null 2>&1 || return 1
		[ "$OS" = opensuse ] || return 0
		python3 -c 'import pyexpat' >/dev/null 2>&1
	}
	if ! pip_ok; then
		warn "pip3 is installed but fails to run — runtime library mismatch on a not-fully-updated system?"
		if [ "$OS" = opensuse ] && have_native_cmd zypper; then
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
