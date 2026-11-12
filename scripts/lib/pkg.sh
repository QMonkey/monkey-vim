# monkey-scripts/lib/pkg.sh — the DISPATCH CORE of the installer domains:
# the lane contract (every package manager answers the same verbs), the
# install CHAIN (one evaluator for "which manager, in what order"),
# install_pkg (the batch entry point), and the install-strategy dispatcher.
#
# Sourced by scripts/install.sh and scripts/checkhealth.sh (via
# lib/bootstrap.sh).
#
# Sibling domains (sourced alongside, reached only through the lane contract):
#   lib/distro.sh     the distro package-manager family (apt / pacman /
#                     zypper / dnf) — the "pkg" lane — and the "aur" lane
#                     (arch's second repo set, driven by the paru helper)
#   lib/brew.sh       Homebrew — the "brew" lane, and brew_ensure
#   lib/toolchain.sh  the language-ecosystem installers (rustup / go / npm /
#                     pip) — NOT lanes: their step needs a spec-supplied
#                     coordinate, not a package name
#
# The core stays domain-free: it decides ORDER and reports VERDICTS, the
# domains own the "how". Everything below is safe to call from either entry
# point.
#
# ──────────────────────────── the lane contract ────────────────────────────
# A LANE is a package index that can be asked, per name, "do you carry it?".
# Three lanes exist — pkg (the distro manager), aur (arch's second repo set),
# brew — and each answers the same verbs, so nothing outside this file names a
# manager on its own:
#
#   pkg_name       <bin> [lane]       → the package name for a binary (pure).
#          The arity exception above: <lane> is optional and last.
#   pkg_installed <lane> <pkgname>   → 0 = this lane owns an install of it on this host
#   pkg_available <lane>             → 0 = the manager binary runs here
#   pkg_ensure    <lane>             → 0 = usable after self-bootstrapping
#   pkg_refresh   <lane>             → always 0; one guarded refresh per run
#   pkg_index_ok  <lane>             → 0 = its probe verdicts are trustworthy right now
#   pkg_install   <lane> <pkgnames..> → run the batch; fills PKG_VALID (names
#          accepted) and UNKNOWN_PKGS (names not carried) and returns the
#          TRANSACTION rc, which is not a per-name verdict
#          Probing has no dispatcher of its own, on purpose: the walk never
#          pre-probes (a pre-probe would pay zypper's privileged capability
#          dry-run twice per name), so the per-lane probe functions —
#          distro_probe / aur_probe / brew_probe — are reached
#          through filter_pkgs INSIDE each lane installer. Their contract,
#          which those three must keep: 0 = carried OR cannot tell, 1 =
#          definitely not carried; read-only, sudo-free, never refreshes the
#          metadata (distro_refresh owns that, once per run), NO internal
#          retry; a missing manager binary answers 0 — never drop a
#          name because a lane cannot speak. That is why probing is 0/1 and
#          not a tri-state: the tri-state lives in the chain's verdicts.
#   pkg_version   <lane> <pkgname>   → the version this lane's INDEX offers
#          (X.Y, "" when it carries no such name) — "what would I get", never
#          "what is on disk", which is pkg_installed's question
#          caller-facing: the walk never calls it. Ask this (not a backend's
#          distro_version / brew_version) so the lane stays decided in
#          one place.
#
# Ecosystem installers (rustup / go / npm / pip) are NOT lanes: their target
# is a coordinate a package name cannot imply (a module path, a PyPI
# distribution, an npm package), so they appear only as explicit spec steps in
# install_strategy_step. A generic "toolchain lane" would require inventing a
# name→coordinate resolver we do not have.
#
# ──────────────────────── rc never aborts the run ────────────────────────
# Consumer installers run under `set -euo pipefail`, so a bare non-zero call
# would kill the install. Contract: pkg_ensure / pkg_refresh /
# pkg_available / pkg_installed failures are consumed inside this file (in
# an if-condition or with `|| rc=$?`) and only ever change WHICH lanes run,
# never whether the run continues. Only install_pkg and install_strategy hand
# a status to a caller, and every call site in the framework and the 9
# consumer repos already puts them in an `if`, `|| :` or `|| warn` position.

