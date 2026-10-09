# monkey-scripts/lib/kmscon.sh — kmscon install & VT takeover.
#
# Sourced by scripts/install.sh (not by checkhealth.sh).
#
# Public entry point:
#   ensure_kmscon <tty[,tty...]>    e.g. ensure_kmscon tty2 / ensure_kmscon tty1,tty2
# Each ttyN in the list gets kmscon@ttyN enabled and getty@ttyN masked
# (mask, not disable: getty@tty2-6 are spawned by getty-static.service, which
# ignores per-instance disables). The bare getty is deliberately kept on
# every VT NOT in the list — the fbcon console is the last resort when the
# whole drm stack breaks — so a "full replacement" (tty1-6) is never
# implicit: the caller must list each VT.
#
# shellcheck shell=bash

KMSCON_DRM_PATH=/dev/dri
KMSCON_UNIT_PATH=/etc/systemd/system/kmscon@.service
KMSCON_PAM_PATH=/etc/pam.d/kmscon
KMSCON_UNIT_MARKER="managed by monkey-scripts (kmscon setup) v1"

# Default argument pre-parser for installers offering --with-kmscon
# [tty[,tty...]] (default tty2): consumes the flag BEFORE install_main sees
# the args (it fills _INSTALL_ARGS; the caller runs `parse_install_args "$@"`
# then `install_main "${_INSTALL_ARGS[@]}"`). Sets KMSCON_TTYS ("" = flag not
# given) and KMSCON_DONE. Projects with extra flags override this and
# delegate the leftover args themselves.
parse_install_args() {
	KMSCON_TTYS=""
	KMSCON_DONE=""
	local args=()
	while [ $# -gt 0 ]; do
		case "$1" in
		--with-kmscon)
			KMSCON_TTYS=tty2
			if [ $# -gt 1 ]; then
				case "$2" in
				--*) ;; # next flag: keep the tty2 default
				*) KMSCON_TTYS=$2
					shift ;;
				esac
			fi
			;;
		*) args+=("$1") ;;
		esac
		shift
	done
	_INSTALL_ARGS=("${args[@]+"${args[@]}"}")
}

