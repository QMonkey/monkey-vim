# monkey-scripts/lib/distro.sh — the DISTRO package-manager family:
# apt / pacman / zypper / dnf plus the AUR (arch's second repo set). Owns
# everything "what does THIS distro's repository carry and how do I install
# it": the name mapping, index refresh, index probing, the per-name
# "installed" query, the batch installers, build-dep groups. Sourced by
# lib/bootstrap.sh; the install chain (lib/pkg.sh) reaches it only through
# the lane dispatchers there, as the "pkg" lane and the "aur" lane.
#
# Distro-specific quirks are deliberate here, not folded away: apt runs
# fully non-interactive (three env layers), pacman needs stale-lock repair,
# zypper resolves capabilities via a privileged dry-run, dnf pulls EPEL.
# That is also why the chain dispatches to whole functions instead of
# passing a manager id down and expecting a generic body.

# ────────────────── package-name mapping ──────────────────
# The tables below map a binary to a package name. The DOOR that selects
# which table answers — pkg_name <bin> [lane], lib/pkg.sh — lives with the
# other lane verbs, so a caller never has to know which file owns a namespace.
# Names that differ from the binary name for SOME distro manager. The arms
# below cover ONLY those (go→golang-go, node→nodejs, black→python3-black,
# ...). A tool whose package name equals its command name (git, tmux,
# ripgrep, fzf, ...) needs no row here — it falls through to `*) echo "$1"`
# at the bottom. Editor/LSP/tooling names shared by monkey-nvim and
# monkey-vim live here; Homebrew's own mapping is brew_name (lib/brew.sh),
# which pkg_name selects on macOS and for any brew-lane request.
distro_name() {
	case "${OS:-unknown}:$1" in
	# Go / Node / shell utilities
	debian:go | ubuntu:go) echo "golang-go" ;;
	centos:go | fedora:go) echo "golang" ;;
	debian:node | ubuntu:node | arch:node | centos:node | fedora:node) echo "nodejs" ;;
	debian:which | ubuntu:which) echo "debianutils" ;;
	arch:python3) echo "python" ;;
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
	# CentOS Stream 10 splits npm into nodejs-npm; the bare name matches
	# nothing (dnf ≥4.20 "info npm" → no match, rc 0).
	centos:npm) echo "nodejs-npm" ;;
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
	# Ubuntu carries policykit-1-gnome in universe (incl. resolute) — the
	# D-Bus agent name must map, or apt gets asked for a name no repo has.
	debian:polkit-gnome-authentication-agent-1 | ubuntu:polkit-gnome-authentication-agent-1) echo "policykit-1-gnome" ;;
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
	debian:rg | ubuntu:rg | arch:rg | opensuse:rg | centos:rg | fedora:rg) echo "ripgrep" ;;
	debian:ctags | ubuntu:ctags | opensuse:ctags | centos:ctags) echo "universal-ctags" ;;
	arch:ctags | fedora:ctags) echo "ctags" ;; # Arch & Fedora ship universal-ctags as "ctags"
	debian:pygmentize | ubuntu:pygmentize) echo "python3-pygments" ;;
	arch:pygmentize) echo "python-pygments" ;;
	opensuse:pygmentize) echo "python3-Pygments" ;; # capability: python313-Pygments provides it
	centos:pygmentize | fedora:pygmentize) echo "python3-pygments" ;;
	debian:pylsp | ubuntu:pylsp) echo "python3-pylsp" ;;
	# python-lsp-black: pylsp's black plugin (no binary — py:module probe).
	# Arch ships python-lsp-black under its own name; openSUSE prefixes the
	# PyPI name verbatim (python3-<pypi>); Fedora: not packaged (probe
	# drops it → the spec's pip fallback installs).
	debian:python-lsp-black | ubuntu:python-lsp-black) echo "python3-pylsp-black" ;;
	opensuse:python-lsp-black) echo "python3-python-lsp-black" ;;
	arch:pylsp) echo "python-lsp-server" ;;
	opensuse:pylsp) echo "python3-python-lsp-server" ;; # Leap has NO provider — probe fails → pip fallback (correct)
	centos:pylsp | fedora:pylsp) echo "python3-lsp-server" ;;
	# Debian/Ubuntu split clangd & clang-tidy into unversioned metapackages
	# (`clang` there ships only clang/clang++); Arch and openSUSE's `clang`
	# carry both binaries.
	arch:clangd | arch:clang-tidy | opensuse:clangd | opensuse:clang-tidy) echo "clang" ;;
	debian:clangd | ubuntu:clangd) echo "clangd" ;;
	debian:clang-tidy | ubuntu:clang-tidy) echo "clang-tidy" ;;
	centos:clangd | centos:clang-tidy | fedora:clangd | fedora:clang-tidy) echo "clang-tools-extra" ;;
	arch:g++) echo "gcc" ;;
	opensuse:g++ | centos:g++ | fedora:g++) echo "gcc-c++" ;;
	arch:black) echo "python-black" ;;
	opensuse:black) echo "python3-black" ;;
	centos:black | fedora:black) echo "python3-black" ;;
	*) echo "$1" ;;
	esac
}

