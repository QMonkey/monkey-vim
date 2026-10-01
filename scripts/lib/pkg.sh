# monkey-scripts/lib/pkg.sh — package index refresh, installs, Homebrew.
#
# Sourced by scripts/install.sh and scripts/checkhealth.sh.
#
# pkg_name() is a single mapping table for the system manager AND the brew
# fallback (brew validates every name up front and aborts the WHOLE batch
# when one is unknown — a lone apt-style "golang-go" would prevent even the
# brew-available fzf from installing). Projects override it AFTER sourcing
# the entry point: only entries that differ from the binary name need a case
# arm, everything else falls through. A case function instead of
# `declare -A`: macOS still ships bash 3.2, which has no associative arrays.
# Base table: names that differ from the binary name for SOME package
# manager. Editor/LSP/tooling names shared by monkey-nvim and monkey-vim live
# here; a repo with a one-off mapping (monkey-sway's swaymsg, monkey-hyprland's
# notif, ...) overrides pkg_name() after sourcing and delegates the rest to
# this function.
# openSUSE Python module packages carry the interpreter's ABI flavor
# prefix (python314-black, python314-python-lsp-server — NOT python3-*),
# and the flavor follows the default python3 version, so derive it at
# runtime. Prints nothing if python3 is unavailable.
python_flavor() {
	python3 -c 'import sys;print("python%d%d"%sys.version_info[:2])' 2>/dev/null
}

default_pkg_name() {
	case "${OS:-unknown}:$1" in
	# Go / Node / shell utilities
	debian:go | ubuntu:go) echo "golang-go" ;;
	centos:go | fedora:go) echo "golang" ;;
	debian:node | ubuntu:node | arch:node | centos:node | fedora:node) echo "nodejs" ;;
	debian:which | ubuntu:which) echo "debianutils" ;;
	arch:python3 | macos:python3) echo "python" ;;
	# Tumbleweed's index has no package literally named "python3" — the
	# interpreter ships as python313 (provides /usr/bin/python3 via
	# update-alternatives). Without this mapping the name probes as missing
	# and the retry loop re-fails on every attempt (observed on openSUSE:
	# monkey-zsh checkhealth lost all 4 attempts this way). Leap 15 ships a
	# real python3; its probe finds it before this row matters.
	opensuse:python3) echo "python313" ;;
	# Same class: no package named "node" (nodejs22 and friends), and an
	# unmapped node falls through to the brew fallback — whose node formula
	# drags python@3.14 in, which is HOW brew's python came to shadow
	# /usr/bin/python3 on openSUSE. Version rolls with Tumbleweed: bump
	# when the default nodejs major moves.
	opensuse:node) echo "nodejs22" ;;
	# pip3 is a standalone package on every distro (openSUSE's python313-pip
	# is NOT pulled in by python3; Leap 16 proved this matters — see
	# ensure_pip below).
	debian:pip3 | ubuntu:pip3 | centos:pip3 | fedora:pip3) echo "python3-pip" ;;
	arch:pip3) echo "python-pip" ;;
	opensuse:pip3) echo "$(python_flavor)-pip" ;;
	# Editors / language servers / gtags tooling (monkey-nvim, monkey-vim)
	debian:rg | ubuntu:rg | arch:rg | macos:rg | opensuse:rg | centos:rg | fedora:rg) echo "ripgrep" ;;
	debian:ctags | ubuntu:ctags | macos:ctags | opensuse:ctags | centos:ctags) echo "universal-ctags" ;;
	arch:ctags | fedora:ctags) echo "ctags" ;; # Arch & Fedora ship universal-ctags as "ctags"
	debian:pygmentize | ubuntu:pygmentize) echo "python3-pygments" ;;
	arch:pygmentize) echo "python-pygments" ;;
	macos:pygmentize) echo "pygments" ;;
	opensuse:pygmentize) echo "$(python_flavor)-Pygments" ;;
	centos:pygmentize | fedora:pygmentize) echo "python3-pygments" ;;
	debian:pylsp | ubuntu:pylsp) echo "python3-pylsp" ;;
	arch:pylsp | macos:pylsp) echo "python-lsp-server" ;;
	opensuse:pylsp) echo "$(python_flavor)-python-lsp-server" ;;
	centos:pylsp | fedora:pylsp) echo "python3-lsp-server" ;;
	# Debian/Ubuntu split clangd & clang-tidy into their own (unversioned
	# metapackages — `clang` there ships only clang/clang++, so mapping them
	# to `clang` installs nothing the probes look for. Arch's `clang` DOES
	# ship both binaries; openSUSE's `clang` carries them too.
	arch:clangd | arch:clang-tidy | opensuse:clangd | opensuse:clang-tidy) echo "clang" ;;
	debian:clangd | ubuntu:clangd) echo "clangd" ;;
	debian:clang-tidy | ubuntu:clang-tidy) echo "clang-tidy" ;;
	macos:clangd | macos:clang-tidy) echo "llvm" ;;
	centos:clangd | centos:clang-tidy | fedora:clangd | fedora:clang-tidy) echo "clang-tools-extra" ;;
	arch:g++ | macos:g++) echo "gcc" ;;
	opensuse:g++ | centos:g++ | fedora:g++) echo "gcc-c++" ;;
	arch:black) echo "python-black" ;;
	opensuse:black) echo "$(python_flavor)-black" ;;
	centos:black | fedora:black) echo "python3-black" ;;
	*) echo "$1" ;;
	esac
}

