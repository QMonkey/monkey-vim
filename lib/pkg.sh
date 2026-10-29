# monkey-scripts/lib/pkg.sh — the DISPATCH CORE of the installer domains:
# install_pkg (the sys→brew-fallback orchestrator), the install-strategy
# dispatcher over every installer, and the shared batch classifier.
#
# Sourced by scripts/install.sh and scripts/checkhealth.sh (via
# lib/bootstrap.sh).
#
# Sibling domains (sourced alongside, called at runtime):
#   lib/distro.sh     the distro package-manager family (apt / pacman /
#                     zypper / dnf + AUR) — install_pkg's PRIMARY lane
#   lib/brew.sh       Homebrew — install_pkg's fallback and BREW_FIRST lane
#   lib/toolchain.sh  language-ecosystem installers (rustup / go / npm / pip)
#     — install_strategy_step dispatches into all three domain files.
#
# The core stays domain-free: it routes and reports, the domains own the
# "how". Everything below is safe to call from either entry point.

# filter_pkgs <probe> <name>... — classify names through <probe>: the ones it
# accepts land in PKG_VALID, the rest in UNKNOWN_PKGS. warn_unknown_pkgs
# reports the dropped names; call it right after filter_pkgs. Shared by the
# system, Homebrew and AUR install passes.
PKG_VALID=()
UNKNOWN_PKGS=()
filter_pkgs() {
	local probe="$1" p
	shift
	PKG_VALID=()
	UNKNOWN_PKGS=()
	for p in "$@"; do
		if "$probe" "$p"; then
			PKG_VALID+=("$p")
		else
			UNKNOWN_PKGS+=("$p")
		fi
	done
}

# The usual pairing: classify through <probe>, then report the dropped names.
filter_pkgs_warn() {
	filter_pkgs "$@"
	warn_unknown_pkgs
}

warn_unknown_pkgs() {
	local p
	# Pattern-match dedupe, not `local -A`: macOS still ships bash 3.2 (same
	# reason pkg_name is a case function).
	local -a reported=()
	for p in ${UNKNOWN_PKGS[@]+"${UNKNOWN_PKGS[@]}"}; do
		# The same unmapped name arrives once per batch (required AND
		# recommended both referenced wlogout) — report it once.
		case " ${reported[*]-} " in *" $p "*) continue ;; esac
		reported+=("$p")
		warn "$p not found in the package index — skipped (one bad name would fail the whole batch)"
	done
}

