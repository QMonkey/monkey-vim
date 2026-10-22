# monkey-scripts/lib/distro.sh — the DISTRO package-manager family:
# apt / pacman / zypper / dnf plus the AUR (arch's second repo set). Owns
# everything "what does THIS distro's repository carry and how do I install
# it": the pkg_name mapping, index refresh, index probing, the batch
# installer, build-dep groups. Sourced by lib/bootstrap.sh; install_pkg
# (lib/pkg.sh) drives it as the primary lane, with brew.sh as fallback.
#
# Distro-specific quirks are deliberate here, not folded away: apt runs
# fully non-interactive (three env layers), pacman needs stale-lock repair,
# zypper resolves capabilities via a privileged dry-run, dnf pulls EPEL.

# ────────────────── system package managers ──────────────────
# The ONE OS → package-manager mapping (apt | pacman | zypper | dnf | brew,
# "" when nothing applies). Simple mappers (install hints, canary, display
# name) dispatch through this; the install/probe/refresh paths keep their
# explicit per-OS cases — their branches carry distro-specific behaviour
# (apt env vars, the pacman lock, EPEL, zypper capabilities) that a flat id
# cannot express.
pkg_manager() {
	case "${OS:-unknown}" in
	debian | ubuntu) echo "apt" ;;
	arch) echo "pacman" ;;
	opensuse) echo "zypper" ;;
	centos | fedora) echo "dnf" ;;
	macos) echo "brew" ;;
	*) echo "" ;;
	esac
}

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
	debian:rg | ubuntu:rg | arch:rg | macos:rg | opensuse:rg | centos:rg | fedora:rg) echo "ripgrep" ;;
	debian:ctags | ubuntu:ctags | macos:ctags | opensuse:ctags | centos:ctags) echo "universal-ctags" ;;
	arch:ctags | fedora:ctags) echo "ctags" ;; # Arch & Fedora ship universal-ctags as "ctags"
	debian:pygmentize | ubuntu:pygmentize) echo "python3-pygments" ;;
	arch:pygmentize) echo "python-pygments" ;;
	macos:pygmentize) echo "pygments" ;;
	opensuse:pygmentize) echo "python3-Pygments" ;; # capability: python313-Pygments provides it
	centos:pygmentize | fedora:pygmentize) echo "python3-pygments" ;;
	debian:pylsp | ubuntu:pylsp) echo "python3-pylsp" ;;
	# python-lsp-black: pylsp's black plugin (no binary — py:module probe).
	# Arch ships python-lsp-black under its own name; openSUSE prefixes the
	# PyPI name verbatim (python3-<pypi>); Fedora: not packaged (probe
	# drops it → the spec's pip fallback installs).
	debian:python-lsp-black | ubuntu:python-lsp-black) echo "python3-pylsp-black" ;;
	opensuse:python-lsp-black) echo "python3-python-lsp-black" ;;
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

# ────────────────── package index refresh ──────────────────
# Refresh before installing: a stale index is the usual cause of "Unable to
# locate package" on fresh machines. Retried, never fatal (dnf refreshes on
# demand, brew auto-updates). Guarded to one refresh per run — call freely.
PKG_DB_REFRESHED=0

refresh_pkg() {
	[ "$PKG_DB_REFRESHED" -eq 1 ] && return 0
	PKG_DB_REFRESHED=1
	case "$OS" in
	debian | ubuntu) retry -t "$RETRY_T_NET" -s "apt-get update" sudo_cmd apt-get update ;;
	arch)
		clear_stale_pacman_lock
		local rc=0
		retry -t "$RETRY_T_NET" -s "pacman -Sy" sudo_cmd pacman -Sy || rc=$?
		[ "$rc" -eq 124 ] && cleanup_timed_out_pacman
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
	# repoquery reads the REPO metadata only (installed state irrelevant,
	# which is why `dnf list available` was wrong: it omits installed
	# packages), and %{VERSION} carries no epoch prefix (`dnf list` shows
	# "1:22.23.2-1.el10", which breaks the X.Y normalization below).
	centos | fedora) ver=$(dnf -q repoquery --latest-limit=1 --qf '%{VERSION}' "$1" 2>/dev/null | head -1) ;;
	esac
	printf '%s' "$ver" | grep -oE '^[0-9]+\.[0-9]+' || true
}