# ──────────────────────────── shared batch classifier ────────────────────────────
# filter_pkgs <probe> <name>... — classify names through <probe>: the ones it
# accepts land in PKG_VALID, the rest in UNKNOWN_PKGS. warn_unknown_pkgs
# reports the dropped names. Lane installers call filter_pkgs and stay
# silent; WHO reports is the caller's decision — install_pkg reports once at
# the end of the chain (a lane that reports would call a name "skipped" while
# a later lane is about to install it), install_build_deps reports right after
# its own call.
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
	# reason every dispatch table here is a case statement).
	local -a reported=()
	for p in ${UNKNOWN_PKGS[@]+"${UNKNOWN_PKGS[@]}"}; do
		# The same unmapped name arrives once per batch (required AND
		# recommended both referenced wlogout) — report it once.
		case " ${reported[*]-} " in *" $p "*) continue ;; esac
		reported+=("$p")
		warn "$p not found in the package index — skipped (one bad name would fail the whole batch)"
	done
}

# ──────────────────────────── routing: OS → lane ────────────────────────────
# The ONE OS → package-manager mapping (apt | pacman | zypper | dnf | brew,
# "" when nothing applies). This is the ROUTER's question — "which manager
# does this host call its own?" — not a lane's, which is why it lives here and
# not in lib/distro.sh. Simple mappers (install hints, display name) dispatch
# through it; the install/probe paths keep their explicit per-OS cases.
pkg_manager() {
	case "$OS" in
	debian | ubuntu) printf '%s\n' "apt" ;;
	arch) printf '%s\n' "pacman" ;;
	opensuse) printf '%s\n' "zypper" ;;
	centos | fedora) printf '%s\n' "dnf" ;;
	macos) printf '%s\n' "brew" ;;
	*) printf '%s\n' "" ;;
	esac
}

# The default chain for this host, as an ordered lane list. The ordering is a
# coverage judgement, not a rank: Homebrew carries a broader set at current
# versions, so it takes the names the distro index lacks. AUR sits between
# them on arch because a tool can leave the official repos and still be in
# the AUR (wlogout left [extra] outright). macOS has no system index at all,
# so brew IS the whole chain there.
chain_default() {
	case "$(pkg_manager)" in
	brew) printf '%s\n' "brew" ;;
	pacman) printf '%s\n' "pkg aur brew" ;;
	"")
		# Unreachable since os_init gates $OS: an OS with no manager would
		# otherwise run the whole chain as "pkg", where distro_install
		# declines every name and the retry loop keeps asking.
		printf 'chain_default: no package lane for OS "%s" — supported: %s\n' "$OS" "$OS_SUPPORTED" >&2
		exit 1
		;;
	*) printf '%s\n' "pkg brew" ;;
	esac
}

# WHICH LANES, IN WHAT ORDER — one answer per host: chain_default above. A
# single name asks for a different order by declaring it in its own strategy
# string (`brew,pkg:fzf`), which install_strategy walks step by step. One lane
# is therefore asked at most once per name per run — enforced by the visit
# record STRATEGY_VISITED below, not by pre-computing a chain per name.

