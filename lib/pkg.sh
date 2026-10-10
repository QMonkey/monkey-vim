# monkey-scripts/lib/pkg.sh — package installs, grouped by package manager.
#
# Sourced by scripts/install.sh and scripts/checkhealth.sh.
#
# Layout (each group is introduced by a section comment below):
#   ── system package managers ──  pkg_name mapping table, batch filtering,
#       index refresh, pacman lock cleanup, index probing, the install path
#       (install_sys_pkg / install_pkg — the Homebrew-fallback orchestrator),
#       build deps, the AUR helper
#   ── Homebrew ──                 BREW_FIRST, probing, install_linuxbrew
#   ── rust / cargo ──             ensure_rust (rustup)
#   ── go ──                       go_install
#   ── npm ──                      ensure_npm / npm_install_g
#   ── pip / python ──             ensure_pip / install_python_for_gtags
#
# pkg_name() is a single mapping table for the system manager AND the brew
# fallback (brew validates every name up front and aborts the WHOLE batch
# when one is unknown — a lone apt-style "golang-go" would prevent even the
# brew-available fzf from installing). Projects override it AFTER sourcing
# the entry point — the override REPLACES this table, so it must carry every
# base arm it still needs. A case function instead of `declare -A`: macOS
# still ships bash 3.2, which has no associative arrays.