# System package install with Homebrew fallback. Gated on INSTALL_MODE
# (checkhealth installs only under --install); recycles bash's command hash.
#
# Both managers get a probe pass before their batch: one unknown name aborts
# the WHOLE transaction, so probe_pkg_name / probe_brew_name drop such names
# up front (read-only, sudo-free, milliseconds per name; a missing manager
# binary disables the probe).
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
				# Brew is the fallback for names the system index LACKS —
				# never for system-packaged tools whose install failed (a
				# blind fallback once installed wl-clipboard, wireplumber
				# and mako from bottles on arch while pacman was down). An
				# unreachable index makes every probe reject, so the canary
				# below skips the fallback during outages (the outer retry
				# heals later). macOS: no system manager — brew is primary.
				local -a bpkg=()
				local b canary fallback_allowed=1
				if [ "${OS:-}" != macos ]; then
					canary=$(_pkg_index_canary)
					if [ -n "$canary" ] && ! probe_pkg_name "$canary"; then
						warn "system package index unreachable — skipping the brew fallback; the retry loop heals later."
						fallback_allowed=0
					fi
					if [ "$fallback_allowed" -eq 1 ]; then
						for b in "${rest[@]}"; do
							probe_pkg_name "$(pkg_name "$b")" || bpkg+=("$(pkg_name "$b")")
						done
					fi
				else
					for b in "${rest[@]}"; do bpkg+=("$(pkg_name "$b" brew)"); done
				fi
				if [ "$fallback_allowed" -eq 1 ]; then
					filter_pkgs_warn probe_brew_name "${bpkg[@]}"
					# All names filtered: the arithmetic test fails and _rc
					# records it — same as an actual failed brew call.
					if ((${#PKG_VALID[@]} > 0)); then
						brew_install_retry "$RETRY_T_NET" "brew install (fallback)" ${PKG_VALID[@]+"${PKG_VALID[@]}"}
					else
						false
					fi
				else
					false
				fi
			else
				false
			fi
		} || _rc=1
	fi
	if ((${#brew_pkgs[@]} > 0)); then
		filter_pkgs_warn probe_brew_name "${brew_pkgs[@]}"
		if ((${#PKG_VALID[@]} > 0)); then
			local brc=0
			# The BREW_FIRST batch can carry heavy formulae (zig pulls
			# llvm@22 + lld@22) — RETRY_T_HUGE gives those downloads room.
			brew_install_retry "$RETRY_T_HUGE" "brew install" ${PKG_VALID[@]+"${PKG_VALID[@]}"} || brc=$?
			# A timed-out brew (rc 124) may still have COMPLETED the install
			# (the timeout kills the wrapper after the binaries land):
			# blindly falling back to the system package would install a
			# SECOND copy shadowing the brew one (observed on every WSL
			# distro: system AND brew zig/zls). Only fall back for names
			# that do not resolve at all.
			if [ "$brc" -ne 0 ]; then
				local -a missing=() q
				for q in ${PKG_VALID[@]+"${PKG_VALID[@]}"}; do
					have_native_cmd "$q" || missing+=("$q")
				done
				if ((${#missing[@]} > 0)); then
					install_sys_pkg ${missing[@]+"${missing[@]}"} || _rc=1
				fi
			fi
			# Link UNCONDITIONALLY, never gated on the batch's rc: a timed-out
			# brew can still have completed the install, and a batch can pull
			# an unrelated BREW_FIRST tool as a DEPENDENCY (brew zls installs
			# zig transitively) with no successful batch rc of its own. brew_link_bins
			# skips any name brew does not provide, so the wide call is
			# harmless when the batch genuinely failed.
			brew_link_bins ${BREW_FIRST[@]+"${BREW_FIRST[@]}"}
		else
			_rc=1
		fi
	fi
	# Freshly installed binaries may be shadowed by bash's per-process
	# command hash cache (a /mnt shim executed earlier in this same run);
	# re-scan PATH. Run AFTER capturing _rc — hash -r must not mask the
	# install status.
	hash -r
	return "$_rc"
}

# Split one comma-separated strategy step off <rest> (e.g. "pkg,pip:x"):
# sets _STRATEGY_KIND / _STRATEGY_ARGS / _STRATEGY_REST (what remains after
# the step) and returns 1 when the list is exhausted. Shared by
# install_strategy (execution) and optional_hint (hint derivation).
_strategy_split() {
	[ -n "$1" ] || return 1
	local step="${1%%,*}"
	_STRATEGY_KIND="${step%%:*}"
	_STRATEGY_ARGS=""
	[ "$step" != "$_STRATEGY_KIND" ] && _STRATEGY_ARGS="${step#*:}"
	if [ "$1" = "$step" ]; then
		_STRATEGY_REST=""
	else
		_STRATEGY_REST="${1#*,}"
	fi
}

# Install everything a spec's strategy asks for, step by step, stopping as
# soon as the dependency actually probes positive.
install_strategy() {
	local spec="$1" strategy rest
	parse_spec "$spec"
	strategy="$SPEC_INSTALL"
	[ -n "$strategy" ] || strategy="pkg"
	[ "$strategy" = "none" ] && return 1
	rest="$strategy"
	while _strategy_split "$rest"; do
		rest="$_STRATEGY_REST"
		install_strategy_step "$_STRATEGY_KIND" "$_STRATEGY_ARGS" || true
		# The step may have just CREATED a bin dir (go/cargo install into
		# GOPATH[0]/bin, CARGO_HOME/bin, npm prefix/bin) — re-seed so the
		# probe below can actually resolve the freshly installed binary.
		if probe_spec "$spec"; then
			return 0
		fi
	done
	return 1
}

# ──────────────────────── install strategies ────────────────────────
# Runs one install step: <kind> picks the installer (pkg | npm | go | cargo
# | pip | brew | rustup | rustup-component | python-unversioned | none) and
# <args> is its package argument. Returns non-zero when the step failed.
# The integration point over every package manager's installer in this
# file — callers hand in a step, not a manager choice.
# KEEP IN SYNC with lib/output.sh _strategy_hint: the two case tables walk
# the SAME set of kinds — one executes a step, that one renders the human-
# readable command. A new kind needs a row in BOTH.
install_strategy_step() {
	local kind="$1" args="$2"
	case "$kind" in
	pkg)
		if [ -n "$args" ]; then
			# args are binaries, not package names: the distro package is
			# whatever pkg_name maps them to (cc → gcc, then clang).
			local -a names=() b
			for b in $args; do
				names+=("$(pkg_name "$b")")
			done
			install_pkg "${names[@]}"
		else
			install_pkg "$(pkg_name "$SPEC_ID")"
		fi
		;;
	npm)
		ensure_node_and_npm || return 1
		npm_install_g $args
		;;
	go)
		go_install $args
		;;
	cargo)
		ensure_rust || return 1
		retry -t "$RETRY_T_NET" -s "cargo install $args" cargo install $args
		;;
	pip)
		# ensure_pip first: the fallback dies with command-not-found when
		# pip3 is missing (Leap 16). stderr stays visible — a silently
		# swallowed pip error is what made the Leap 16 pylsp failure
		# undiagnosable.
		ensure_pip || return 1
		# USER-SPACE install (~/.local/lib/python3.X) first: pip installs
		# here are editor-grade user tools, and a sudo prompt inside this
		# retried command would die of SIGTTIN (sudo_cmd fails the attempt).
		# User site stays on this interpreter's sys.path (distro pylsp loads
		# the plugin), is user-owned/removable, and matches the npm/cargo/go
		# convention; console scripts land in ~/.local/bin (bin_dirs seeds
		# it at the front of PATH). The sudo lane is the fallback.
		#
		# PEP 668: Fedora 38+ / Debian 12+ / Ubuntu 23.04+ / Tumbleweed mark
		# the system python EXTERNALLY-MANAGED — pip refuses ALL installs
		# into it, --user included. Old pips reject the flag itself, so add
		# it only when this pip knows it AND the marker is present. venv/
		# pipx are NOT options: pylsp loads plugins via entry points from
		# ITS OWN interpreter, so isolation hides them; pipx-ing the whole
		# pylsp stack would overturn the distro-package-first policy for
		# one plugin gap.
		local user_flags="--user" sys_flags=""
		if pip3 install --help 2>/dev/null | grep -q -- --break-system-packages &&
			[ -f "$(python3 -c 'import sysconfig; print(sysconfig.get_path("stdlib"))' 2>/dev/null)/EXTERNALLY-MANAGED" ]; then
			user_flags="$user_flags --break-system-packages"
			sys_flags="--break-system-packages"
		fi
		retry -t "$RETRY_T_NET" -s "pip3 install $args" pip3 install $user_flags $args ||
			retry -t "$RETRY_T_NET" -s "pip3 install $args" sudo_cmd pip3 install $sys_flags $args
		;;
	brew)
		have_native_cmd brew || return 1
		# Heavy-formula timeout floors (zig / zls / marksman) live inside
		# brew_install_retry — uniform across every brew lane.
		brew_install_retry "$RETRY_T_NET" "brew install $args" $args
		;;
	zig-zls-pair)
		# Version-locked zig+zls pair (see install_zig_zls_pair in brew.sh)
		# — heals the match:zig probe failure caused by brew's zls formula
		# lagging its own zig formula.
		install_zig_zls_pair
		;;
	rustup)
		ensure_rust
		;;
	rustup-component)
		ensure_rust || return 1
		retry -t "$RETRY_T_NET" -s "rustup component add $args" rustup component add $args
		;;
	python-unversioned)
		install_python_for_gtags
		;;
	none)
		return 1
		;;
	*)
		install_pkg "$kind${args:+:$args}"
		;;
	esac
}

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