pkg_name() {
	default_pkg_name "$1"
}

# Names that should prefer Homebrew over the system package manager: system
# repos ship versions that lag far behind (fzf: 0.44 on Ubuntu noble vs
# current 0.7x). Projects append names here.
BREW_FIRST=()

# Homebrew's bin dirs. Appended to PATH (see install_linuxbrew), never
# prepended — overridable for tests.
BREW_BIN_DIRS="/home/linuxbrew/.linuxbrew/bin /opt/homebrew/bin"

# The brew-first whitelist: a BREW_FIRST tool installed via brew gets a
# symlink in ~/.local/bin, which _preseed_path seeds at the FRONT of PATH.
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

# ────────────────── package index refresh ──────────────────
# Refresh the package index before installing: a stale or missing index is
# the usual cause of "Unable to locate package" on freshly provisioned
# machines (and universe-only packages like fzf/zoxide/eza are invisible
# until the first update). Retried once for transient network failures; a
# failed refresh is never fatal — the install step still runs (dnf refreshes
# expired metadata on demand anyway, brew auto-updates). Guarded to at most
# one refresh per run: checkhealth installs in two batches (required +
# optional) and the index does not go stale between them — call freely
# before every install.
PKG_DB_REFRESHED=0

# The pacman transaction lock survives its owner: a pacman killed
# mid-transaction (retry timeout, OOM, crash) leaves /var/lib/pacman/db.lck
# behind, and EVERY later transaction then fails with "unable to lock
# database: File exists" until the file is removed by hand — monkey-vim lost
# exactly this way. Remove the lock only when
# no pacman process is alive; a live holder (another pacman really is
# running) is left alone — stealing its lock would corrupt the database.
PACMAN_DB_LCK=${PACMAN_DB_LCK:-/var/lib/pacman/db.lck}
clear_stale_pacman_lock() {
	[ "$OS" = arch ] || return 0
	command -v pacman >/dev/null 2>&1 || return 0
	sudo_cmd test -f "$PACMAN_DB_LCK" || return 0
	if pgrep -x pacman >/dev/null 2>&1; then
		warn "a pacman process is running — leaving $PACMAN_DB_LCK alone."
		return 0
	fi
	warn "removing stale pacman lock $PACMAN_DB_LCK (left by a killed pacman)..."
	sudo_cmd rm -f -- "$PACMAN_DB_LCK"
}

# A timed-out pacman attempt can leave a live orphan holding db.lck (sudo
# re-parents the transaction, so the timeout's signal does not always reach
# it). Kill it and clear the now-stale lock so the next attempt — ours or
# another component's — is not blocked for its whole timeout.
cleanup_timed_out_pacman() {
	sudo_cmd pkill -x pacman 2>/dev/null
	sleep 1
	clear_stale_pacman_lock
	return 0 # best-effort — never fail the caller over cleanup
}

refresh_pkg() {
	[ "$PKG_DB_REFRESHED" -eq 1 ] && return 0
	PKG_DB_REFRESHED=1
	case "$OS" in
	debian | ubuntu) retry -t 1800 -s "apt-get update" sudo_cmd apt-get update ;;
	arch)
		clear_stale_pacman_lock
		local rc=0
		retry -t 1800 -s "pacman -Sy" sudo_cmd pacman -Sy || rc=$?
		[ "$rc" -eq 124 ] && cleanup_timed_out_pacman
		;;
	opensuse) retry -t 1800 -s "zypper refresh" sudo_cmd zypper --non-interactive refresh ;;
	centos | fedora) retry -t 1800 -s "dnf makecache" sudo_cmd dnf makecache -q ;;
	esac
	# A failed refresh is never fatal — the install step still runs (dnf
	# refreshes expired metadata on demand anyway, brew auto-updates).
	return 0
}