# ──────────────────────────── lane dispatch ────────────────────────────
# The aggregator's only window into a domain: a case table (not
# "${lane}_install" name mangling, and not an associative array — macOS ships
# bash 3.2). The domains keep their distro-specific behaviour (apt's three
# non-interactive env layers, pacman's db.lck, EPEL, zypper's privileged
# capability dry-run) that a flat id cannot express; this table only picks
# WHICH function to call.
# pkg_name <bin> [lane] — the package name for a binary. <lane> selects whose
# index is being named (pkg/aur → the distro table, brew → Homebrew's);
# omitted, it maps for the head of this host's chain — the distro manager on
# Linux, Homebrew on macOS. Keeping <lane> as an argument rather than an
# environment probe is what lets the chain ask brew for a name without the
# caller knowing which OS it is on.
#
# The one verb whose <lane> is NOT the first argument, on purpose: its answer
# is a name, not a lane verdict, and every existing caller asks "what is this
# binary called on this host" — forcing them to spell the default lane out
# would just move this two-step derivation into every call site.
pkg_name() {
	local bin="$1" lane="${2:-}"
	# bash cannot strip a pattern off a command substitution in one step, so
	# the chain lands in $lane before it is cut to its head. The `|| lane=""`
	# is not decoration: chain_default exits 1 for an OS with no lane, and
	# without this the failing substitution would abort pkg_name itself
	# instead of leaving the mapping to fall through to the distro table.
	[ -n "$lane" ] || {
		lane="$(chain_default)" || lane=""
		lane="${lane%% *}"
	}
	case "$lane" in
	brew) brew_name "$bin" ;;
	*) distro_name "$bin" ;;
	esac
}

pkg_installed() {
	local lane="$1"
	shift
	case "$lane" in
	pkg) distro_installed "$@" ;;
	aur) aur_installed "$@" ;;
	brew) brew_installed "$@" ;;
	*) return 1 ;;
	esac
}

pkg_available() {
	local m
	case "$1" in
	pkg)
		m="$(pkg_manager)"
		[ -n "$m" ] && [ "$m" != brew ] && have_native_cmd "$m"
		;;
	aur) aur_have_helper ;;
	brew) have_native_cmd brew ;;
	*) return 1 ;;
	esac
}

# rc = "usable", nothing more. Callers in this file consume it in an
# if-condition or with `|| true`; a failed bootstrap means the lane is skipped
# for these names, never that the install stops.
pkg_ensure() {
	case "$1" in
	aur) aur_ensure ;;
	brew) brew_ensure ;;
	*) return 0 ;; # the distro manager is either present or the OS is unsupported
	esac
}

pkg_refresh() {
	case "$1" in
	pkg | aur) distro_refresh ;;
	brew) brew_refresh ;;
	*) return 0 ;;
	esac
	return 0
}

# Can this lane's "I don't carry it" be believed right now? The distro lanes
# answer through the index canary; the others have no separate index to lose.
pkg_index_ok() {
	case "$1" in
	pkg) distro_index_ok ;;
	*) return 0 ;;
	esac
}

pkg_install() {
	local lane="$1"
	shift
	case "$lane" in
	aur) aur_install "$@" ;;
	brew) brew_install "$@" ;;
	*) distro_install "$@" ;;
	esac
}

# The repo's version offer for a name, normalized to X.Y ("" = not carried).
pkg_version() {
	local lane="$1"
	shift
	case "$lane" in
	brew) brew_version "$@" ;;
	*) distro_version "$@" ;;
	esac
}

# ──────────────────────────── the install chain ────────────────────────────
# What a walk decided, per name — the three states a true/false return cannot
# separate, and the difference between "install it from the bottle", "report
# it as unknown" and "let the retry loop try again":
#   CHAIN_DELIVERED  a lane accepted the name and its transaction landed
#   CHAIN_UNINDEXED  every lane that spoke does not carry it → report once
#   CHAIN_FAILED     a lane carries it but the transaction died → retry
#                    loop's problem; never coverage for a bottle
CHAIN_DELIVERED=()
CHAIN_UNINDEXED=()
CHAIN_FAILED=()

# PKG_RETRY_WORTHY — the walk outcome the EXIT codes have to tell apart from
# "missing": a name whose verdict never arrived. Two classes reach it (see
# chain_walk's tail): names a lane carried but could not deliver, and names no
# lane got to answer because its index was unreachable. Retrying can change
# both. CHAIN_UNINDEXED — a trusted index that answered "not here" — cannot, so
# that gap is reported once and left alone. Set in one place, never cleared:
# every --install pass is a fresh process, and the retry loop re-runs the whole
# chain from scratch, which resets the latch by construction.
PKG_RETRY_WORTHY=0