# ────────────────── system package managers ──────────────────
# Names that differ from the binary name for SOME package manager. The arms
# below cover ONLY those (go→golang-go, node→nodejs, black→python3-black,
# ...). A tool whose package name equals its command name (git, tmux,
# ripgrep, fzf, ...) needs no row here — it falls through to `*) echo "$1"`
# at the bottom. Editor/LSP/tooling names shared by monkey-nvim and
# monkey-vim live here; a repo with a one-off mapping (monkey-sway's
# swaymsg, monkey-hyprland's notif, ...) overrides pkg_name() after sourcing.
pkg_name() {
	case "${OS:-unknown}:$1" in
	# Go / Node / shell utilities
	debian:go | ubuntu:go) echo "golang-go" ;;
	centos:go | fedora:go) echo "golang" ;;
	debian:node | ubuntu:node | arch:node | centos:node | fedora:node) echo "nodejs" ;;
	debian:which | ubuntu:which) echo "debianutils" ;;
	arch:python3 | macos:python3) echo "python" ;;
	# python3 needs no versioned mapping: Leap 16 ships a literal python3,
	# Tumbleweed resolves it through the python313 capability. Same for
	# `node` — `nodejs` resolves through the nodejs22/26 capability, which
	# drags the matching npm in as a recommended package.
	opensuse:node) echo "nodejs" ;;
	# pip3 is standalone on every distro (openSUSE's python3-pip is NOT
	# pulled in by python3). The python3- names resolve on openSUSE through
	# capabilities — no interpreter-flavor versioning: a hard python313-
	# name dies the day the default python rolls.
	debian:pip3 | ubuntu:pip3 | centos:pip3 | fedora:pip3) echo "python3-pip" ;;
	arch:pip3) echo "python-pip" ;;
	opensuse:pip3) echo "python3-pip" ;;
	# ── compositor tooling (monkey-sway / monkey-hyprland) ──
	*:swaymsg | *:swaynag) echo "sway" ;;
	*:wl-copy) echo "wl-clipboard" ;;
	*:wpctl) echo "wireplumber" ;;
	*:hyprctl) echo "hyprland" ;;
	# hyprland-dialog: the hyprland-qtutils helpers; coverage varies per
	# release — the availability probe degrades gracefully when missing.
	ubuntu:hyprland-dialog) echo "hyprland-qtutils" ;;
	debian:hyprland-dialog | arch:hyprland-dialog | opensuse:hyprland-dialog) echo "hyprland-guiutils" ;;
	# notification-daemon sentinel: dunst where packaged (EPEL), mako elsewhere.
	debian:notif | ubuntu:notif | centos:notif | fedora:notif) echo "dunst" ;;
	*:notif) echo "mako" ;;
	# polkit agents: the GNOME agent is retired upstream on Fedora/EPEL.
	debian:polkit-gnome-authentication-agent-1) echo "policykit-1-gnome" ;;
	arch:polkit-gnome-authentication-agent-1 | fedora:polkit-gnome-authentication-agent-1) echo "polkit-gnome" ;;
	# tray / network manager
	debian:nm-applet | ubuntu:nm-applet) echo "network-manager-gnome" ;;
	opensuse:nm-applet) echo "NetworkManager-applet" ;;
	arch:nm-applet) echo "network-manager-applet" ;;
	centos:nm-applet | fedora:nm-applet) echo "nm-connection-editor" ;;
	# nm-connection-editor is a binary of network-manager-gnome on Debian/Ubuntu.
	debian:nm-connection-editor | ubuntu:nm-connection-editor) echo "network-manager-gnome" ;;
	opensuse:nm-connection-editor) echo "NetworkManager-connection-editor" ;;
	# notification daemons: Debian/Ubuntu call mako "mako-notifier"
	debian:mako | ubuntu:mako) echo "mako-notifier" ;;
	# Editors / language servers / gtags tooling (monkey-nvim, monkey-vim)
	debian:rg | ubuntu:rg | arch:rg | macos:rg | opensuse:rg | centos:rg | fedora:rg) echo "ripgrep" ;;
	debian:ctags | ubuntu:ctags | macos:ctags | opensuse:ctags | centos:ctags) echo "universal-ctags" ;;
	arch:ctags | fedora:ctags) echo "ctags" ;; # Arch & Fedora ship universal-ctags as "ctags"
	debian:pygmentize | ubuntu:pygmentize) echo "python3-pygments" ;;
	arch:pygmentize) echo "python-pygments" ;;
	macos:pygmentize) echo "pygments" ;;
	opensuse:pygmentize) echo "python3-Pygments" ;; # capability: python313-Pygments provides it
	centos:pygmentize | fedora:pygmentize) echo "python3-pygments" ;;
	debian:pylsp | ubuntu:pylsp) echo "python3-pylsp" ;;
	arch:pylsp | macos:pylsp) echo "python-lsp-server" ;;
	opensuse:pylsp) echo "python3-python-lsp-server" ;; # Leap has NO provider — probe fails → pip fallback (correct)
	centos:pylsp | fedora:pylsp) echo "python3-lsp-server" ;;
	# Debian/Ubuntu split clangd & clang-tidy into unversioned metapackages
	# (`clang` there ships only clang/clang++); Arch and openSUSE's `clang`
	# carry both binaries.
	arch:clangd | arch:clang-tidy | opensuse:clangd | opensuse:clang-tidy) echo "clang" ;;
	debian:clangd | ubuntu:clangd) echo "clangd" ;;
	debian:clang-tidy | ubuntu:clang-tidy) echo "clang-tidy" ;;
	macos:clangd | macos:clang-tidy) echo "llvm" ;;
	centos:clangd | centos:clang-tidy | fedora:clangd | fedora:clang-tidy) echo "clang-tools-extra" ;;
	arch:g++ | macos:g++) echo "gcc" ;;
	opensuse:g++ | centos:g++ | fedora:g++) echo "gcc-c++" ;;
	arch:black) echo "python-black" ;;
	opensuse:black) echo "python3-black" ;;
	centos:black | fedora:black) echo "python3-black" ;;
	*) echo "$1" ;;
	esac
}

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

# ────────────────── package index refresh ──────────────────
# Refresh before installing: a stale index is the usual cause of "Unable to
# locate package" on fresh machines. Retried, never fatal (dnf refreshes on
# demand, brew auto-updates). Guarded to one refresh per run — call freely.
PKG_DB_REFRESHED=0

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