# Low-level path used inside install_pkg and as the brew-failure fallback —
# returns non-zero when the OS is unknown, every name fails its probe, or the
# manager fails.
install_sys_pkg() {
	refresh_pkg
	filter_pkgs probe_pkg_name "$@"
	warn_unknown_pkgs
	[ ${#PKG_VALID[@]} -gt 0 ] || return 1
	case "$OS" in
	debian | ubuntu) retry -t 1800 -s "apt-get install" sudo_cmd apt-get install -y ${PKG_VALID[@]+"${PKG_VALID[@]}"} ;;
	arch)
		clear_stale_pacman_lock
		local rc=0
		retry -t 1800 -s "pacman install" sudo_cmd pacman -S --noconfirm ${PKG_VALID[@]+"${PKG_VALID[@]}"} || rc=$?
		[ "$rc" -eq 124 ] && cleanup_timed_out_pacman
		return "$rc"
		;;
	opensuse) retry -t 1800 -s "zypper install" sudo_cmd zypper --non-interactive install -y ${PKG_VALID[@]+"${PKG_VALID[@]}"} ;;
	centos)
		# Some tools (universal-ctags, global, fzf, bat, pygments) come from EPEL.
		sudo_cmd dnf install -y epel-release || true
		local -a _args=(${PKG_VALID[@]+"${PKG_VALID[@]}"})
		[[ " ${_args[*]} " =~ " global " ]] && _args+=(global-ctags)
		retry -t 1800 -s "dnf install" sudo_cmd dnf install -y "${_args[@]}"
		;;
	fedora)
		# No EPEL on Fedora — the names below ship in the base repos.
		# gtags needs the global-ctags subpackage (ctags back-end config),
		# same as CentOS; without it gtags is unusable.
		local -a _args=(${PKG_VALID[@]+"${PKG_VALID[@]}"})
		[[ " ${_args[*]} " =~ " global " ]] && _args+=(global-ctags)
		retry -t 1800 -s "dnf install" sudo_cmd dnf install -y "${_args[@]}"
		;;
	macos) return 1 ;; # Homebrew owns macOS — install_pkg routes there
	*) return 1 ;;
	esac
}

# ────────────────── package-name probing ──────────────────
# Read-only existence checks against the package index, one name at a time.
# Dispatch keys on $OS; a name the probe cannot vouch for is dropped from
# its install batch (see install_pkg / install_sys_pkg). Purely virtual apt
# packages carry no "Package:" record, so the apt probe greps the output of
# `apt-cache show` instead of trusting its exit code.

probe_pkg_name() {
	case "$OS" in
	debian | ubuntu)
		command -v apt-cache >/dev/null 2>&1 || return 0
		# Command substitution, not `| grep -q`: grep -q exits at the first
		# match and a multi-record `apt-cache show` then dies of SIGPIPE —
		# rc 141 under pipefail, indistinguishable from "not found".
		local records
		records="$(apt-cache show "$1" 2>/dev/null | grep '^Package:')"
		[ -n "$records" ]
		;;
	arch)
		command -v pacman >/dev/null 2>&1 || return 0
		pacman -Si "$1" >/dev/null 2>&1
		;;
	opensuse)
		command -v zypper >/dev/null 2>&1 || return 0
		zypper --non-interactive info "$1" >/dev/null 2>&1
		;;
	centos | fedora)
		command -v dnf >/dev/null 2>&1 || return 0
		dnf info -q "$1" >/dev/null 2>&1
		;;
	*) return 0 ;; # Homebrew owns macOS; an unknown OS cannot be probed
	esac
}

probe_brew_name() {
	# `brew info` fails on an unknown formula. Without a brew binary there is
	# nothing to probe against — don't filter.
	have_native_cmd brew || return 0
	brew info "$1" >/dev/null 2>&1
}

# filter_pkgs <probe> <name>... — classify names through <probe>: the ones it
# accepts land in PKG_VALID, the rest in UNKNOWN_PKGS. warn_unknown_pkgs
# reports the dropped names; call it right after filter_pkgs.
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

warn_unknown_pkgs() {
	local p
	local -A seen=()
	for p in ${UNKNOWN_PKGS[@]+"${UNKNOWN_PKGS[@]}"}; do
		# The same unmapped name arrives once per batch (required AND
		# recommended both referenced wlogout) — report it once.
		[ -z "${seen[$p]:-}" ] || continue
		seen[$p]=1
		warn "$p not found in the package index — skipped (one bad name would fail the whole batch)"
	done
}

