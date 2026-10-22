# monkey-scripts/lib/brew.sh — Homebrew: install_pkg's fallback manager and
# the BREW_FIRST lane, plus the installer itself. Sourced by
# lib/bootstrap.sh (both entry points — install_pkg needs the runtime side
# under checkhealth --install too).
#
# NOTE: install_linuxbrew fetches the installer through fetch_url_or_clone
# (lib/clone.sh) — clone.sh therefore also lives in the bootstrap common set.

# ──────────────────────────── Homebrew ────────────────────────────
# Heavy brew formulae (name patterns): installs that dwarf a normal
# bottle — zig pulls LLVM and builds from source where brew ships no
# bottle for the distro (observed on Tumbleweed); marksman pulls the .NET
# runtime. Every brew lane installing them runs at no less than
# RETRY_T_HUGE (enforced in brew_install_retry, the one point all lanes
# pass through). The BREW_FIRST batch lane keeps a blanket RETRY_T_HUGE
# on top: a batch can drag heavy formulae in as DEPENDENCIES of innocent
# names, which a name table cannot see.
BREW_HEAVY_NAMES="zig zig@* zls marksman"

# Names that should prefer Homebrew over the system package manager: system
# repos ship versions that lag far behind (fzf: 0.44 on Ubuntu noble vs
# current 0.7x). Projects append names here.
BREW_FIRST=()

# The brew-first whitelist: a BREW_FIRST tool installed via brew gets a
# symlink in ~/.local/bin, which export_path seeds at the FRONT of PATH.
# This is what keeps those tools beating the system versions now that brew
# itself sits at the BACK. Idempotent; never replaces anything that is not a
# symlink (a user's own script in ~/.local/bin stays untouched).
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
	# `brew info` fails on an unknown formula. Without a brew binary there is
	# nothing to probe against — don't filter.
	have_native_cmd brew || return 0
	brew info "$1" >/dev/null 2>&1
}