# ────────────────── pacman lock cleanup ──────────────────
# A pacman killed mid-transaction leaves db.lck behind and every later
# transaction then fails with "unable to lock database: File exists"
# (monkey-vim lost exactly this way). Remove the lock only when no pacman
# process is alive — a live holder is left alone (stealing its lock would
# corrupt the database).
PACMAN_DB_LCK=/var/lib/pacman/db.lck
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

# A timed-out pacman attempt can leave a live orphan holding db.lck — kill
# it and clear the now-stale lock so the next attempt is not blocked.
cleanup_timed_out_pacman() {
	sudo_cmd pkill -x pacman 2>/dev/null
	sleep 1
	clear_stale_pacman_lock
	return 0 # best-effort — never fail the caller over cleanup
}

# ────────────────── package-name probing ──────────────────
# Read-only existence checks against the package index; a name the probe
# cannot vouch for is dropped from its install batch. The apt probe greps
# `apt-cache show` — purely virtual packages carry no "Package:" record.

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
		# Literal package name first; openSUSE ships several tools ONLY as
		# capabilities (nodejs, python3, ...), so fall back to a dry-run
		# resolve — "would `zypper install $1` succeed?" without hardcoding
		# versioned names a rolling release drops. The dry-run goes through
		# sudo_cmd: unprivileged it dies with rc 5 (ERR_PRIVILEGES) before
		# the solver even runs — which silently dropped EVERY capability
		# name on Tumbleweed while literal names passed `zypper info`.
		# rc 104 (INF_CAP_NOT_FOUND) is the ONLY "not found" verdict; any
		# other failure must NOT filter the name.
		if zypper --non-interactive info "$1" >/dev/null 2>&1; then
			return 0
		fi
		local rc=0
		sudo_cmd zypper --non-interactive install --dry-run "$1" >/dev/null 2>&1 || rc=$?
		[ "$rc" -ne 104 ]
		;;
	centos | fedora)
		command -v dnf >/dev/null 2>&1 || return 0
		dnf info -q "$1" >/dev/null 2>&1
		;;
	*) return 0 ;; # Homebrew owns macOS; an unknown OS cannot be probed
	esac
}

# The version the DISTRO REPO offers for a package (not the installed one):
# normalized to X.Y, empty when no repo carries it. Sibling of
# probe_pkg_name — answers "repo install or source build?".
repo_pkg_version() {
	local ver=""
	case "$OS" in
	debian | ubuntu) ver=$(apt-cache policy "$1" 2>/dev/null | awk '/Candidate:/{print $2}') ;;
	arch) ver=$(LC_ALL=C pacman -Si "$1" 2>/dev/null | awk '/^Version[[:space:]]*:/ {print $3; exit}') ;;
	opensuse) ver=$(LC_ALL=C zypper --non-interactive info "$1" 2>/dev/null | awk -F': *' '/^Version/{print $2; exit}') ;;
	centos | fedora) ver=$(dnf -q list available "$1" 2>/dev/null | awk 'NR>1 {print $2; exit}') ;;
	esac
	printf '%s' "$ver" | grep -oE '^[0-9]+\.[0-9]+' || true
}