# ────────────────── package index refresh ──────────────────
# Refresh before installing: a stale index is the usual cause of "Unable to
# locate package" on fresh machines. Retried, never fatal (dnf refreshes on
# demand, brew auto-updates). Guarded to one refresh per run — call freely.
PKG_DB_REFRESHED=0

distro_refresh() {
	[ "$PKG_DB_REFRESHED" -eq 1 ] && return 0
	PKG_DB_REFRESHED=1
	case "$OS" in
	debian | ubuntu) retry -t "$RETRY_T_NET" -s "apt-get update" sudo_cmd apt-get update ;;
	arch)
		clear_stale_pacman_lock
		# -H: reap a timeout-orphaned pacman between attempts (db.lck).
		retry -t "$RETRY_T_NET" -H distro_cleanup_timed_out -s "pacman -Sy" sudo_cmd pacman -Sy
		;;
	opensuse) retry -t "$RETRY_T_NET" -s "zypper refresh" sudo_cmd zypper --non-interactive refresh ;;
	centos | fedora) retry -t "$RETRY_T_NET" -s "dnf makecache" sudo_cmd dnf makecache -q ;;
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

# A timed-out pacman attempt leaves a live orphan holding db.lck — kill it
# and clear the lock. Called two ways: bare (caller already verified the
# timeout — always cleans up) or via retry's -H hook with the attempt's
# exit code as $1 (only 124 leaves an orphan to reap).
distro_cleanup_timed_out() {
	case "${1-}" in
	"" | 124) ;;   # bare call or a timeout — clean up
	*) return 0 ;; # any other explicit exit code — nothing to reap
	esac
	sudo_cmd pkill -x pacman 2>/dev/null
	sleep 1
	clear_stale_pacman_lock
	return 0 # best-effort — never fail the caller over cleanup
}

# ────────────────── package-name probing ──────────────────
# Read-only existence checks against the package index; a name the probe
# cannot vouch for is dropped from its install batch. The apt probe greps
# `apt-cache show` — purely virtual packages carry no "Package:" record.
# None of them refreshes the metadata (--no-refresh on zypper): the run
# refreshes once through distro_refresh, and a probe that refreshed again
# would pay the network for every name it is asked about. The contract the
# probes must satisfy lives in lib/pkg.sh (the lane verbs).

distro_probe() {
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
		if zypper --non-interactive --no-refresh info "$1" >/dev/null 2>&1; then
			return 0
		fi
		local rc=0
		sudo_cmd zypper --non-interactive --no-refresh install --dry-run "$1" >/dev/null 2>&1 || rc=$?
		[ "$rc" -ne 104 ]
		;;
	centos | fedora)
		command -v dnf >/dev/null 2>&1 || return 0
		dnf info -q "$1" >/dev/null 2>&1
		;;
	*) return 0 ;; # Homebrew owns macOS; an unknown OS cannot be probed
	esac
}