# The brew twin of the pacman orphan: a killed brew WRAPPER leaves its ruby
# worker alive holding the cache flock — every later brew then refuses with
# "already locked". Homebrew's locks are flocks (release when the holder
# dies), so killing the orphan IS the unlock. Scoped to cmdlines mentioning
# the brew prefix (a bare `pkill brew` misses the ruby worker); only fires
# after OUR OWN failed attempt.
# zig+zls must be version-locked: zls refuses to serve a zig whose
# major.minor differs, and brew's zls formula lags its zig formula (the
# naive `brew install zig zls` yields zig 0.17 + zls 0.16 — a broken pair).
# Install the pair at the ZLS CEILING: whatever zls version brew carries,
# zig comes from the matching versioned formula (zig@X.Y — keg-only, so it
# is force-linked after the newer plain `zig` is removed). Without a
# versioned zig@X.Y formula the step falls back to latest-latest and leaves
# the verdict to the match:zig probe (install_strategy re-probes).
install_zig_zls_pair() {
	have_native_cmd brew || return 1
	local zls_xy zpath zver resolved brew_prefix managed
	zls_xy=$(brew info zls 2>/dev/null | head -1 | grep -oE 'stable [0-9]+\.[0-9]+' | grep -oE '[0-9]+\.[0-9]+$')
	[ -n "$zls_xy" ] || return 1
	info "installing the zig+zls pair at brew's zls version ($zls_xy)..."

	# What does `zig` resolve to RIGHT NOW? Three states matter:
	#   - already at the zls ceiling → only zls is missing (no swap needed);
	#   - brew-managed and stale → the swap below fixes it;
	#   - NOT brew-managed (a real file: manual install, Windows shim...) →
	#     NO relink can change what `zig` resolves to, so the multi-GB
	#     zig@X.Y install would be pure waste — fail fast with a precise
	#     message (observed: ~/.local/bin/zig as a plain binary).
	brew_prefix=$(brew --prefix 2>/dev/null) || brew_prefix=""
	zpath=$(native_bin_path zig 2>/dev/null) || zpath=""
	zver=""
	[ -n "$zpath" ] && zver=$(extract_version "$zpath")
	if [ -n "$zpath" ] && [ "$zver" = "$zls_xy" ]; then
		brew_install_retry "$RETRY_T_HUGE" "brew install zls" zls
		return "$?"
	fi
	if [ -n "$zpath" ] && [ -n "$brew_prefix" ]; then
		resolved=$(readlink -f "$zpath" 2>/dev/null || printf '%s' "$zpath")
		managed=0
		case "$zpath" in "$brew_prefix"/*) managed=1 ;; esac
		case "$resolved" in "$brew_prefix"/*) managed=1 ;; esac
		if [ "$managed" -ne 1 ]; then
			warn "zig resolves to $zver ($zpath) — not managed by Homebrew, expected $zls_xy. The pair install cannot swap it: remove or shadow $zpath (or install zig $zls_xy there), then re-run."
			return 1
		fi
	fi

	if brew info "zig@$zls_xy" >/dev/null 2>&1; then
		# Not fatal: the keg may already exist from an earlier attempt that
		# timed out AFTER pouring — the swap below is the whole point.
		brew_install_retry "$RETRY_T_HUGE" "brew install zls zig@$zls_xy" zls "zig@$zls_xy" || true
		# keg-only: zig@X.Y never lands in brew's bin — swap the `zig`
		# symlink from plain (newer) to the pinned keg, guarded on the keg
		# existing: uninstalling plain zig with nothing to link would leave
		# NO brew zig at all. match:zig re-probes the pair on every run.
		if brew list --versions "zig@$zls_xy" >/dev/null 2>&1; then
			# zls DEPENDS on plain zig, so a bare `brew uninstall zig` is
			# refused ("required by zls"). unlink first (always allowed),
			# then drop the keg with --ignore-dependencies, then force-link
			# the pinned keg. If the uninstall is still refused the link
			# still wins — unlink already removed plain zig's symlinks.
			brew unlink zig >/dev/null 2>&1 || true
			brew uninstall --ignore-dependencies zig >/dev/null 2>&1 || true
			brew link --force --overwrite "zig@$zls_xy" >/dev/null 2>&1 || true
		fi
		hash -r
		# The symlink swap is the whole point of the pair — verify what
		# `zig` actually resolves to on PATH (not just what brew linked).
		zpath=$(native_bin_path zig 2>/dev/null) || zpath=""
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
	local prefix cache i
	prefix="$(brew --prefix 2>/dev/null)" || return 0
	cache="$(brew --cache 2>/dev/null)" || cache=""
	warn "killing orphaned brew process(es) left by the timed-out brew (they hold the cache flock)..."
	# TWO cmdline surfaces must be swept: the ruby worker carries the brew
	# PREFIX in its cmdline, but the download children it spawned (curl
	# writing a .incomplete file) do NOT — they carry the CACHE dir. An
	# orphaned downloader keeps the flock on the .incomplete bottle and
	# wedges every later attempt with "already locked ... Gave up after
	# waiting 180 seconds" (observed on openSUSE: the next component's
	# pair install died on the previous component's orphaned curl).
	pkill -f "$prefix" 2>/dev/null
	if [ -n "$cache" ] && [ "$cache" != "$prefix" ]; then
		pkill -f "$cache" 2>/dev/null
	fi
	# Give dying holders a moment to release their flocks before the
	# retry ladder re-enters brew (flocks release on process death).
	for i in 1 2 3; do
		pgrep -f "$prefix" >/dev/null 2>&1 || break
		sleep 1
	done
	return 0 # best-effort — never fail the caller over cleanup
}

# One brew install ATTEMPT: ANY failure — not just timeouts (rc 124) —
# triggers the orphan cleanup. Brew's stalled-download lock failures
# ("already locked") never surface as 124, yet the orphaned worker wedges
# every later attempt the same way (observed on Ubuntu/openSUSE).
_brew_install_attempt() {
	local rc=0
	# Both flags make brew fail fast instead of prompting: the retry child
	# sits in a NON-foreground process group, where ANY prompt is frozen by
	# SIGTTIN (^C unreachable — reaches only the foreground group).
	#   HOMEBREW_NO_INTERACTIVE — formula hooks reading stdin (Ubuntu:
	#     `brew install zig` hung at its [y/n], ^C dead).
	#   HOMEBREW_NO_ASK — brew ≥7's dependency prompt gates on the TTY
	#     only, so NO_INTERACTIVE does NOT suppress it (CentOS: `brew
	#     install wget2` froze). Maps to `brew install --no-ask`.
	# The Homebrew INSTALLER already runs with NONINTERACTIVE=1.
	HOMEBREW_NO_INTERACTIVE=1 HOMEBREW_NO_ASK=1 brew install "$@" || rc=$?
	[ "$rc" -eq 0 ] || cleanup_timed_out_brew
	return "$rc"
}

# One brew install with the standard retry ladder. Returns the install's
# exit code.
#
# Heavy-formula timeout FLOOR, applied here (not per call site) so every
# brew lane gets it uniformly: zig pulls LLVM and builds from source where
# brew ships no bottle for the distro (observed on Tumbleweed); marksman
# pulls the .NET runtime. Their installs dwarf a normal bottle — no lane
# may run them at a lower tier than RETRY_T_HUGE, whatever the caller
# passed. The BREW_FIRST batch lane additionally keeps a blanket
# RETRY_T_HUGE: a batch can drag heavy formulae in as DEPENDENCIES of
# innocent names, which a per-name floor cannot see.
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
	# The attempt runs in a child shell (`timeout bash -c`): retry's
	# whitelist exports $1 but not cleanup — export it here.
	export -f cleanup_timed_out_brew
	retry -t "$t" -s "$desc" _brew_install_attempt "$@" || brc=$?
	# Backstop: rc 124 = timeout killed the wrapper before the attempt
	# reached its own cleanup line.
	[ "$brc" -eq 124 ] && cleanup_timed_out_brew
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
		# inherit the profile. Adopt it instead of re-downloading. The
		# candidate prefixes come from BREW_PREFIXES (env.sh) — the single
		# source of truth the brew PATH tier derives from too.
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
		# The temporary NOPASSWD drop-in makes the timestamp irrelevant, so
		# the official installer runs unmodified. Download fully before
		# executing: `curl | bash` would run a truncated script.
		local installer="/tmp/homebrew_install.$$.sh"
		# `curl -fsSL -o` is silent: on a slow network the download would
		# look like a hang.
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
		# section (the opposite of `brew shellenv` on both ends): prepending
		# let brew's python@3.x shadow /usr/bin/python3, plain-appending put
		# brew behind the /mnt/* shims so `npm` resolved to the Windows one.
		# export_path_pre_win splits the difference: system > brew > Windows.
		export_path_pre_win "$brew_prefix/bin" "$brew_prefix/sbin"
		ok "Homebrew/Linuxbrew ready at $brew_prefix (before Windows shims, after system paths)."
		# Persist the same insert for future shells. Idempotent.
		persist_brew_path "$brew_prefix"
	else
		# Two flavors of "no usable brew": never installed, or dead (bin/brew
		# present, vendor ruby missing) — name the difference.
		if [ -n "$brew_prefix" ]; then
			warn "brew exists at $brew_prefix but cannot run (incomplete install?) — continuing without Homebrew. Fix: reinstall Homebrew."
		else
			warn "brew not found — continuing without Homebrew."
		fi
	fi
}
