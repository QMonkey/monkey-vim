# monkey-scripts/lib/sudo.sh — one password entry per run, no keepalive.
# Sourced by scripts/install.sh and scripts/checkhealth.sh.

SUDOERS_D_DIR="${SUDOERS_D_DIR:-/etc/sudoers.d}"
SUDO_BIN=""
# The only sudo state: the grant this process created, empty if it created
# none. Riding and owning are decided once, when setup_sudo asks root about
# the path — the file is named per project (zz-<PROJECT>-nopasswd), so a
# chained child of the same project inherits its parent's file and must not
# delete it mid-run, while a stage that finds nothing usable creates one and
# then owes its removal.
# "Did I authenticate?" and "is NOPASSWD in force?" need no flags: the first is
# invisible to anything downstream and the second is answered by probing sudo
# itself, so both used to be write-only variables that gated cleanup wrongly.
SUDO_DROPIN_FILE=""

# The drop-in name is derived from the project — lazily, because PROJECT is
# set by the project script AFTER it sources this entry point.
nopasswd_dropin_path() {
	printf '%s' "$SUDOERS_D_DIR/zz-${PROJECT:-monkey}-nopasswd"
}

cleanup_sudo() {
	# Removes only what THIS process wrote, and clears the marker before
	# acting: main() may call this explicitly and the EXIT trap calls it
	# again, so the second pass has to be a no-op rather than a warning
	# about an already-deleted grant.
	[ -n "$SUDO_DROPIN_FILE" ] || return 0
	local _dropin="$SUDO_DROPIN_FILE"
	SUDO_DROPIN_FILE=""
	if [ -n "$SUDO_BIN" ] && "$SUDO_BIN" -n rm -f "$_dropin" 2>/dev/null; then
		return 0
	fi
	warn "could not remove the NOPASSWD drop-in — remove it manually: sudo rm $_dropin"
}

# Pre-authenticate once, then grant NOPASSWD for the rest of the run.
# SUDO_DROPIN=0 skips the drop-in: the `sudo -v` below is the only
# authentication and the run rides the sudo timestamp instead. Honest
# limits of that mode: brew resets the timestamp on every invocation and
# long runs can outlive it — and a re-auth needed INSIDE a retried command
# cannot prompt (the retry child sits in a non-foreground process group, a
# tty read stops on SIGTTIN), so sudo_cmd fails the attempt instead of
# hanging. The drop-in stays the default because it has no expiry window.
#
# Probe first (`-n true`, a command): when credentials are already valid —
# this run's own drop-in from a previous stage, or an outer installer's
# grant — skip authentication entirely; chained stages never re-prompt.
# Failure means no valid grant exists and `sudo -v` prompts for the one
# password of the run.
#
# Why the drop-in is NOPASSWD: authentication is granted by the rule itself
# and the timestamp is never consulted, so brew's --reset-timestamp, clock
# jumps and plain expiry are all harmless. GNU sudo resolves conflicting
# rules last-match-wins, so this drop-in (parsed after the distro's
# password-required rule) always wins. sudo-rs would defeat this tag for
# VALIDATE (max_by_key picks the password-required rule) — but every sudo in
# these scripts is a command or the probe, where NOPASSWD wins on both
# implementations.
#
# No sudo keepalive: with the drop-in in place the timestamp is never read,
# so there is nothing to keep alive — and no helper could re-authenticate for
# us inside WSL/containers anyway. The failure mode of a missing drop-in is
# covered by sudo_cmd's lazy re-auth below — do not reintroduce it.
setup_sudo() {
	SUDO_BIN=$(native_sudo) || return 0
	if [ "$(id -u)" -eq 0 ]; then
		return 0
	fi
	# Ride or create. A grant that already exists AND parses covers every sudo
	# this process will run — it came from an outer stage of the same project
	# (chained stages share the path) or from an earlier run — so nothing is
	# created here and cleanup stays out of what someone else is using. A file
	# sudo will not parse, or none at all, is taken over below: written again,
	# owned, removed on exit.
	# Both halves are answered from root's side of the wall: /etc/sudoers.d is
	# 0750 root:root, so a userland [ -e ] cannot resolve any name inside it
	# (EACCES reads as "missing") — under that test every chained stage
	# "created" the shared project file, took ownership of it and deleted it at
	# exit while its parent still needed it. `sudo -n test -e` stats as root;
	# the timestamp is then dropped and re-probed because only a rule that
	# parses can answer without credentials — a cached ticket must not
	# masquerade as a durable grant.
	if "$SUDO_BIN" -n test -e "$(nopasswd_dropin_path)" 2>/dev/null; then
		"$SUDO_BIN" -k 2>/dev/null
		if "$SUDO_BIN" -n true 2>/dev/null; then
			return 0
		fi
	fi
	if ! "$SUDO_BIN" -n true 2>/dev/null; then
		if ! "$SUDO_BIN" -v 2>/dev/null; then
			# No tty / no sudo rule: degrade to a warning — user-level
			# installs still work; privileged steps fail individually via
			# sudo_cmd and are collected by the caller's reporting.
			warn "sudo authorization failed — continuing without root; privileged steps (system packages) will be reported as failures."
		fi
	fi
	# SUDO_DROPIN=0: timestamp-only mode — the password above was the only
	# prompt, no drop-in is installed and there is nothing to clean up.
	[ "${SUDO_DROPIN:-1}" = "1" ] || return 0
	# Armed before the file exists: every path from here that can leave a
	# grant on disk must also be able to take it away, including a failure
	# between the write and the verification below.
	trap cleanup_sudo EXIT
	trap 'exit 130' INT
	trap 'exit 143' TERM
	if printf '%s ALL=(ALL) NOPASSWD: ALL\n' "$(id -un)" |
		"$SUDO_BIN" -n sh -c 'umask 077; cat >"$1" && chmod 0440 "$1" && visudo -c -f "$1" >/dev/null 2>&1 || { rm -f "$1"; exit 1; }' sh "$(nopasswd_dropin_path)" >/dev/null 2>&1; then
		SUDO_DROPIN_FILE="$(nopasswd_dropin_path)"
		# A written, visudo-clean drop-in is not necessarily PARSED: a sudoers
		# missing the @includedir line never loads it, and a sudo whose rule
		# matching disfavors the tag defeats it. Unverified, the run then
		# silently rides the pre-auth timestamp and collapses when it expires
		# mid-run. So discard the timestamp FIRST (-k needs no password) and probe — a
		# success now can only come from the rule itself.
		"$SUDO_BIN" -k 2>/dev/null
		if "$SUDO_BIN" -n true 2>/dev/null; then
			ok "Temporary NOPASSWD drop-in installed for this run (auto-removed on exit)."
		else
			# Inert right now, but it becomes a live NOPASSWD grant the moment
			# sudoers grows an @includedir line — withdraw it immediately.
			cleanup_sudo
			warn "NOPASSWD drop-in is not effective (sudo ignores $SUDOERS_D_DIR?) — removed the file and fell back to timestamp-only mode; long runs may still need one re-authentication."
			# -k above destroyed the ticket the probe/-v may have created —
			# restore it, or the run is dead on arrival. Foreground here, so
			# prompting is safe (the SIGTTIN freeze only applies inside retried commands).
			"$SUDO_BIN" -v -p "[${PROJECT:-monkey}] sudo password (drop-in not effective): " ||
				warn "could not re-authenticate — privileged steps will fail until you re-run with 'sudo -v' done first."
		fi
	else
		# The pipeline deletes the file itself when visudo -c rejects it, but
		# that cleanup runs as root inside sudo — confirm from here that no
		# grant survived a failed write.
		SUDO_DROPIN_FILE="$(nopasswd_dropin_path)"
		cleanup_sudo
		warn "could not install the temporary NOPASSWD drop-in — each privileged step will ask for the password separately."
	fi
}