# distro_installed <pkgname> — does the LOCAL database own this package?
# The per-name truth after a transaction returned non-zero: a timed-out
# install can have finished (the timeout kills the wrapper after the files
# land), and the chain must not hand such a name to another lane — a second
# copy on PATH is worse than a retry. Batch rc is not a per-name verdict, and
# a command-name probe cannot substitute (package names are not binary names:
# NetworkManager-applet, python3-lsp-server, debianutils). Read-only, and the
# managers' own query verbs — no solver, no network.
distro_installed() {
	case "$OS" in
	debian | ubuntu)
		command -v dpkg-query >/dev/null 2>&1 || return 1
		# "ii" = installed OK; rc alone is 0 for a known-but-removed package,
		# so the status field is the verdict. Glob, not equality: command
		# substitution strips the field's trailing space ("ii " → "ii"), and
		# a `[ x = "ii " ]` test would then never match anything.
		local st
		st=$(dpkg-query -W -f='${db:Status-Abbrev}' "$1" 2>/dev/null) || return 1
		case "$st" in ii*) return 0 ;; esac
		return 1
		;;
	arch)
		command -v pacman >/dev/null 2>&1 || return 1
		pacman -Qi "$1" >/dev/null 2>&1
		;;
	opensuse | centos | fedora)
		command -v rpm >/dev/null 2>&1 || return 1
		# --whatprovides, not a bare -q: the names these lanes install are
		# OFTEN capabilities (measured on Tumbleweed — `rpm -q python3-pip`
		# says "no" while python313-pip is installed and provides it, and
		# nodejs resolves through nodejs26/28). A plain -q would call those
		# deliveries failures and hand the name to the next lane — the exact
		# double copy this verb exists to prevent. An available-but-not-
		# installed name still answers "no": rpm's database is local only.
		rpm -q --whatprovides "$1" >/dev/null 2>&1
		;;
	*) return 1 ;; # Homebrew owns macOS (brew_installed, lib/brew.sh)
	esac
}

# ────────────────── index reachability ──────────────────
# A package present in every repo set of its distro — the canary that says
# whether distro_probe's "not carried" answers mean anything. Probing
# against a dead mirror rejects EVERY name, and treating those rejections as
# coverage gaps is how wl-clipboard, wireplumber and mako once got installed
# from bottles while pacman was down. The chain asks before letting a later
# lane act on an index miss; macOS has no system index and no canary.
_pkg_index_canary() {
	case "$(pkg_manager)" in
	apt) echo "dpkg" ;;
	pacman | zypper | dnf) echo "filesystem" ;;
	*) return 1 ;;
	esac
}

distro_index_ok() {
	local canary
	# No canary (unsupported / absent manager) means nothing to distrust:
	# the lane's own probes and transactions are the only verdict left.
	canary="$(_pkg_index_canary)" || return 0
	[ -n "$canary" ] || return 0
	distro_probe "$canary"
}

# The version the DISTRO REPO offers for a package (not the installed one):
# normalized to X.Y, empty when no repo carries it. Sibling of
# distro_probe — answers "repo install or source build?".
distro_version() {
	local ver=""
	case "$OS" in
	debian | ubuntu) ver=$(apt-cache policy "$1" 2>/dev/null | awk '/Candidate:/{print $2}') ;;
	arch) ver=$(LC_ALL=C pacman -Si "$1" 2>/dev/null | awk '/^Version[[:space:]]*:/ {print $3; exit}') ;;
	opensuse) ver=$(LC_ALL=C zypper --non-interactive --no-refresh info "$1" 2>/dev/null | awk -F': *' '/^Version/{print $2; exit}') ;;
	# repoquery reads the REPO metadata only (installed state irrelevant,
	# which is why `dnf list available` was wrong: it omits installed
	# packages), and %{VERSION} carries no epoch prefix (`dnf list` shows
	# "1:22.23.2-1.el10", which breaks the X.Y normalization below).
	centos | fedora) ver=$(dnf -q repoquery --latest-limit=1 --qf '%{VERSION}' "$1" 2>/dev/null | head -1) ;;
	esac
	printf '%s' "$ver" | grep -oE '^[0-9]+\.[0-9]+' || true
}

