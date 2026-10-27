# monkey-scripts/lib/brew.sh — Homebrew: install_pkg's fallback manager and
# the BREW_FIRST lane, plus the installer itself. Sourced by
# lib/bootstrap.sh (both entry points — install_pkg needs the runtime side
# under checkhealth --install too).
#
# NOTE: install_linuxbrew fetches the installer through fetch_url_or_clone
# (lib/clone.sh) — clone.sh therefore also lives in the bootstrap common set.

# ──────────────────────────── Homebrew ────────────────────────────
# Heavy brew formulae (name patterns): zig pulls LLVM, marksman pulls
# .NET — installs that dwarf a normal bottle, so any lane installing
# them runs at no less than RETRY_T_HUGE (enforced in brew_install_retry).
BREW_HEAVY_NAMES="zig zig@* zls marksman"

# Names that should prefer Homebrew over the system package manager: system
# repos ship versions that lag far behind (fzf: 0.44 on Ubuntu noble vs
# current 0.7x). Projects append names here.
BREW_FIRST=()

# A BREW_FIRST tool installed via brew gets a symlink in ~/.local/bin,
# which export_path seeds at the FRONT of PATH — that keeps it beating the
# system version now that brew itself sits at the BACK. Idempotent; never
# replaces anything that is not a symlink (a user's own script stays).
_brew_first_link() {
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

probe_brew_name() {
	# `brew info` fails on an unknown formula; without brew, don't filter.
	have_native_cmd brew || return 0
	brew info "$1" >/dev/null 2>&1
}

# zig+zls must be version-locked: zls refuses to serve a zig whose
# major.minor differs, and brew's zls formula lags its zig formula (the
# naive `brew install zig zls` yields a broken pair). Install the pair at
# the ZLS CEILING: zig comes from the versioned formula matching brew's
# zls (zig@X.Y — keg-only, force-linked after plain `zig` is removed).
# Without a versioned formula, fall back to latest-latest and let the
# match:zig probe give the verdict.
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
		_brew_first_link zig zls
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
		_brew_first_link zig zls
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

cleanup_timed_out_brew() {
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
# brew lane gets it uniformly. NO_INTERACTIVE/NO_ASK make brew fail fast
# instead of prompting: the retry child sits in a NON-foreground process
# group where ANY prompt freezes on SIGTTIN. env(1) carries the flags —
# a bare VAR=x prefix would be parsed as the command name by retry's getopts.
brew_install_retry() {
	local t="$1" desc="$2"
	shift 2
	local f n
	for f in "$@"; do
		for n in $BREW_HEAVY_NAMES; do
			# ${f%%@*}: versioned formulae (zig@0.16) count as their base name.
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
	retry -t "$t" -H cleanup_timed_out_brew -s "$desc" env HOMEBREW_NO_INTERACTIVE=1 HOMEBREW_NO_ASK=1 brew install "$@" || brc=$?
	return "$brc"
}

# Does a brew at <prefix> actually run? A half-installed Homebrew
# (portable-ruby unpack failed) leaves bin/brew behind while every
# invocation dies — verify with --version.
brew_functional() {
	[ -x "$1/bin/brew" ] && "$1/bin/brew" --version >/dev/null 2>&1
}

# The portable-ruby unpack needs tar AND gzip (the bottle is a .tar.gz)
ensure_brew_unpack_tools() {
	local tool
	for tool in tar gzip; do
		have_native_cmd "$tool" && continue
		install_pkg "$tool" ||
			warn "$tool is missing — the Homebrew install will likely fail halfway."
	done
}

install_linuxbrew() {
	local brew_prefix="" cand
	if have_native_cmd brew; then
		brew_prefix="$(dirname "$(dirname "$(command -v brew)")")"
		ok "Homebrew already installed at $brew_prefix."
	else
		# brew may exist at a standard prefix without being on PATH — an
		# earlier monkey-* component installed it and this process did not
		# inherit the profile. Adopt it instead of re-downloading; the
		# candidates come from BREW_PREFIXES (env.sh).
		for cand in $BREW_PREFIXES; do
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
		ensure_brew_unpack_tools
		if fetch_url_or_clone "https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh" "https://github.com/Homebrew/install" "$installer" "Homebrew installer"; then
			:
		else
			warn "Homebrew installer download failed — continuing without Homebrew."
			return 0
		fi
		NONINTERACTIVE=1 /bin/bash "$installer" ||
			warn "Homebrew installer failed — continuing without Homebrew."
		rm -f "$installer"

		for cand in $BREW_PREFIXES; do
			if [ -x "$cand/bin/brew" ]; then
				brew_prefix="$cand"
				break
			fi
		done
	fi

	if [ -n "$brew_prefix" ] && brew_functional "$brew_prefix"; then
		# Brew goes AFTER system paths but BEFORE the WSL-injected Windows
		# shims (the opposite of `brew shellenv` on both ends): prepending
		# let brew's python@3.x shadow /usr/bin/python3, plain-appending
		# put `npm` on the Windows one. system > brew > Windows.
		export_path_pre_win "$brew_prefix/bin" "$brew_prefix/sbin"
		ok "Homebrew/Linuxbrew ready at $brew_prefix (before Windows shims, after system paths)."
		# Persist the same insert for future shells. Idempotent.
		persist_brew_path "$brew_prefix"
	else
		# Two flavors of "no usable brew": never installed, or dead
		# (bin/brew present, vendor ruby missing) — name the difference.
		if [ -n "$brew_prefix" ]; then
			warn "brew exists at $brew_prefix but cannot run (incomplete install?) — continuing without Homebrew. Fix: reinstall Homebrew."
		else
			warn "brew not found — continuing without Homebrew."
		fi
	fi
}