# SUDO_DROPIN default for a --install run; an explicit value always wins.
#   chained (INSTALL_CHAIN, set by run_checkhealth) → keep the drop-in: the
#     installer's own setup_sudo has already granted, and long chained runs
#     must not trip the timestamp expiry;
#   manual run → timestamp-only: ONE password up front, no drop-in (an
#     expired mid-run re-auth fails the attempt fast instead of prompting —
#     see sudo_cmd).
resolve_sudo_dropin() {
	[ -n "${SUDO_DROPIN:-}" ] && return 0
	if [ -n "${INSTALL_CHAIN:-}" ]; then
		SUDO_DROPIN=1
	else
		SUDO_DROPIN=0
	fi
}

sudo_cmd() {
	# Lazy re-auth: Homebrew resets the sudo timestamp on EVERY invocation
	# (brew.sh runs `sudo --reset-timestamp` at startup), so a ticket that was
	# valid a minute ago can be dead here — and when the NOPASSWD drop-in
	# failed to install there is no ticket at all. Re-authenticate proactively
	# with an explanatory prompt instead of letting the command fail or
	# springing a context-free password prompt. `-n true` never prompts; the
	# interactive `-v` only runs when the ticket is actually gone.
	local sudo_bin
	sudo_bin=$(native_sudo) || {
		"$@"
		return
	}
	if ! "$sudo_bin" -n true 2>/dev/null; then
		# A prompt inside a retried command hangs: retry runs its child under
		# timeout, in a NON-foreground process group, so the tty read is
		# stopped by SIGTTIN and ^C never reaches it. Fail the attempt instead
		# and let the retry loop report it. Reachable only without the
		# drop-in (SUDO_DROPIN=0, or an install that failed) once the
		# timestamp has expired.
		if [ "${RETRY_ACTIVE_COUNT:-0}" -gt 0 ]; then
			warn "sudo credentials expired inside a retried command — cannot prompt here (no NOPASSWD drop-in). Re-authenticate with 'sudo -v' and re-run."
			return 1
		fi
		"$sudo_bin" -v -p "[${PROJECT:-monkey}] sudo credentials needed to continue — enter your password: " || return 1
	fi
	"$sudo_bin" "$@"
}