# Lanes already asked for a package name during the CURRENT strategy run. A
# strategy is a sequence of steps for one spec, and a lane step plus the default
# chain can name the same lane for the same package — without this record the
# second visit repeats a transaction that already answered. Keyed by package
# NAME, not by bin, because two steps can resolve one bin to two packages
# (`node` names nodejs on the distro lane and node on the brew lane). Scoped
# to one strategy run: install_pkg reached from the plain required-bins path
# clears it, so no verdict leaks from a previous spec.
STRATEGY_VISITED=""
IN_STRATEGY=0

_strategy_visited() { # <lane> <name> -> 0 = this lane already answered for it
	case " $STRATEGY_VISITED " in *" $1:$2 "*) return 0 ;; esac
	return 1
}

_strategy_mark() { # <lane> <names...>
	local _lane="$1"
	shift
	local _n
	for _n in "$@"; do
		STRATEGY_VISITED="$STRATEGY_VISITED $_lane:$_n"
	done
}

# chain_install <pkgname>... — walk this host's chain once for the whole
# batch: one transaction per lane, and a batch never splits because two names
# wanted different orders (an order is a spec strategy now, not a chain).
chain_install() {
	# Outside a strategy run there is no step sequence to dedupe against, and a
	# stale record would silently skip a lane that still owes this name an answer.
	[ "$IN_STRATEGY" -eq 1 ] || STRATEGY_VISITED=""
	local rc=0
	CHAIN_DELIVERED=()
	CHAIN_UNINDEXED=()
	CHAIN_FAILED=()
	# One chain for the host, one transaction per lane for the whole batch.
	# chain_default's lane list is already free of duplicates, so there is
	# nothing to dedupe per name here.
	chain_walk "$(chain_default)" "$@" || rc=1
	# Report the names no lane carries, once, after every lane had its say.
	if [ ${#CHAIN_UNINDEXED[@]} -gt 0 ]; then
		UNKNOWN_PKGS=(${CHAIN_UNINDEXED[@]+"${CHAIN_UNINDEXED[@]}"})
		warn_unknown_pkgs
	fi
	return "$rc"
}

# chain_walk <lane-list> <names...> — evaluate one chain, one batch per lane.
chain_walk() {
	local lanes="$1"
	# Which lane is first is the caller's preference, so it is also the only
	# thing that may let a bottle outrank the distro copy: an assembled
	# brew,pkg / brew,pkg,aur chain says so, macOS's single-lane brew chain
	# says so, and a brew lane reached after pkg (and after aur on arch) says
	# nothing of the kind.
	local head_lane="${lanes%% *}"
	shift
	local -a todo=("$@") inflight=("$@") carried=() dropped=() dead=()
	local lane n rc=0
	# A false index verdict is worse than no verdict: once ANY lane in this
	# walk reports its index unreachable, every NOT_INDEXED already collected
	# is suspect (the name may live behind that outage), so the rest of the
	# walk stays shut against bottles. Scoped to this walk — the retry loop
	# re-runs the chain from scratch, so nothing here degrades a later call.
	local trusted=1
	# Did THIS walk park a name as FAILED? Per walk, so one group's status
	# stays its own; PKG_RETRY_WORTHY is the process-wide view of the same
	# fact, which is what the exit codes read.
	local failed_here=0
	# Names owed a verdict when the walk was cut short by an outage. They are
	# NOT "unknown to the index" — reporting them as such would be a lie
	# about a name we never got a trustworthy answer for, and would bury the
	# outage warning that states the real cause.
	local -a unverified=()
	[ ${#todo[@]} -gt 0 ] || return 0
	for lane in $lanes; do
		# Candidates for this lane: the index misses still in flight, plus — only
		# into the distro manager, the one lane that exists to catch a bottle
		# whose download timed out and never landed — the names an earlier lane
		# carried and could not deliver. The question is asked of the lane being
		# ENTERED, never of the one that failed: brew/aur never inherit a failure,
		# a blind fallback once installed wl-clipboard, wireplumber and mako from
		# bottles on arch while pacman was down. A FAILED name is the retry
		# loop's business.
		todo=(${inflight[@]+"${inflight[@]}"})
		if [ ${#dead[@]} -gt 0 ] && [ "$lane" = pkg ]; then
			todo+=(${dead[@]+"${dead[@]}"})
			dead=()
		fi
		[ ${#todo[@]} -gt 0 ] || continue
		# Asked already in this strategy run? Repeat nothing — this lane already
		# answered for exactly these names. A no-op outside a strategy, where the
		# record is empty by construction.
		if [ -n "$STRATEGY_VISITED" ]; then
			local -a fresh=()
			for n in ${todo[@]+"${todo[@]}"}; do
				_strategy_visited "$lane" "$n" || fresh+=("$n")
			done
			todo=(${fresh[@]+"${fresh[@]}"})
			[ ${#todo[@]} -gt 0 ] || continue
		fi
		# Bootstrap a missing-but-bootstrappable lane (a name whose spec asked
		# for a bottle must not dead-end on a host that has no brew yet), then
		# skip the lane if it still cannot speak. Neither failure stops the run.
		# The filter above runs BEFORE this: a lane that already answered for
		# every name in flight is not entered, so no second bootstrap attempt.
		if ! pkg_available "$lane"; then
			pkg_ensure "$lane" || true
			pkg_available "$lane" || continue
		fi
		if [ "$lane" = brew ] && [ "$trusted" -eq 0 ]; then
			warn "package index unreachable — not falling back to bottles for ${todo[*]} (the retry loop heals later)."
			unverified=(${todo[@]+"${todo[@]}"})
			inflight=()
			todo=()
			break
		fi
		pkg_refresh "$lane"
		# The lane filters its own names (one unknown name aborts a whole
		# transaction), so PKG_VALID/UNKNOWN_PKGS after the call ARE its
		# verdicts. No pre-probe here — that would pay the privileged zypper
		# capability dry-run twice per name. Reset FIRST: a lane that returns
		# before filtering (an OS it does not serve, an empty batch) must not
		# be read as having spoken with the previous lane's arrays.
		PKG_VALID=()
		UNKNOWN_PKGS=()
		rc=0
		_strategy_mark "$lane" ${todo[@]+"${todo[@]}"}
		pkg_install "$lane" ${todo[@]+"${todo[@]}"} || rc=$?
		# A head lane gets the shadow. Not gated on rc: a timed-out brew can
		# still have finished the pour, and brew_link_bins ignores names brew
		# does not actually provide. On macOS it declines the job itself —
		# there the prefix is prepended, which shadows every keg (lib/env.sh).
		if [ "$lane" = brew ] && [ "$lane" = "$head_lane" ]; then
			brew_link_bins ${PKG_VALID[@]+"${PKG_VALID[@]}"}
		fi
		carried=(${PKG_VALID[@]+"${PKG_VALID[@]}"})
		dropped=(${UNKNOWN_PKGS[@]+"${UNKNOWN_PKGS[@]}"})
		pkg_index_ok "$lane" || trusted=0
		if [ ${#carried[@]} -eq 0 ] && [ ${#dropped[@]} -eq 0 ]; then
			continue # the lane took no stance: names stay in flight
		fi
		# The lane spoke. Index misses stay in flight for the lanes after it;
		# delivered names leave the chain.
		inflight=(${dropped[@]+"${dropped[@]}"})
		if [ "$rc" -eq 0 ]; then
			CHAIN_DELIVERED+=(${carried[@]+"${carried[@]}"})
		else
			# A failed transaction is not a failed install: a timed-out brew
			# can have finished it (the timeout kills the wrapper after the
			# binaries land) and re-installing that name through another lane
			# would put a SECOND copy on PATH. So pkg_installed, the per-name
			# query, decides — not the batch rc, and not a command-name probe
			# (package names are not binary names). What genuinely did not
			# land waits for a lane that admits failures.
			for n in ${carried[@]+"${carried[@]}"}; do
				if pkg_installed "$lane" "$n"; then
					CHAIN_DELIVERED+=("$n")
				else
					dead+=("$n")
				fi
			done
		fi
	done
	if [ ${#dead[@]} -gt 0 ]; then
		CHAIN_FAILED+=(${dead[@]+"${dead[@]}"})
		failed_here=1
	fi
	# The one write site for the latch (both transient classes land here: a
	# dead transaction, and the outage that left names unanswered).
	if [ "$failed_here" -ne 0 ] || [ ${#unverified[@]} -gt 0 ]; then
		PKG_RETRY_WORTHY=1
	fi
	# Anything still in flight was rejected by every lane that spoke.
	if [ ${#inflight[@]} -gt 0 ]; then
		CHAIN_UNINDEXED+=(${inflight[@]+"${inflight[@]}"})
		return 1
	fi
	[ ${#unverified[@]} -eq 0 ] || return 1
	[ "$failed_here" -eq 0 ] || return 1
	return 0
}

# Install a batch of package names through this host's install chain: the
# public batch entry point (consumer installers, the checkhealth missing
# passes, ensure_git, the clipboard domain). Thin by design — it gates on
# INSTALL_MODE, drops empty arguments, hands the names to chain_install and
# recycles bash's command hash. checkhealth installs only under --install.
install_pkg() {
	${INSTALL_MODE:-true} || return 1
	local -a names=()
	local n rc=0
	for n in "$@"; do
		[ -n "$n" ] || continue
		names+=("$n")
	done
	[ ${#names[@]} -gt 0 ] || return 1
	chain_install ${names[@]+"${names[@]}"} || rc=1
	# Freshly installed binaries may be shadowed by bash's per-process
	# command hash cache (a /mnt shim executed earlier in this same run);
	# re-scan PATH. Run AFTER capturing rc — hash -r must not mask the
	# install status.
	hash -r
	return "$rc"
}

# ──────────────────────────── install strategies ────────────────────────────
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
# soon as the dependency actually probes positive. The probe IS the chain's
# stop condition — that is why no verb here needs an "is it installed"
# answer of its own.
install_strategy() {
	local spec="$1" strategy rest rc=1
	parse_spec "$spec"
	strategy="$SPEC_INSTALL"
	[ -n "$strategy" ] || strategy="pkg"
	[ "$strategy" = "none" ] && return 1
	rest="$strategy"
	# The single place the visit record opens and closes. Every exit path runs
	# through the bottom of the loop, so a probe that passes mid-run cannot leave
	# the record (or IN_STRATEGY) set for the next spec.
	STRATEGY_VISITED=""
	IN_STRATEGY=1
	while _strategy_split "$rest"; do
		rest="$_STRATEGY_REST"
		install_strategy_step "$_STRATEGY_KIND" "$_STRATEGY_ARGS" || true
		# The step may have just CREATED a bin dir (go/cargo install into
		# GOPATH[0]/bin, CARGO_HOME/bin, npm prefix/bin) — re-seed so the
		# probe below can actually resolve the freshly installed binary.
		if probe_spec "$spec"; then
			rc=0
			break
		fi
	done
	IN_STRATEGY=0
	return "$rc"
}

# Runs one install step: <kind> picks the installer (pkg | aur | brew | npm
# | go | pip | rustup | rustup-component | python-unversioned | none) and
# <args> is its package argument. Returns non-zero when the step failed.
# A LANE kind (pkg / aur / brew) runs the chain for its names; an ECOSYSTEM
# kind runs its own installer with the coordinate the spec supplied. The kind
# tokens are DATA carried by specs in the consumer repos — never rename one
# without shipping the scripts/ subtree propagation first: an unknown kind
# falls through the *) arm below, is handed to install_pkg as a literal
# "kind:args" string, and gets dropped as an index miss — a near-silent
# no-op.
# KEEP IN SYNC with lib/output.sh _strategy_hint: the two case tables walk
# the SAME set of kinds — one executes a step, that one renders the human-
# readable command. A new kind needs a row in BOTH.
install_strategy_step() {
	local kind="$1" args="$2"
	case "$kind" in
	pkg)
		if [ -n "$args" ]; then
			# args are binaries, not package names: the package is whatever
			# pkg_name maps them to (`node` → nodejs, `rg` → ripgrep), and
			# names separated by spaces in one step batch into a single
			# transaction.
			local -a names=() b
			for b in $args; do
				names+=("$(pkg_name "$b")")
			done
			install_pkg "${names[@]}"
		else
			install_pkg "$(pkg_name "$SPEC_ID")"
		fi
		;;
	aur)
		# AUR-only tool (arch's second repo set, built by the helper). The
		# default arch chain reaches this lane on its own, so the step is for
		# the spec that wants ONLY the AUR build.
		local -a _step=()
		if [ -n "$args" ]; then
			_step=($args)
		else
			_step=("$(pkg_name "$SPEC_ID")")
		fi
		# Marked BEFORE the attempt: whether this step ends in a built package,
		# an unavailable helper or a failed build, the AUR lane has now answered
		# for these names in this run — the chain that follows must not ask it
		# again (and must not try to bootstrap a helper a second time).
		_strategy_mark aur ${_step[@]+"${_step[@]}"}
		pkg_install aur ${_step[@]+"${_step[@]}"}
		;;
	brew)
		# A declared bottle install. The chain routes pkg→brew for index
		# misses on its own, so this step only means something as a LATER
		# step: install_strategy stops the moment probe_spec passes, and a
		# "pkg,brew:x" spec therefore never reaches it when an earlier lane
		# had x (gomplate via arch's AUR pass). Kept because a spec declares
		# intent, not a guess about this host's index.
		# The ensure is guarded with `|| true` on purpose: its rc means
		# "brew is usable", and the line after it is the check that decides
		# what this step costs. Bare, it would abort a consumer installer
		# running under set -e (this call is the last command of the
		# then-clause, so its status becomes the statement's).
		local -a _step=()
		if [ -n "$args" ]; then
			_step=($args)
		else
			_step=("$(pkg_name "$SPEC_ID")")
		fi
		# Marked before the bootstrap attempt, exactly as in the aur arm: a host
		# with no Homebrew must not pay for a second bootstrap when the chain
		# reaches the brew lane later in the same run.
		_strategy_mark brew ${_step[@]+"${_step[@]}"}
		if ! have_native_cmd brew; then brew_ensure || true; fi
		have_native_cmd brew || return 1
		pkg_install brew ${_step[@]+"${_step[@]}"}
		# A `brew` step is a declared bottle-first install, so it owns the
		# shadowing the lane verb deliberately refuses to do.
		brew_link_bins ${PKG_VALID[@]+"${PKG_VALID[@]}"}
		;;
	zig-zls-pair)
		# Not a lane and not a coordinate either: the PAIR is the unit. zls
		# refuses to serve a zig whose major.minor differs, and brew's zls
		# formula lags its own zig formula, so a bottle install of zls alone
		# is exactly what breaks the match:zig probe. install_zig_zls_pair
		# (lib/brew.sh) installs both at the zls ceiling.
		install_zig_zls_pair
		;;
	npm)
		ensure_node_and_npm || return 1
		npm_install_g $args
		;;
	go)
		# Self-heal the toolchain like the rustup/npm/pip steps do — a spec
		# declaring go:x must not dead-end on a host with no go. The rc only
		# says "no toolchain"; install_strategy already runs the step with
		# `|| true`, so nothing here aborts the run.
		ensure_go || return 1
		go_install $args
		;;
	pip)
		install_pip_pkgs $args
		;;
	python-unversioned)
		install_python_for_gtags
		;;
	rustup)
		ensure_rust
		;;
	rustup-component)
		ensure_rust || return 1
		retry -t "$RETRY_T_NET" -s "rustup component add $args" rustup component add $args
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