# System package install with Homebrew fallback. Gated on INSTALL_MODE
# (checkhealth.sh only installs under --install; install.sh always does);
# recycles bash's command hash so a freshly installed binary resolves.
#
# Both managers get a probe pass before their batch: an unknown name aborts
# the WHOLE transaction (apt: "Unable to locate package"; brew pre-validates
# every name and aborts too — a lone apt-style name would prevent even the
# good formulae from installing). probe_pkg_name / probe_brew_name drop such
# names up front with a warning, so the good names still install in a single
# transaction. The probes are read-only, sudo-free queries against the local
# index — milliseconds per name; a missing manager binary disables the probe
# (the name passes unfiltered and the real install attempt reports the error
# as before).
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
				local -a bpkg=()
				for b in "${rest[@]}"; do bpkg+=("$(pkg_name "$b" brew)"); done
				filter_pkgs probe_brew_name "${bpkg[@]}"
				warn_unknown_pkgs
				# All names filtered: the arithmetic test fails, the group
				# returns non-zero and _rc records it — same as an actual
				# failed brew call.
				((${#PKG_VALID[@]} > 0)) &&
					retry -t 1800 -s "brew install (fallback)" brew install ${PKG_VALID[@]+"${PKG_VALID[@]}"}
			else
				false
			fi
		} || _rc=1
	fi
	if ((${#brew_pkgs[@]} > 0)); then
		filter_pkgs probe_brew_name "${brew_pkgs[@]}"
		warn_unknown_pkgs
		if ((${#PKG_VALID[@]} > 0)); then
			retry -t 1800 -s "brew install" brew install ${PKG_VALID[@]+"${PKG_VALID[@]}"} || install_sys_pkg ${PKG_VALID[@]+"${PKG_VALID[@]}"} || _rc=1
			# Whitelist the brew-first tools into ~/.local/bin so they keep
			# beating the system versions now that brew sits at the BACK of
			# PATH (see install_linuxbrew).
			if [ "$_rc" -eq 0 ]; then
				_brew_first_link ${PKG_VALID[@]+"${PKG_VALID[@]}"}
			fi
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

get_install_hint() {
	case "$OS" in
	debian | ubuntu) echo "sudo apt-get install ${*}" ;;
	arch) echo "sudo pacman -S ${*}" ;;
	opensuse) echo "sudo zypper install ${*}" ;;
	centos | fedora) echo "sudo dnf install ${*}" ;;
	macos) echo "brew install ${*}" ;;
	linux-unknown) echo "install ${*} manually or 'brew install ${*}'" ;;
	*) echo "install ${*} manually" ;;
	esac
}

# ────────────────── shared install steps ──────────────────
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

# pip3 must exist before any `pip:` install strategy runs: it is a separate
# package on every distro, and the pip fallback dies with command-not-found
# when it is missing. Surfaced by openSUSE Leap 16.0: its repos do not
# package python-lsp-server at all (Tumbleweed does), so pylsp can only come
# from the pip fallback — which silently failed while pip3 was absent.
ensure_pip() {
	have_native_cmd pip3 && return 0
	info "Installing pip3 via the system package manager..."
	install_pkg "$(pkg_name pip3)" || return 1
	have_native_cmd pip3 || return 1
	# pip3 must actually RUN, not just exist: on a not-fully-updated system
	# the distro python can be newer than its runtime libraries, and pip
	# dies at import (it pulls in pyexpat → libexpat). Leap 16.0 shipped
	# python3.13 built against libexpat 2.7 while GA media had an older
	# one — updating libexpat1 fixes it.
	if ! pip3 --version >/dev/null; then
		warn "pip3 is installed but fails to run — runtime library mismatch on a not-fully-updated system?"
		if [ "${OS:-}" = opensuse ] && have_native_cmd zypper; then
			info "updating libexpat1 (the known Leap 16 victim)..."
			sudo_cmd zypper update -y libexpat1 >/dev/null 2>&1 || true
		fi
		if ! pip3 --version >/dev/null; then
			warn "pip3 still not runnable — update the system packages and re-run."
			return 1
		fi
	fi
	ok "pip3 installed."
}

# Install a binary from the system package manager if it is missing.
# Usage: ensure_system_bin <bin> <desc> — never fatal (the package may not be
# in the repos; checkhealth reports what is left afterwards).
ensure_system_bin() {
	local bin="$1" desc="${2:-$1}" ver
	if have_native_cmd "$bin"; then
		ver=$("$bin" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+' | head -1)
		ok "${desc} ${ver:+$ver }already installed."
		return 0
	fi
	info "Installing ${desc} via the system package manager..."
	if install_pkg "$(pkg_name "$bin")"; then
		ok "${desc} installed."
	else
		warn "${desc} install failed — install it manually: $(get_install_hint "$(pkg_name "$bin")")"
	fi
}

# Does a brew at <prefix> actually run? bin/brew existing is not enough: a
# half-installed Homebrew (portable-ruby unpack failed — e.g. tar missing on
# openSUSE Tumbleweed) leaves the binary behind while every invocation dies.
# Verifying with --version keeps the success line honest.
brew_functional() {
	[ -x "$1/bin/brew" ] && "$1/bin/brew" --version >/dev/null 2>&1
}

install_linuxbrew() {
	local brew_prefix="" cand
	if have_native_cmd brew; then
		brew_prefix="$(dirname "$(dirname "$(command -v brew)")")"
		ok "Homebrew already installed at $brew_prefix."
	else
		# brew may exist at a standard prefix without being on PATH — an
		# earlier monkey-* component installed it and this process did not
		# inherit the profile. Adopt it instead of re-downloading.
		for cand in /home/linuxbrew/.linuxbrew /opt/homebrew /usr/local; do
			if [ -x "$cand/bin/brew" ]; then
				brew_prefix="$cand"
				ok "Homebrew found at $brew_prefix (not on PATH — adopting)."
				break
			fi
		done
	fi
	if [ -z "$brew_prefix" ]; then
		info "Installing Homebrew/Linuxbrew..."
		# NOTE: the installer's exit trap runs `sudo -k` (and the `brew`
		# commands it spawns reset the timestamp too) — that used to require
		# sed-patching the installer, but the temporary NOPASSWD drop-in makes
		# the timestamp irrelevant, so the official installer runs unmodified.
		# If the drop-in failed to install, the next privileged command simply
		# re-authenticates once (sudo_cmd).
		# Download fully before executing: `curl | bash` would run a truncated
		# script if the connection drops mid-stream.
		local installer="/tmp/homebrew_install.$$.sh"
		# `curl -fsSL -o` is silent: on a slow network the download (and its
		# retries) would look like a hang without this line.
		info "Downloading the Homebrew installer..."
		# The portable-ruby unpack needs tar; a minimal install without it
		# (openSUSE Tumbleweed) makes the installer fail halfway through and
		# leaves a brew that cannot run. Install it up front when missing.
		have_native_cmd tar || install_pkg tar ||
			warn "tar is missing — the Homebrew install will likely fail halfway."
		if retry -s "Homebrew installer download" curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh -o "$installer"; then
			:
		else
			warn "Homebrew installer download failed — continuing without Homebrew."
			return 0
		fi
		NONINTERACTIVE=1 /bin/bash "$installer" ||
			warn "Homebrew installer failed — continuing without Homebrew."
		rm -f "$installer"

		for cand in /home/linuxbrew/.linuxbrew /opt/homebrew /usr/local; do
			if [ -x "$cand/bin/brew" ]; then
				brew_prefix="$cand"
				break
			fi
		done
	fi

	if [ -n "$brew_prefix" ] && brew_functional "$brew_prefix"; then
		# APPEND brew to PATH — the opposite of what `brew shellenv` does.
		# Prepending let brew's binaries shadow the system's wholesale:
		# brew's python@3.x hid /usr/bin/python3 and vim linked against it.
		# With brew at the back, system binaries
		# keep precedence and brew only fills gaps; tools that must beat the
		# system version are whitelisted individually via _brew_first_link.
		case ":$PATH:" in
		*":$brew_prefix/bin:"*) ;;
		*) export PATH="$PATH:$brew_prefix/bin:$brew_prefix/sbin" ;;
		esac
		ok "Homebrew/Linuxbrew ready at $brew_prefix (appended to PATH)."
		# Persist the append block for future shells. Idempotent —
		# append_env_block skips if the marker is already present.
		local line
		line="case \":\$PATH:\" in *\":${brew_prefix}/bin:\"*) ;; *) export PATH=\"\$PATH:${brew_prefix}/bin:${brew_prefix}/sbin\" ;; esac"
		append_env_block "Homebrew PATH (appended)" "$line"
	else
		# Two flavors of "no usable brew": never installed, or installed but
		# dead (bin/brew present, vendor ruby missing). Name the difference so
		# the log points at the right fix.
		if [ -n "$brew_prefix" ]; then
			warn "brew exists at $brew_prefix but cannot run (incomplete install?) — continuing without Homebrew. Fix: reinstall Homebrew."
		else
			warn "brew not found — continuing without Homebrew."
		fi
	fi
}