# Parse "<tty[,tty...]>" or "<N,N>" into KMSCON_VTS (VT numbers). Returns 1
# on any malformed token (caller bug): the caller-listed set IS the
# replacement set, so a typo must not silently widen or narrow it — the
# caller decides whether to continue. The token form is restricted to
# ttyN/N, which also makes masking the getty@.service TEMPLATE (= every
# getty at once) impossible to express.
_kmscon_parse_ttys() {
	KMSCON_VTS=()
	local tok n
	local IFS=','
	for tok in $1; do
		case "$tok" in
		tty[0-9]*) n=${tok#tty} ;;
		[0-9]*) n=$tok ;;
		*)
			warn "ensure_kmscon: invalid tty '$tok' — expected ttyN (e.g. tty2) — skipping."
			return 1
			;;
		esac
		{ [ "$n" -ge 1 ] && [ "$n" -le 63 ]; } ||
			{
				warn "ensure_kmscon: tty$n out of range — the kernel supports tty1..tty63 (MAX_NR_CONSOLES) — skipping."
				return 1
			}
		# Normalize leading zeros (tty02 == tty2): the unit instance is the
		# plain number, so tty02 would enable a phantom kmscon@tty02.service
		# next to the real tty2 instance.
		n=$((10#$n))
		case " ${KMSCON_VTS[*]-} " in
		*" $n "*)
			warn "ensure_kmscon: tty$n listed twice — skipping."
			return 1
			;;
		esac
		KMSCON_VTS+=("$n")
	done
	[ ${#KMSCON_VTS[@]} -gt 0 ] ||
		{
			warn "ensure_kmscon: empty tty list — skipping."
			return 1
		}
}

# The --with-kmscon step inside a compositor's install_step_autostart: run
# the takeover when the flag was given (parse_install_args filled
# KMSCON_TTYS) and record success in KMSCON_DONE for the summary. The WSL /
# non-Linux / no-KMS guards live in ensure_kmscon itself (skip = success).
run_kmscon_setup() {
	[ -n "$KMSCON_TTYS" ] || return 0
	if ensure_kmscon "$KMSCON_TTYS"; then
		KMSCON_DONE=1
	else
		warn "kmscon setup failed — continuing without it."
	fi
}

ensure_kmscon() {
	[ -n "${1:-}" ] ||
		{
			warn "ensure_kmscon: missing tty list — usage: ensure_kmscon tty2 (or tty1,tty2,...) — skipping."
			return 1
		}
	# WSL reports uname -s = Linux and (with WSLg) even has /dev/dri, but
	# there is no VT login for kmscon to serve — skip before the checks that
	# would pass on a systemd-enabled WSL2.
	if is_wsl; then
		warn "WSL detected — skipping kmscon setup (no VT login)."
		return 0
	fi
	case "$(uname -s)" in
	Linux) ;;
	*)
		warn "kmscon is Linux-only — skipping."
		return 0
		;;
	esac
	if ! have_native_cmd systemctl; then
		warn "ensure_kmscon: systemctl not found — kmscon setup needs systemd — skipping."
		return 0
	fi
	if ! [ -d "$KMSCON_DRM_PATH" ]; then
		warn "ensure_kmscon: kmscon needs KMS/DRM but $KMSCON_DRM_PATH is missing (container/WSL/serial console?) — skipping."
		return 0
	fi
	_kmscon_parse_ttys "$1" || return 1
	_kmscon_dm_warning
	if ! have_native_cmd kmscon; then
		info "Installing kmscon..."
		if ! install_pkg "$(pkg_name kmscon)"; then
			warn "kmscon installation failed — install it manually: $(get_install_hint "$(pkg_name kmscon)") — skipping."
			return 0
		fi
		if ! have_native_cmd kmscon; then
			warn "ensure_kmscon: kmscon still missing after install — skipping."
			return 0
		fi
	fi
	_kmscon_write_unit
	_kmscon_write_pam
	local n
	for n in ${KMSCON_VTS[@]+"${KMSCON_VTS[@]}"}; do
		# set -e guard: a failed enable/mask is a warn, not an abort.
		sudo_cmd systemctl enable "kmscon@tty$n.service" ||
			warn "could not enable kmscon@tty$n.service — continuing."
		if [ "$n" -le 6 ]; then
			sudo_cmd systemctl mask "getty@tty$n.service" ||
				warn "could not mask getty@tty$n.service — continuing."
		else
			warn "tty$n: no default getty exists above tty6 — kmscon enabled, nothing masked."
		fi
	done
	local rc=0
	_kmscon_verify || rc=$?
	_kmscon_check_launch_gui
	local list=""
	for n in ${KMSCON_VTS[@]+"${KMSCON_VTS[@]}"}; do
		list="$list tty$n"
	done
	ok "kmscon enabled on:$list — getty masked on tty1-6 entries, bare getty kept everywhere else."
	return "$rc"
}

# Write $KMSCON_UNIT_PATH. Based on upstream v10.0.4 kmsconvt@.service.in
# with two deliberate changes: the Alias=autovt@.service line is dropped (the
# alias hands EVERY new VT to kmscon — implicit full replacement) and a
# marker comment is added (idempotency + ownership).
_kmscon_write_unit() {
	local unit="$KMSCON_UNIT_PATH"
	if [ -f "$unit" ] && sudo_cmd grep -qF "$KMSCON_UNIT_MARKER" "$unit"; then
		return 0 # already ours and current
	fi
	if [ -f "$unit" ]; then
		warn "$unit exists and is not ours — replacing it (a foreign Alias= line would hijack every VT)."
	fi
	sudo_cmd mkdir -p "$(dirname "$unit")"
	sudo_cmd tee "$unit" >/dev/null <<EOF
# $KMSCON_UNIT_MARKER
[Unit]
Description=KMS System Console on %I
Documentation=man:kmscon(1)
After=systemd-user-sessions.service
After=plymouth-quit-wait.service
After=rc-local.service
After=systemd-vconsole-setup.service
Before=getty.target
Conflicts=getty@%i.service
OnFailure=getty@%i.service
IgnoreOnIsolate=yes
ConditionPathExists=/dev/tty0

[Service]
User=root
PAMName=kmscon
ExecStart=kmscon --vt=%I --no-switchvt --term=kmscon
UtmpIdentifier=%I
TTYPath=/dev/%I
TTYReset=yes
TTYVHangup=yes
TTYVTDisallocate=yes

[Install]
WantedBy=getty.target
EOF
	sudo_cmd systemctl daemon-reload
}