# ────────────────── installs ──────────────────
# The "pkg" lane's batch installer: refresh, filter, ONE transaction for
# every name this index carries. The chain calls it through pkg_install;
# install_build_deps calls it directly because its argument space is GROUPS
# (base-devel, build-essential) that no index probe can vouch for. That is
# also why the filter here stays silent: WHO reports the dropped names is the
# caller's decision — chain_install reports once at the end of the walk (a
# lane must not call a name "skipped" while a later lane is about to install
# it), install_build_deps calls warn_unknown_pkgs itself.
#
# PKG_VALID / UNKNOWN_PKGS after the call ARE the lane's verdicts (carried /
# not carried). The return status is the TRANSACTION result, never a per-name
# answer — the chain asks distro_installed for that.
distro_install() {
	distro_refresh
	filter_pkgs distro_probe "$@"
	if [ ${#PKG_VALID[@]} -eq 0 ]; then
		return 1 # an all-unknown batch is a NOT_INDEXED verdict, not a failure
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
		retry -t "$RETRY_T_NET" -s "apt-get install" sudo_cmd env DEBIAN_FRONTEND=noninteractive DEBIAN_PRIORITY=critical NEEDRESTART_MODE=a apt-get install -y -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold ${PKG_VALID[@]+"${PKG_VALID[@]}"}
		;;
	arch)
		local rc=0
		clear_stale_pacman_lock
		# -H: reap a timeout-orphaned pacman between attempts (db.lck).
		retry -t "$RETRY_T_NET" -H distro_cleanup_timed_out -s "pacman install" sudo_cmd pacman -S --noconfirm ${PKG_VALID[@]+"${PKG_VALID[@]}"} || rc=$?
		return "$rc"
		;;
	opensuse) retry -t "$RETRY_T_NET" -s "zypper install" sudo_cmd zypper --non-interactive install -y ${PKG_VALID[@]+"${PKG_VALID[@]}"} ;;
	centos | fedora)
		# Some tools (universal-ctags, global, fzf, bat, pygments) live in EPEL,
		# which only CentOS needs — Fedora ships them in the base repos.
		if [ "$OS" = centos ]; then
			sudo_cmd dnf install -y epel-release || true
		fi
		# gtags needs the global-ctags subpackage (ctags back-end config);
		# without it gtags is unusable.
		local -a _args=(${PKG_VALID[@]+"${PKG_VALID[@]}"})
		[[ " ${_args[*]} " =~ " global " ]] && _args+=(global-ctags)
		retry -t "$RETRY_T_NET" -s "dnf install" sudo_cmd dnf install -y "${_args[@]}"
		;;
	macos) return 1 ;; # Homebrew owns macOS — the chain routes those names to brew
	*) return 1 ;;
	esac
}

# ────────────────── source-build dependency groups ──────────────────
# Projects that build from source (tmux, neovim, ...) name LOGICAL GROUPS
# here; this table owns the per-distro names — same dispatch style as
# pkg_name. Project-specific extras stay in the project.
#
# Group-outer / OS-inner dispatch: groups that map to the same packages on
# every distro (vcs, cmake, ...) are written once; only the divergent cells
# (toolchain, versioned -devel names, arch's base-devel) get an OS branch.
#
# Usage: install_build_deps toolchain vcs autotools libevent ncurses bison
install_build_deps() {
	case "$OS" in
	debian | ubuntu | arch | opensuse | centos | fedora | macos) ;;
	*)
		warn "install_build_deps: unsupported OS '$OS' — skipped."
		return 0
		;;
	esac
	distro_refresh
	local -a names=()
	local group
	for group in "$@"; do
		case "$group" in
		toolchain)
			case "$OS" in
			debian | ubuntu) names+=(build-essential) ;;
			arch) names+=(base-devel) ;;
			opensuse) names+=(gcc make) ;;
			centos | fedora) names+=(gcc gcc-c++ make) ;;
			macos) ;; # Xcode CLT provides the toolchain
			esac
			;;
		vcs)
			case "$OS" in
			macos) names+=(git) ;; # curl ships with macOS
			*) names+=(git curl) ;;
			esac
			;;
		autotools)
			case "$OS" in
			arch) names+=(base-devel) ;;
			centos | fedora) names+=(autoconf automake pkgconfig) ;;
			*) names+=(autoconf automake pkg-config) ;;
			esac
			;;
		libevent)
			case "$OS" in
			debian | ubuntu) names+=(libevent-dev) ;;
			arch | macos) names+=(libevent) ;;
			*) names+=(libevent-devel) ;;
			esac
			;;
		ncurses)
			case "$OS" in
			debian | ubuntu) names+=(libncurses-dev) ;;
			arch | macos) names+=(ncurses) ;;
			*) names+=(ncurses-devel) ;;
			esac
			;;
		bison | gettext)
			# arch folds both into base-devel (a package GROUP — see the
			# toolchain arm); everywhere else the group IS the package name.
			case "$OS" in
			arch) names+=(base-devel) ;;
			*) names+=("$group") ;;
			esac
			;;
		cmake) names+=(cmake) ;;
		*)
			warn "install_build_deps: unknown group '$group' — skipped."
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
	# Deliberately NOT the chain: build dependencies are package GROUPS
	# (base-devel on arch is a group, not a package, so no index probe can
	# vouch for it) and an unmatched group name must never become a reason to
	# go looking in the AUR or in bottles. One lane, chosen by OS, and this
	# caller reports what that lane refused — distro_install filters silently
	# because the chain reports at the end of its walk instead.
	if [ "$OS" = macos ]; then
		brew_install ${names[@]+"${names[@]}"}
	else
		distro_install ${names[@]+"${names[@]}"}
	fi
	warn_unknown_pkgs
	hash -r
}

