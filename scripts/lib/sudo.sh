# monkey-scripts/lib/sudo.sh — one password entry per run, no keepalive.
# Sourced by scripts/install.sh and scripts/checkhealth.sh.

SUDOERS_D_DIR="${SUDOERS_D_DIR:-/etc/sudoers.d}"
SUDO_NOPASSWD=0
SUDO_BIN=""

# The drop-in name is derived from the project — lazily, because PROJECT is
# set by the project script AFTER it sources this entry point.
nopasswd_dropin_path() {
	printf '%s' "$SUDOERS_D_DIR/zz-${PROJECT:-monkey}-nopasswd"
}

cleanup_sudo() {
	# Flag cleared BEFORE acting: main() calls this explicitly and the EXIT
	# trap calls it again on the way out. The second pass must be a no-op —
	# once the grant file is gone, `sudo -n rm` can no longer authenticate
	# (no timestamp is ever recorded because every sudo during the run was
	# NOPASSWD), and it would warn even though the file was already removed.
	if [ "$SUDO_NOPASSWD" -eq 1 ] && [ -n "$SUDO_BIN" ]; then
		SUDO_NOPASSWD=0
		"$SUDO_BIN" -n rm -f "$(nopasswd_dropin_path)" 2>/dev/null ||
			warn "could not remove the NOPASSWD drop-in — remove it manually: sudo rm $(nopasswd_dropin_path)"
	fi
}

# Pre-authenticate once, then grant NOPASSWD for the rest of the run.
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
# so there is nothing to keep alive. The old background refresh loop also
# leaked a process per run and never worked inside WSL/containers where no
# helper can re-authenticate for us. The failure mode of a missing drop-in
# is covered by sudo_cmd's lazy re-auth below — do not reintroduce it.
setup_sudo() {
	SUDO_BIN=$(native_sudo) || return 0
	if [ "$(id -u)" -eq 0 ]; then
		return 0
	fi
	if ! "$SUDO_BIN" -n true 2>/dev/null; then
		"$SUDO_BIN" -v || die "sudo authorization failed — run this script in an interactive terminal."
	fi
	if printf '%s ALL=(ALL) NOPASSWD: ALL\n' "$(id -un)" |
		"$SUDO_BIN" -n sh -c 'umask 077; cat >"$1" && chmod 0440 "$1" && visudo -c -f "$1" >/dev/null 2>&1 || { rm -f "$1"; exit 1; }' sh "$(nopasswd_dropin_path)" >/dev/null 2>&1; then
		SUDO_NOPASSWD=1
		ok "Temporary NOPASSWD drop-in installed for this run (auto-removed on exit)."
	else
		warn "could not install the temporary NOPASSWD drop-in — each privileged step will ask for the password separately."
	fi
	trap cleanup_sudo EXIT
	trap 'exit 130' INT
	trap 'exit 143' TERM
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
		"$sudo_bin" -v -p "[${PROJECT:-monkey}] sudo credentials needed to continue — enter your password: " || return 1
	fi
	"$sudo_bin" "$@"
}