# The kmscon package normally installs this; only fill the gap.
_kmscon_write_pam() {
	local p
	for p in /etc/pam.d/kmscon /usr/lib/pam.d/kmscon; do
		[ -f "$p" ] && return 0
	done
	sudo_cmd mkdir -p "$(dirname "$KMSCON_PAM_PATH")"
	sudo_cmd tee "$KMSCON_PAM_PATH" >/dev/null <<'EOF'
#%PAM-1.0

auth     required   pam_permit.so
account  required   pam_unix.so
session  required   pam_env.so
session  required   pam_unix.so
-session  optional  pam_systemd.so type=tty class=greeter
EOF
}

# Post-landing assertion (spec §5.1): the replacement set must be EXACTLY the
# requested list — every listed unit enabled (and masked for tty1-6), and
# nothing else touched. On mismatch: report + revert hint, rc 1.
_kmscon_verify() {
	local n got u rc=0
	for n in ${KMSCON_VTS[@]+"${KMSCON_VTS[@]}"}; do
		got=$(systemctl is-enabled "kmscon@tty$n.service" 2>/dev/null || true)
		# real systemd also reports enabled-runtime (and indirect) here —
		# everything enabled* is the requested state.
		case "$got" in
		enabled*) ;;
		*)
			warn "self-check: kmscon@tty$n is '${got:-unknown}', expected enabled."
			rc=1
			;;
		esac
		[ "$n" -le 6 ] || continue
		got=$(systemctl is-enabled "getty@tty$n.service" 2>/dev/null || true)
		if [ "$got" != "masked" ]; then
			warn "self-check: getty@tty$n is '${got:-not-installed}', expected masked — revert with: sudo systemctl unmask getty@tty$n.service"
			rc=1
		fi
	done
	for u in $(systemctl list-unit-files 'kmscon@*.service' --no-legend 2>/dev/null | awk '$2 == "enabled" {print $1}'); do
		n=${u#kmscon@tty}
		n=${n%.service}
		case " ${KMSCON_VTS[*]-} " in
		*" $n "*) ;;
		*) warn "self-check: unexpected enabled unit $u — revert with: sudo systemctl disable $u" && rc=1 ;;
		esac
	done
	for u in $(systemctl list-unit-files 'getty@*.service' --no-legend 2>/dev/null | awk '$2 == "masked" {print $1}'); do
		n=${u#getty@tty}
		n=${n%.service}
		case " ${KMSCON_VTS[*]-} " in
		*" $n "*)
			# The lib never masks above tty6, so a masked getty there is drift.
			if [ "$n" -gt 6 ]; then
				warn "self-check: unexpected masked unit $u — revert with: sudo systemctl unmask $u"
				rc=1
			fi
			;;
		*) warn "self-check: unexpected masked unit $u — revert with: sudo systemctl unmask $u" && rc=1 ;;
		esac
	done
	return "$rc"
}

# Advisory only — picking a free VT is the caller's job; this catches the
# most common mistake (kmscon tty1 next to an enabled display manager,
# whose default seat VT is tty1 for sddm/lightdm/xdm/greetd/ly and
# dynamic-first-free for gdm). display-manager.service is the generic alias
# most distros point at the installed DM; greetd/ly are common on
# Wayland-minimal setups and are usually enabled under their own name.
_kmscon_dm_warning() {
	local dm
	for dm in display-manager sddm gdm gdm3 lightdm lxdm xdm greetd ly slim nodm entrance; do
		systemctl is-enabled "$dm.service" >/dev/null 2>&1 || continue
		case " ${KMSCON_VTS[*]-} " in
		*" 1 "*) warn "display manager '$dm' is enabled and owns tty1 — kmscon on tty1 will fight it for the VT." ;;
		esac
		return 0
	done
}

# kmscon-launch-gui ships in distro kmscon packages (>= 10.0.0); only verify
# presence — a missing script is not fatal because the profile block skips
# GUI autostart when it is absent.
_kmscon_check_launch_gui() {
	have_native_cmd kmscon-launch-gui && {
		ok "kmscon-launch-gui available."
		return 0
	}
	warn "kmscon-launch-gui not found — kmscon sessions will skip GUI autostart (install a kmscon package that ships it)."
	return 0
}