# ────────────────── installs ──────────────────
# Low-level system install, used inside install_pkg and as the brew-failure
# fallback — returns non-zero when the OS is unknown, every name fails its
# probe, or the manager fails.
install_sys_pkg() {
	refresh_pkg
	# Names the official index does not know may still live in the AUR
	# (wlogout was dropped from [extra]) — set them aside for the AUR pass
	# below instead of losing them to the unknown-name warning.
	filter_pkgs_warn probe_pkg_name "$@"
	local -a aur_pkgs=()
	if [ "$OS" = arch ] && ((${#UNKNOWN_PKGS[@]} > 0)); then
		aur_pkgs=(${UNKNOWN_PKGS[@]+"${UNKNOWN_PKGS[@]}"})
	fi
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
		retry -t "$RETRY_T_NET" -s "apt-get install" sudo_cmd env DEBIAN_FRONTEND=noninteractive DEBIAN_PRIORITY=critical NEEDRESTART_MODE=a apt-get install -y -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold ${PKG_VALID[@]+"${PKG_VALID[@]}"}
		;;
	arch)
		clear_stale_pacman_lock
		local rc=0
		retry -t "$RETRY_T_NET" -s "pacman install" sudo_cmd pacman -S --noconfirm ${PKG_VALID[@]+"${PKG_VALID[@]}"} || rc=$?
		[ "$rc" -eq 124 ] && cleanup_timed_out_pacman
		# The official batch landed (or not) — the dropped names still get
		# their AUR pass; its failure does not undo the pacman result.
		((${#aur_pkgs[@]} > 0)) && install_aur_pkgs ${aur_pkgs[@]+"${aur_pkgs[@]}"}
		return "$rc"
		;;
	opensuse) retry -t "$RETRY_T_NET" -s "zypper install" sudo_cmd zypper --non-interactive install -y ${PKG_VALID[@]+"${PKG_VALID[@]}"} ;;
	centos)
		# Some tools (universal-ctags, global, fzf, bat, pygments) come from EPEL.
		sudo_cmd dnf install -y epel-release || true
		local -a _args=(${PKG_VALID[@]+"${PKG_VALID[@]}"})
		[[ " ${_args[*]} " =~ " global " ]] && _args+=(global-ctags)
		retry -t "$RETRY_T_NET" -s "dnf install" sudo_cmd dnf install -y "${_args[@]}"
		;;
	fedora)
		# No EPEL on Fedora — the names below ship in the base repos.
		# gtags needs the global-ctags subpackage (ctags back-end config),
		# same as CentOS; without it gtags is unusable.
		local -a _args=(${PKG_VALID[@]+"${PKG_VALID[@]}"})
		[[ " ${_args[*]} " =~ " global " ]] && _args+=(global-ctags)
		retry -t "$RETRY_T_NET" -s "dnf install" sudo_cmd dnf install -y "${_args[@]}"
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
	case "$(pkg_manager)" in
	apt) echo "dpkg" ;;
	pacman | zypper | dnf) echo "filesystem" ;;
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
	refresh_pkg
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
	if [ "$OS" = macos ]; then
		brew_install_retry "$RETRY_T_NET" "brew install build deps" ${names[@]+"${names[@]}"}
	else
		install_sys_pkg ${names[@]+"${names[@]}"}
	fi
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
	(cd "$dir" && retry -t "$RETRY_T_NET" -s "AUR $pkg build" makepkg -si --noconfirm) || rc=$?
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
	retry -t "$RETRY_T_NET" -s "pacman install base-devel git" sudo_cmd pacman -S --needed --noconfirm base-devel git || return 1
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
	filter_pkgs_warn probe_aur_name "$@"
	((${#PKG_VALID[@]} > 0)) || return 1
	local rc=0
	retry -t "$RETRY_T_NET" -s "AUR install" "$AUR_HELPER" -S --needed --noconfirm ${PKG_VALID[@]+"${PKG_VALID[@]}"} || rc=$?
	hash -r
	return "$rc"
}
