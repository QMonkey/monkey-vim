# monkey-scripts/lib/brew.sh — Homebrew, implemented as the "brew" LANE of
# the install chain (lib/pkg.sh): the manager this host calls its own on
# macOS, the coverage lane for names a distro index lacks on Linux, and the
# first lane only where a name asks for it, in its spec strategy
# (`brew,pkg:fzf`). Sourced by lib/bootstrap.sh (both entry points — the chain
# needs the runtime side under checkhealth --install too).
#
# NOTE: brew_ensure fetches the installer through fetch_url_or_clone
# (lib/clone.sh) — clone.sh therefore also lives in the bootstrap common set.

# ──────────────────────────── Homebrew ────────────────────────────
# Heavy brew formulae (name patterns) — the ceiling source for a BATCH that
# arrives through a lane: any batch carrying one of these runs at no less than
# RETRY_T_HUGE (enforced in brew_install_retry). The table lists names by what
# they POUR, not by what they are: zig pulls an LLVM tier, marksman pulls a
# .NET runtime, and zls is here because installing it pours zig. Check a new
# entry with `brew info --json=v2 <f>` and its dependencies field.
#
# Lane ORDER is never an input here — a name that wants Homebrew first says so
# in its spec strategy, and this table answers only how long the bottle may
# take. The one caller that does not rely on the table is install_zig_zls_pair:
# installing zig and zls IS an LLVM-scale pour by definition, so it asks for the
# huge tier directly. A ceiling that matters that much must not hang on a table
# entry staying present — measured: with the table emptied, a lane batch of zls
# drops to the network tier while the pair install keeps the huge one.
BREW_HEAVY_NAMES="zig zls marksman"

# No pin array survives here or anywhere: lane order is a spec strategy
# (lib/pkg.sh), and bottle weight is BREW_HEAVY_NAMES above — except inside
# install_zig_zls_pair, which states its own tier.

# ────────────────── lane verbs ──────────────────
# Homebrew's own binary→formula mapping. pkg_name (lib/distro.sh) selects
# this table on macOS and for any brew-lane request, so the chain can name a
# formula without the caller knowing which OS it is on. Only names that
# DIFFER from the command are listed; a formula named after its binary (git,
# tmux, fzf, wireplumber) needs no row and falls through to `*) echo "$1"`.
brew_name() {
	case "$1" in
	python3) echo "python" ;;
	rg) echo "ripgrep" ;;
	ctags) echo "universal-ctags" ;;
	pygmentize) echo "pygments" ;;
	clangd | clang-tidy) echo "llvm" ;; # one formula ships both binaries
	g++) echo "gcc" ;;
	pylsp) echo "python-lsp-server" ;;
	# Rendering is gomplate (see scripts/lib/template.sh render). No Linux
	# DISTRO repository packages it — zypper has no provider, and arch's AUR
	# does (gomplate-bin) — while the formula is current on every macOS. The
	# provisioning order lives in the spec (pkg,brew:gomplate): the distro
	# lane runs first because it is the one that can reach a repository that
	# carries it, and the brew lane is the declared fallback for every index
	# that lacks it, self-healing through brew_ensure where brew is
	# absent. envsubst/gettext is no longer a dependency. The formula name
	# equals the binary, so there is no row here to write.
	*) echo "$1" ;;
	esac
}

# brew_probe <formula> — `brew info` fails on an unknown formula.
# Without brew: don't filter (a lane that cannot speak must never drop a
# name). Single-shot by policy, like every other probe.
brew_probe() {
	have_native_cmd brew || return 0
	brew info "$1" >/dev/null 2>&1
}

# brew_installed <formula> — did the Cellar actually get this keg?
# The chain asks it after a non-zero transaction, because a timed-out brew can
# have finished the install (timeout kills the wrapper after the binaries
# land) and re-installing that name through another lane would pour a SECOND
# copy. `brew list --versions` is a local metadata read: no network, no
# auto-update.
brew_installed() {
	have_native_cmd brew || return 1
	brew list --versions "$1" >/dev/null 2>&1
}

# The version the formula offers ("" when brew has no such formula): the brew
# twin of distro_version (lib/distro.sh). Parsed from the same header line
# install_zig_zls_pair reads — `brew info --json` has no documented output
# layout (it pretty-prints here, compact upstream), and a version-pinning
# decision must not ride an undocumented format.
brew_version() {
	have_native_cmd brew || return 0
	local ver
	ver=$(brew info "$1" 2>/dev/null | head -1 | grep -oE 'stable [0-9]+\.[0-9]+' | grep -oE '[0-9]+\.[0-9]+$')
	printf '%s' "${ver:-}"
	return 0
}