# ──────────────────────────── AUR helper (arch) ────────────────────────────
# Tools move from the official repos to the AUR (wlogout left [extra]
# outright) and filter_pkgs would drop such a name forever. paru builds AUR
# packages through makepkg — each PKGBUILD carries its own makedepends, the
# only prerequisite is base-devel + git. SOURCE paru over -bin: the prebuilt
# binary breaks when the system libalpm outgrows its SONAME, and the source
# build would not pull a full Rust toolchain onto every machine.
AUR_HELPER=paru

aur_have_helper() {
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
	# AUR-only package (wlogout) unavailable. -H: makepkg's `pacman -U`
	# child can be orphaned holding db.lck.
	(cd "$dir" && retry -t "$RETRY_T_NET" -H distro_cleanup_timed_out -s "AUR $pkg build" makepkg -si --noconfirm) || rc=$?
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

aur_ensure() {
	if aur_have_helper && "$AUR_HELPER" --version >/dev/null 2>&1; then
		return 0
	fi
	[ "$OS" = arch ] || return 1
	if aur_have_helper; then
		warn "$AUR_HELPER exists but cannot run (system libalpm moved past its build?) — removing it and building from source..."
		_remove_dead_aur_helper_pkg "$AUR_HELPER"
	else
		info "installing $AUR_HELPER (AUR helper) from source..."
	fi
	# base-devel is a package GROUP, not a package — a pacman -Si probe
	# cannot vouch for it, so install straight through pacman (--needed
	# keeps it a no-op when the toolchain exists).
	distro_refresh
	retry -t "$RETRY_T_NET" -H distro_cleanup_timed_out -s "pacman install base-devel git" sudo_cmd pacman -S --needed --noconfirm base-devel git || return 1
	local rc=0
	_ensure_aur_variant "$AUR_HELPER" || rc=$?
	hash -r
	if [ "$rc" -eq 0 ] && aur_have_helper && "$AUR_HELPER" --version >/dev/null 2>&1; then
		ok "$AUR_HELPER ready."
	else
		rc=1
		warn "$AUR_HELPER is still not available."
	fi
	return "$rc"
}

aur_probe() {
	# `paru -Si` is an AUR-RPC query and fails on an unknown name. Probes are
	# single-shot by policy — a transient failure drops the name and the
	# outer retry heals. Without a helper: don't filter.
	aur_have_helper || return 0
	"$AUR_HELPER" -Si "$1" >/dev/null 2>&1
}

# The AUR lane's per-name install query. paru builds into the local pacman
# database like any other package, so the distro query answers for it —
# keeping this a separate verb is what lets the chain ask "did THIS lane
# deliver it" without assuming the two repo sets share a verdict.
aur_installed() {
	distro_installed "$@"
}

# AUR batch install for names the official index does not carry — the "aur"
# lane of the chain (and the arch lane pair's whole reason for existing:
# tools move out of [extra] and would otherwise be dropped forever).
# Filtered first (one bad name fails the whole paru transaction, same policy
# as the pacman/brew probes), retried like every other network operation,
# silent like every other lane installer: the chain reports.
aur_install() {
	[ "$OS" = arch ] || return 0
	(($# > 0)) || return 0
	aur_ensure || {
		warn "AUR helper unavailable — not installed: $*"
		return 1
	}
	filter_pkgs aur_probe "$@"
	((${#PKG_VALID[@]} > 0)) || return 1
	local rc=0
	# -H: the helper drives pacman internally — same orphan risk.
	retry -t "$RETRY_T_NET" -H distro_cleanup_timed_out -s "AUR install" "$AUR_HELPER" -S --needed --noconfirm ${PKG_VALID[@]+"${PKG_VALID[@]}"} || rc=$?
	hash -r
	return "$rc"
}