# ────────────────── installs ──────────────────
# Low-level system install, used inside install_pkg and as the brew-failure
# fallback — returns non-zero when the OS is unknown, every name fails its
# probe, or the manager fails.
install_sys_pkg() {
	refresh_pkg
	filter_pkgs probe_pkg_name "$@"
	# Names the official index does not know may still live in the AUR
	# (wlogout was dropped from [extra]) — set them aside for the AUR pass
	# below instead of losing them to the unknown-name warning.
	local -a aur_pkgs=()
	if [ "$OS" = arch ] && ((${#UNKNOWN_PKGS[@]} > 0)); then
		aur_pkgs=(${UNKNOWN_PKGS[@]+"${UNKNOWN_PKGS[@]}"})
	fi
	warn_unknown_pkgs
	if [ ${#PKG_VALID[@]} -eq 0 ]; then
		# arch-only: an all-unknown batch still gets its AUR chance.
		if [ "$OS" = arch ]; then
			install_aur_pkgs ${aur_pkgs[@]+"${aur_pkgs[@]}"}
			return "$?"
		fi
		return 1
	fi
	case "$OS" in
	debian | ubuntu)
		# Fully non-interactive, three layers:
		#   - DEBIAN_FRONTEND/PRIORITY: debconf never draws a dialog;
		#   - --force-confdef/--force-confold: dpkg's conffile "keep or
		#     replace" question is auto-answered (deferring to the default
		#     answer, else keeping the installed file);
		#   - NEEDRESTART_MODE=a: needrestart (shipped by Ubuntu 22.04+)
		#     auto-restarts services instead of showing its interactive
		#     daemon list.
		# All three matter because the call runs under retry→timeout, whose
		# child sits in a NON-foreground process group: ANY prompt there is
		# frozen by SIGTTIN the moment it reads the terminal — the run hangs
		# with input unreachable (observed on Ubuntu, same class as the old
		# in-retry sudo -v password freeze). `sudo_cmd env` keeps the
		# variables intact through sudo's env_reset.
		retry -t 1800 -s "apt-get install" sudo_cmd env DEBIAN_FRONTEND=noninteractive DEBIAN_PRIORITY=critical NEEDRESTART_MODE=a apt-get install -y -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold ${PKG_VALID[@]+"${PKG_VALID[@]}"}
		;;
	arch)
		clear_stale_pacman_lock
		local rc=0
		retry -t 1800 -s "pacman install" sudo_cmd pacman -S --noconfirm ${PKG_VALID[@]+"${PKG_VALID[@]}"} || rc=$?
		[ "$rc" -eq 124 ] && cleanup_timed_out_pacman
		# The official batch landed (or not) — the dropped names still get
		# their AUR pass; its failure does not undo the pacman result.
		((${#aur_pkgs[@]} > 0)) && install_aur_pkgs ${aur_pkgs[@]+"${aur_pkgs[@]}"}
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

# A package present in every repo set of its distro — the probe canary for
# install_pkg's brew fallback: when the canary itself probes negative, the
# index is unreachable (network outage) and every "unknown" verdict is a
# false negative. macOS: no system manager, no canary.
_pkg_index_canary() {
	case "$OS" in
	debian | ubuntu) echo "dpkg" ;;
	arch | opensuse | centos | fedora) echo "filesystem" ;;
	*) return 1 ;;
	esac
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
					filter_pkgs probe_brew_name "${bpkg[@]}"
					warn_unknown_pkgs
					# All names filtered: the arithmetic test fails and _rc
					# records it — same as an actual failed brew call.
					if ((${#PKG_VALID[@]} > 0)); then
						brew_install_retry 1800 "brew install (fallback)" ${PKG_VALID[@]+"${PKG_VALID[@]}"}
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
		filter_pkgs probe_brew_name "${brew_pkgs[@]}"
		warn_unknown_pkgs
		if ((${#PKG_VALID[@]} > 0)); then
			local brc=0
			# The BREW_FIRST batch can carry heavy formulae (zig pulls
			# llvm@22 + lld@22) — 7200 gives those downloads room.
			brew_install_retry 7200 "brew install" ${PKG_VALID[@]+"${PKG_VALID[@]}"} || brc=$?
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
			# zig transitively) with no successful batch rc of its own. _brew_first_link
			# skips any name brew does not provide, so the wide call is
			# harmless when the batch genuinely failed.
			_brew_first_link ${BREW_FIRST[@]+"${BREW_FIRST[@]}"}
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

# ────────────────── source-build dependency groups ──────────────────
# Projects that build from source (tmux, neovim, ...) name LOGICAL GROUPS
# here; this table owns the per-distro names — same dispatch style as
# pkg_name. Project-specific extras stay in the project.
#
# Usage: install_build_deps toolchain vcs autotools libevent ncurses bison
install_build_deps() {
	refresh_pkg
	local -a names=() group
	for group in "$@"; do
		case "$OS" in
		debian | ubuntu)
			case "$group" in
			toolchain) names+=(build-essential) ;;
			vcs) names+=(git curl) ;;
			autotools) names+=(autoconf automake pkg-config) ;;
			libevent) names+=(libevent-dev) ;;
			ncurses) names+=(libncurses-dev) ;;
			bison | cmake | gettext) names+=("$group") ;;
			*) warn "install_build_deps: unknown group '$group' — skipped." ;;
			esac
			;;
		arch)
			# base-devel is a meta-package covering toolchain/autotools/bison/
			# gettext; --needed keeps re-installs away.
			case "$group" in
			toolchain | autotools | bison | gettext) names+=(base-devel) ;;
			vcs) names+=(git curl) ;;
			libevent) names+=(libevent) ;;
			ncurses) names+=(ncurses) ;;
			cmake) names+=(cmake) ;;
			*) warn "install_build_deps: unknown group '$group' — skipped." ;;
			esac
			;;
		opensuse)
			case "$group" in
			toolchain) names+=(gcc make) ;;
			vcs) names+=(git curl) ;;
			autotools) names+=(autoconf automake pkg-config) ;;
			libevent) names+=(libevent-devel) ;;
			ncurses) names+=(ncurses-devel) ;;
			bison | cmake | gettext) names+=("$group") ;;
			*) warn "install_build_deps: unknown group '$group' — skipped." ;;
			esac
			;;
		centos | fedora)
			case "$group" in
			toolchain) names+=(gcc gcc-c++ make) ;;
			vcs) names+=(git curl) ;;
			autotools) names+=(autoconf automake pkgconfig) ;;
			libevent) names+=(libevent-devel) ;;
			ncurses) names+=(ncurses-devel) ;;
			bison | cmake | gettext) names+=("$group") ;;
			*) warn "install_build_deps: unknown group '$group' — skipped." ;;
			esac
			;;
		macos)
			# Xcode CLT provides the toolchain, curl ships with macOS.
			case "$group" in
			toolchain) ;;
			vcs) names+=(git) ;;
			autotools) names+=(autoconf automake pkg-config) ;;
			libevent | ncurses | bison | cmake | gettext) names+=("$group") ;;
			*) warn "install_build_deps: unknown group '$group' — skipped." ;;
			esac
			;;
		*)
			warn "install_build_deps: unsupported OS '$OS' — skipped."
			return 0
			;;
		esac
	done
	# Groups overlap by design — dedupe, order-preserving.
	local -a unique=() n
	for n in ${names[@]+"${names[@]}"}; do
		case " ${unique[*]-} " in *" $n "*) continue ;; esac
		unique+=("$n")
	done
	names=("${unique[@]}")
	((${#names[@]} > 0)) || return 0
	if [ "$OS" = macos ]; then
		brew_install_retry 1800 "brew install build deps" ${names[@]+"${names[@]}"}
	else
		install_sys_pkg ${names[@]+"${names[@]}"}
	fi
	hash -r
}

# Human install command for one or more package names — the "Run:" line and
# the hint after a failed install.
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

# Install a binary from the system package manager if it is missing.
# Usage: ensure_system_bin <bin> <desc> — never fatal (the package may not be
# in the repos; checkhealth reports what is left afterwards).
ensure_system_bin() {
	local bin="$1" desc="${2:-$1}" ver
	if have_native_cmd "$bin"; then
		ver=$(extract_version "$bin")
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

# ──────────────────────────── AUR helper (arch) ────────────────────────────
# Tools move from the official repos to the AUR (wlogout left [extra]
# outright) and filter_pkgs would drop such a name forever. paru builds AUR
# packages through makepkg — each PKGBUILD carries its own makedepends, the
# only prerequisite is base-devel + git. SOURCE paru over -bin: the prebuilt
# binary breaks when the system libalpm outgrows its SONAME, and the source
# build would not pull a full Rust toolchain onto every machine.
AUR_HELPER=paru

have_aur_helper() {
	[ "$OS" = arch ] || return 1
	have_native_cmd "$AUR_HELPER"
}

# One-time bootstrap: base-devel + git, then makepkg paru from the AUR into
# a throwaway clone. makepkg runs as the invoking user; its final `pacman -U`
# shells out to sudo itself (covered by the NOPASSWD drop-in). Never run the
# helper itself under sudo_cmd — paru refuses root. Returns 0 when makepkg
# succeeded; the caller decides whether the result actually RUNS.
_ensure_aur_variant() {
	# NB: two separate local statements — `local pkg="$1" dir="...${pkg}..."`
	# expands ${pkg} BEFORE pkg is assigned, producing "/tmp/-build.$$".
	local pkg="$1"
	local dir="/tmp/${pkg}-build.$$" rc=0
	retry -s "AUR $pkg clone" git clone "https://aur.archlinux.org/${pkg}.git" "$dir" || {
		rm -rf "$dir"
		return 1
	}
	# makepkg needs the PKGBUILD in cwd — build in a subshell cd'ed into the
	# checkout so the caller's cwd survives. Missing this cd made the build
	# die with "PKGBUILD does not exist" on every run, leaving every
	# AUR-only package (wlogout) unavailable.
	(cd "$dir" && retry -t 1800 -s "AUR $pkg build" makepkg -si --noconfirm) || rc=$?
	rm -rf "$dir"
	return "$rc"
}

# Remove whatever package owns the dead helper binary (paru, paru-bin, ...)
# so the source build can install as if fresh — the variants are declared in
# conflict and makepkg's `pacman -U` would abort with "unresolvable package
# conflicts". Ownership is DISCOVERED via pacman -Qo (paru-bin also ships
# /usr/bin/paru); the "-debug" twin goes with the owner. Best-effort.
_remove_dead_aur_helper_pkg() {
	local bin owner
	bin=$(command -v "$1" 2>/dev/null) || return 0
	owner=$(pacman -Qoq "$bin" 2>/dev/null | head -n1) || return 0
	[ -n "$owner" ] || return 0
	local -a names=("$owner")
	pacman -Qi "${owner}-debug" >/dev/null 2>&1 && names+=("${owner}-debug")
	sudo_cmd pacman -Rns --noconfirm ${names[@]+"${names[@]}"} || true
	return 0
}

ensure_aur_helper() {
	if have_aur_helper && "$AUR_HELPER" --version >/dev/null 2>&1; then
		return 0
	fi
	[ "$OS" = arch ] || return 1
	if have_aur_helper; then
		warn "$AUR_HELPER exists but cannot run (system libalpm moved past its build?) — removing it and building from source..."
		_remove_dead_aur_helper_pkg "$AUR_HELPER"
	else
		info "installing $AUR_HELPER (AUR helper) from source..."
	fi
	# base-devel is a package GROUP, not a package — a pacman -Si probe
	# cannot vouch for it, so install straight through pacman (--needed
	# keeps it a no-op when the toolchain exists).
	refresh_pkg
	retry -t 1800 -s "pacman install base-devel git" sudo_cmd pacman -S --needed --noconfirm base-devel git || return 1
	local rc=0
	_ensure_aur_variant "$AUR_HELPER" || rc=$?
	hash -r
	if [ "$rc" -eq 0 ] && have_aur_helper && "$AUR_HELPER" --version >/dev/null 2>&1; then
		ok "$AUR_HELPER ready."
	else
		rc=1
		warn "$AUR_HELPER is still not available."
	fi
	return "$rc"
}

probe_aur_name() {
	# `paru -Si` is an AUR-RPC query and fails on an unknown name. Probes are
	# single-shot by policy — a transient failure drops the name and the
	# outer retry heals. Without a helper: don't filter.
	have_aur_helper || return 0
	"$AUR_HELPER" -Si "$1" >/dev/null 2>&1
}

# AUR batch install for names the official index does not carry. Filtered
# first (one bad name fails the whole paru transaction, same policy as the
# pacman/brew probes); retried like every other network operation.
install_aur_pkgs() {
	[ "$OS" = arch ] || return 0
	(($# > 0)) || return 0
	ensure_aur_helper || {
		warn "AUR helper unavailable — not installed: $*"
		return 1
	}
	filter_pkgs probe_aur_name "$@"
	warn_unknown_pkgs
	((${#PKG_VALID[@]} > 0)) || return 1
	local rc=0
	retry -t 1800 -s "AUR install" "$AUR_HELPER" -S --needed --noconfirm ${PKG_VALID[@]+"${PKG_VALID[@]}"} || rc=$?
	hash -r
	return "$rc"
}

# ──────────────────────────── Homebrew ────────────────────────────
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

# The brew twin of the pacman orphan: retry's timeout kills the brew WRAPPER
# but not its ruby worker, which stays alive holding the cache flock — every
# later brew then refuses with "already locked". Homebrew's locks are flocks
# (release when the holder dies), so killing the orphan IS the unlock.
# Scoped to cmdlines mentioning the brew prefix (a bare `pkill brew` misses
# the ruby worker); only fires after OUR OWN timed-out attempt.
cleanup_timed_out_brew() {
	local prefix
	prefix="$(brew --prefix 2>/dev/null)" || return 0
	pgrep -f "$prefix" >/dev/null 2>&1 || return 0
	warn "killing orphaned brew process(es) left by the timed-out brew (they hold the cache flock)..."
	pkill -f "$prefix" 2>/dev/null
	sleep 1
	return 0 # best-effort — never fail the caller over cleanup
}

# One brew install with the standard retry; a timed-out attempt (rc 124)
# triggers the orphan cleanup so the retry ladder does not hit the same
# lock again. Returns the install's exit code.
brew_install_retry() {
	local t="$1" desc="$2"
	shift 2
	local brc=0
	# HOMEBREW_NO_INTERACTIVE: brew must never prompt (broken-install
	# removal, stdin-reading formula hooks, ...). Under retry→timeout the
	# child sits in a NON-foreground process group — a prompt there is
	# frozen by SIGTTIN with input unreachable (observed on Ubuntu:
	# checkhealth --install hung at brew install zig's [y/n], ^C/D dead).
	# With the flag brew fails fast instead; retry then re-attempts and the
	# failure stays visible. The Homebrew INSTALLER already runs with
	# NONINTERACTIVE=1 (install_linuxbrew) — this covers the runtime side.
	retry -t "$t" -s "$desc" env HOMEBREW_NO_INTERACTIVE=1 brew install "$@" || brc=$?
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
	if ! retry -t 1800 -s "rustup installer download" curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs -o "$rustup_init"; then
		rm -f "$rustup_init"
		warn "rustup install failed — install it manually: https://rust-lang.org/tools/install/"
		return 1
	fi
	if ! retry -t 3600 -s "rustup toolchain install" sh "$rustup_init" -y; then
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
	retry -t 1800 -s "go install ${1%@*}" go install "$@"
}

# ──────────────────────────── npm ────────────────────────────
# A plain `npm` can resolve to a /mnt/* Windows shim whose global prefix is
# the Windows tree; every npm/node lookup here goes through native_bin_path.
# Debian/Ubuntu: `apt install nodejs` does NOT bring npm (Suggests only), so
# npm must be installed explicitly and verified afterwards.
ensure_npm() {
	if have_native_cmd npm && have_native_cmd node; then
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
		retry -t 1800 -s "brew install node" brew install node || true
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
	retry -t 1800 -s "npm install -g $*" npm install -g ${flags[@]+"${flags[@]}"} "$@"
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
				retry -t 3600 -s "zypper update (full)" sudo_cmd zypper update -y --auto-agree-with-licenses >/dev/null 2>&1 || true
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