# brew_refresh — a documented no-op. Homebrew updates its own metadata on
# demand (and `brew update` is a clone operation with a lock of its own that
# nothing here asked for); the chain still calls this verb so every lane
# answers the same question, and the guard keeps it free.
BREW_DB_REFRESHED=0
brew_refresh() {
	[ "$BREW_DB_REFRESHED" -eq 1 ] && return 0
	BREW_DB_REFRESHED=1
	return 0
}

# The brew lane's batch install: filter, then ONE brew transaction with the
# standard retry ladder. Silent by contract — the chain reports the names no
# lane carried, once, after the whole walk.
#
# The names arrive in whatever namespace the caller mapped them to (the
# distro name on Linux, brew's own on macOS). That is not sloppiness:
# Homebrew keeps aliases for the cross-ecosystem names — measured on brew
# 7.0.12, nodejs→node, golang→go, python-lsp-server and universal-ctags all
# resolve — so a distro name that reaches this lane still lands, and the
# probe drops the handful that do not (python3-pip, base-devel) instead of
# failing the batch.
brew_install() {
	have_native_cmd brew || return 1
	filter_pkgs brew_probe "$@"
	((${#PKG_VALID[@]} > 0)) || return 1
	local rc=0
	brew_install_retry "$RETRY_T_NET" "brew install ${PKG_VALID[*]}" ${PKG_VALID[@]+"${PKG_VALID[@]}"} || rc=$?
	# This verb never shadows the distro copy. Reaching the brew lane through a
	# chain does not mean the caller prefers bottles — it is usually the
	# opposite, an index gap filled on the way past — and shadowing then would
	# silently reverse the order the chain declares. Whoever knows the order
	# decides instead: chain_walk links when brew is the HEAD of the chain it is
	# walking (lib/pkg.sh), a `brew` strategy step links its own names, and
	# brew_link_bins is called directly where the step exists to replace the
	# system copy (install_zig_zls_pair, the node floor).
	return "$rc"
}

# Symlink a bottle-installed tool into ~/.local/bin, which export_path seeds at
# the FRONT of PATH — so `command -v` resolves to the Homebrew build. Skips any
# name brew does not actually provide, and is idempotent: a path that is not a
# symlink (a user's own script) is never touched.
#
# Being called IS the declaration that bottles win here. That is true of the
# head of a chain that starts with brew, of a `brew` strategy step, and of the
# steps whose whole job is replacing the system copy (install_zig_zls_pair, the
# node floor) — and false of a brew lane reached further down a chain.
#
# The mechanism is Linux-only, and it is decided HERE rather than at the four
# call sites: on macOS the prefix itself is prepended ahead of /usr/bin
# (_brew_path_snippet, lib/env.sh), which shadows EVERY keg — dependencies and
# `brew` included — while these links only ever cover the names asked for. A
# stale link left behind by a later `brew uninstall`/upgrade would then sit in
# the dir that outranks the prefix, so the narrower mechanism would be the one
# able to break resolution. On Linux the bottle tier stays behind system paths
# on purpose, so ~/.local/bin remains the only way a bottle can outrank the
# distro copy.
brew_link_bins() {
	if [ "${OS:-unknown}" = macos ]; then
		return 0
	fi
	local p prefix
	prefix="$(brew --prefix 2>/dev/null)" || return 0
	[ -d "$prefix/bin" ] || return 0
	mkdir -p "$HOME/.local/bin" || return 0
	for p in "$@"; do
		[ -x "$prefix/bin/$p" ] || continue
		if [ -e "$HOME/.local/bin/$p" ] && [ ! -L "$HOME/.local/bin/$p" ]; then
			warn "$HOME/.local/bin/$p exists and is not a symlink — not touching it."
			continue
		fi
		ln -sfn "$prefix/bin/$p" "$HOME/.local/bin/$p"
	done
}

# zig+zls must be version-locked: zls refuses to serve a zig whose
# major.minor differs, and brew's zls formula lags its zig formula (the
# naive `brew install zig zls` yields a broken pair). Install the pair at
# the ZLS CEILING: zig comes from the versioned formula matching brew's
# zls (zig@X.Y — keg-only, force-linked after plain `zig` is removed).
# Without a versioned formula, fall back to latest-latest and let the
# match:zig probe give the verdict.
# Every batch below carries zig or zls, which pour an LLVM/.NET tier, so all
# three calls ask for RETRY_T_HUGE explicitly rather than inheriting it from
# BREW_HEAVY_NAMES: this function exists precisely because the pair install is
# the expensive case, so a dropped table entry must not be able to cost a whole
# timeout-and-retry cycle. The ceiling is a max(), so declaring it here is free
# when the table would already have raised it.
install_zig_zls_pair() {
	have_native_cmd brew || return 1
	local zls_xy zpath zver
	zls_xy=$(brew info zls 2>/dev/null | head -1 | grep -oE 'stable [0-9]+\.[0-9]+' | grep -oE '[0-9]+\.[0-9]+$')
	[ -n "$zls_xy" ] || return 1
	info "installing the zig+zls pair at brew's zls version ($zls_xy)..."

	# Already at the zls ceiling → only zls is missing (no swap needed).
	# This is the common path (batch lane already installed plain zig), and
	# it can also run after a batch-lane failure whose pacman fallback
	# satisfied the probe while brew's zig (poured as a zls dependency)
	# never got linked — so shadow both here.
	zpath=$(native_bin_path zig 2>/dev/null) || zpath=""
	zver=""
	[ -n "$zpath" ] && zver=$(extract_version "$zpath")
	if [ -n "$zpath" ] && [ "$zver" = "$zls_xy" ]; then
		brew_install_retry "$RETRY_T_HUGE" "brew install zls" zls
		local brc=$?
		brew_link_bins zig zls
		hash -r
		return "$brc"
	fi

	if brew info "zig@$zls_xy" >/dev/null 2>&1; then
		# The pair install is idempotent on poured kegs, so one call covers
		# both the fresh and the already-poured (timed-out first attempt)
		# case. Not fatal on failure: the keg may already exist — the swap
		# below fixes it.
		brew_install_retry "$RETRY_T_HUGE" "brew install zls zig@$zls_xy" zls "zig@$zls_xy" || true
		# keg-only: zig@X.Y never lands in brew's bin — swap the `zig`
		# symlink from plain (newer) to the pinned keg. Guarded on the keg
		# existing: uninstalling plain zig with nothing to link would
		# leave NO brew zig at all. zls DEPENDS on plain zig, so unlink
		# first (always allowed), drop the keg with --ignore-dependencies,
		# then force-link the pinned keg. If the uninstall is still
		# refused the link still wins — unlink already removed plain
		# zig's symlinks. match:zig re-probes the pair on every run.
		if brew list --versions "zig@$zls_xy" >/dev/null 2>&1; then
			brew unlink zig >/dev/null 2>&1 || true
			brew uninstall --ignore-dependencies zig >/dev/null 2>&1 || true
			brew link --force --overwrite "zig@$zls_xy" >/dev/null 2>&1 || true
		fi
		# Shadow unconditionally (same policy as the batch lane's link):
		# ~/.local/bin sits at the FRONT of PATH, so a system zig the
		# swap above cannot touch loses to the brew keg; when zig is
		# already brew-managed the link points at the same binary.
		brew_link_bins zig zls
		hash -r
		# Verify what `zig` resolves to for the framework: the shadow
		# tier (~/.local/bin/zig) first, then raw PATH.
		zpath=""
		[ -e "$HOME/.local/bin/zig" ] && zpath="$HOME/.local/bin/zig"
		if [ -z "$zpath" ]; then
			zpath=$(native_bin_path zig 2>/dev/null) || zpath=""
		fi
		zver=""
		[ -n "$zpath" ] && zver=$(extract_version "$zpath")
		if [ "${zver:-}" != "$zls_xy" ]; then
			warn "zig resolves to ${zver:-unknown} (${zpath:-not found}), expected $zls_xy — zls will refuse it; match:zig keeps reporting the pair."
			return 1
		fi
		return 0
	fi
	# No versioned formula for the zls ceiling: latest-latest, honestly probed.
	brew_install_retry "$RETRY_T_HUGE" "brew install zig zls" zig zls
}

brew_cleanup_timed_out() {
	# Called bare (caller already knows the attempt failed — always cleans
	# up) or via retry's -H hook with the attempt's exit code as $1. An
	# explicit 0 (healthy attempt) means nothing to reap: pkilling by
	# brew-prefix cmdline would only risk a concurrent, legitimate brew.
	[ "${1:-}" = 0 ] && return 0
	local prefix cache i f
	prefix="$(brew --prefix 2>/dev/null)" || return 0
	cache="$(brew --cache 2>/dev/null)" || cache=""
	warn "killing orphaned brew process(es) left by the timed-out brew (they hold the cache flock)..."
	# Homebrew's locks are flocks — they release when the holder dies, so
	# killing the orphan IS the unlock. TWO cmdline surfaces must be swept:
	# the ruby worker carries the brew PREFIX, but the download children it
	# spawned (curl writing a .incomplete file) carry only the CACHE dir.
	pkill -f "$prefix" 2>/dev/null
	if [ -n "$cache" ] && [ "$cache" != "$prefix" ]; then
		pkill -f "$cache" 2>/dev/null
	fi
	for i in 1 2 3; do
		pgrep -f "$prefix" >/dev/null 2>&1 || break
		sleep 1
	done
	# pkill-miss survivors (detached curl child, exotic cmdline) keep their
	# flock and wedge every later brew with "already locked". Unlink those:
	# the flock rides the inode, so the orphan's writes go to an anonymous
	# inode and brew's next attempt creates a FRESH file. UNLOCKED
	# .incomplete files are left in place — brew resumes them (curl -C -).
	if [ -d "$cache" ]; then
		for f in "$cache"/*.incomplete; do
			[ -e "$f" ] || continue
			if ! flock -n "$f" true 2>/dev/null; then
				warn "removing locked $(basename "$f") — its holder survived cleanup; brew will re-download it."
				rm -f "$f"
			fi
		done
	fi
	return 0 # best-effort — never fail the caller over cleanup
}

# One brew install with the standard retry ladder; returns the exit code.
# Heavy-formula timeout FLOOR applied here (not per call site) so every
# brew lane gets it uniformly. HOMEBREW_NO_ASK makes brew fail fast instead
# of prompting: it is brew's --no-ask switch (the ask gate also skips itself
# without a TTY), and the retry child sits in a NON-foreground process group
# where ANY prompt freezes on SIGTTIN. The installer's silent flag is a
# different knob and a different call site — NONINTERACTIVE=1 belongs to
# Homebrew/install and is set there (brew_ensure), not on `brew install`.
# env(1) carries the flags — a bare VAR=x prefix would be parsed as the
# command name by retry's getopts.
brew_install_retry() {
	local t="$1" desc="$2"
	shift 2
	local f n
	# ONE ceiling, per-name, uniform across every brew lane (callers pass the
	# ordinary network tier and get raised here): BREW_HEAVY_NAMES, matched by
	# what the batch pours. The pin is deliberately NOT an input — a pinned
	# name that pours nothing heavy does not need the HUGE tier, and one that
	# does belongs in the table regardless of being pinned.
	for f in "$@"; do
		for n in $BREW_HEAVY_NAMES; do
			# ${f%%@*}: versioned formulae (zig@X.Y) count as their base name,
			# which is why the table lists plain names only.
			[ "${f%%@*}" = "$n" ] || continue
			# if-form, not `[ ] &&`: with t already at HUGE the AND-list
			# would return 1 and set -e would abort the caller.
			if [ "$t" -lt "$RETRY_T_HUGE" ]; then
				t="$RETRY_T_HUGE"
			fi
			break 2 # fixed ceiling — no later name can raise it further
		done
	done
	local brc=0
	# -H hook: runs in this shell after every attempt, before the backoff
	# sleep (a post-loop backstop could only clean up after ALL attempts
	# had already died on the lock).
	retry -t "$t" -H brew_cleanup_timed_out -s "$desc" env HOMEBREW_NO_ASK=1 brew install "$@" || brc=$?
	return "$brc"
}

# Does a brew at <prefix> actually run? A half-installed Homebrew
# (portable-ruby unpack failed) leaves bin/brew behind while every
# invocation dies — verify with --version.
brew_functional() {
	[ -x "$1/bin/brew" ] && "$1/bin/brew" --version >/dev/null 2>&1
}

# The portable-ruby unpack needs tar AND gzip (the bottle is a .tar.gz)
brew_ensure_unpack_tools() {
	local tool
	for tool in tar gzip; do
		have_native_cmd "$tool" && continue
		install_pkg "$tool" ||
			warn "$tool is missing — the Homebrew install will likely fail halfway."
	done
}

# brew_ensure — idempotent Homebrew/Linuxbrew bootstrap: reuse a brew on
# PATH, adopt one at a known prefix, else install it. The verb is ensure, not
# install: it serves macOS too (brew_prefixes answers /opt/homebrew there) and
# installs nothing when brew is already present. Callers
# probe `have_native_cmd brew` first so the redundant call — and its report
# line — only happens on a host that truly needs the bootstrap.
#
# rc = "brew is usable", nothing more, and NO caller may treat it as fatal:
# an installer run carries on without the bottle lane (the rc contract in
# lib/pkg.sh). This wrapper is what makes that true, and what stops the
# recursion described below.
_HOMEBREW_BOOTSTRAPPING=0
brew_ensure() {
	# brew_ensure_unpack_tools installs tar/gzip through install_pkg, whose
	# chain bootstraps brew again on a host that has no other index (macOS).
	# Without this guard the two calls recurse until the shell dies. The flag
	# is reset on the way out — a failed bootstrap must not strand it and
	# make every later call skip the repair.
	if [ "$_HOMEBREW_BOOTSTRAPPING" -eq 1 ]; then
		warn "already bootstrapping Homebrew — not re-entering."
		return 1
	fi
	_HOMEBREW_BOOTSTRAPPING=1
	local rc=0
	_ensure_homebrew_once || rc=1
	_HOMEBREW_BOOTSTRAPPING=0
	return "$rc"
}

_ensure_homebrew_once() {
	local brew_prefix="" cand
	if have_native_cmd brew; then
		brew_prefix="$(dirname "$(dirname "$(command -v brew)")")"
		ok "Homebrew already installed at $brew_prefix."
	else
		# brew may exist at a standard prefix without being on PATH — an
		# earlier monkey-* component installed it and this process did not
		# inherit the profile. Adopt it instead of re-downloading; the
		# candidates come from brew_prefixes (env.sh).
		for cand in $(brew_prefixes); do
			if [ -x "$cand/bin/brew" ]; then
				brew_prefix="$cand"
				ok "Homebrew found at $brew_prefix (not on PATH — adopting)."
				break
			fi
		done
	fi
	if [ -z "$brew_prefix" ]; then
		info "Installing Homebrew/Linuxbrew..."
		# Download fully before executing: `curl | bash` would run a
		# truncated script.
		local installer="/tmp/homebrew_install.$$.sh"
		info "Downloading the Homebrew installer..."
		brew_ensure_unpack_tools
		if fetch_url_or_clone "https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh" "https://github.com/Homebrew/install" "$installer" "Homebrew installer"; then
			:
		else
			warn "Homebrew installer download failed — continuing without Homebrew."
			return 1
		fi
		# stdin from /dev/null: on macOS the installer takes its GUI route to
		# the Xcode Command Line Tools only when `test -t 0` holds (after the
		# headless softwareupdate route), and then blocks on `getc` — a prompt
		# in a retry/timeout child freezes on SIGTTIN. With no TTY the popup
		# branch is unreachable and NONINTERACTIVE is self-imposed anyway.
		NONINTERACTIVE=1 /bin/bash "$installer" </dev/null ||
			warn "Homebrew installer failed — continuing without Homebrew."
		rm -f "$installer"

		for cand in $(brew_prefixes); do
			if [ -x "$cand/bin/brew" ]; then
				brew_prefix="$cand"
				break
			fi
		done
	fi

	if [ -n "$brew_prefix" ] && brew_functional "$brew_prefix"; then
		local placement="after system paths, before Windows shims"
		# Where the prefix goes on PATH is the host's call (see
		# _brew_path_snippet): macOS prepends it, because there brew IS the
		# package manager and /usr/bin only holds Apple's stubs. Linux/WSL
		# inserts it AFTER system paths but BEFORE the WSL-injected Windows
		# shims: prepending let brew's python@3.x shadow /usr/bin/python3,
		# plain-appending put `npm` on the Windows one.
		if [ "${OS:-unknown}" = macos ]; then
			placement="ahead of the system paths"
			# Reaching here mid-run puts the prefix ahead of the framework
			# user dirs for the REST of this shell (the idempotent prepend
			# lines never move an entry already on PATH); the profile block
			# lands in the pinned order instead (path_dirs_snippet renders
			# Homebrew first, the user dirs after).
		fi
		export_brew_path "$brew_prefix/bin" "$brew_prefix/sbin"
		ok "Homebrew/Linuxbrew ready at $brew_prefix ($placement)."
		# Persist the same insert — the whole block, not a brew-only one, so
		# the profile order cannot depend on which writer ran first. Direct
		# call, past install.sh's PERSIST_PATH gate (see persist_path).
		persist_path
		hash -r
		return 0
	fi
	# Two flavors of "no usable brew": never installed, or dead
	# (bin/brew present, vendor ruby missing) — name the difference.
	if [ -n "$brew_prefix" ]; then
		warn "brew exists at $brew_prefix but cannot run (incomplete install?) — continuing without Homebrew. Fix: reinstall Homebrew."
	else
		warn "brew not found — continuing without Homebrew."
	fi
	return 1
}
