# monkey-scripts/lib/retry.sh — retry with exponential backoff + per-attempt
# timeout. Sourced by lib/bootstrap.sh (both entry points).

# Standard per-attempt timeouts (-t) used by every retried call across lib/.
# A call that legitimately runs long picks the next tier up instead of a
# bespoke number.
RETRY_T_NET=1800   # ordinary network operations (downloads, git, installs)
RETRY_T_HEAVY=3600 # long-but-finite operations (full system upgrade, rustup toolchain)
RETRY_T_HUGE=7200  # installs that pull LLVM/.NET as formula dependencies (zig, zls, marksman)

# ────────────────────── nested-retry guard ──────────────────────
# Exported: the nesting crosses a PROCESS boundary (run_checkhealth retries
# `bash checkhealth.sh --install`, whose child re-enters retry). While any
# outer retry is active (count > 0), an inner retry runs its command ONCE —
# the outer loop already bounds the attempts.
RETRY_ACTIVE_COUNT=${RETRY_ACTIVE_COUNT:-0}
export RETRY_ACTIVE_COUNT

# Per-attempt timeout binary: GNU timeout, gtimeout on macOS, empty = run
# unguarded (a silent hang is recoverable by hand; a broken run is not).
if command -v timeout >/dev/null 2>&1; then
	TIMEOUT_BIN=timeout
elif command -v gtimeout >/dev/null 2>&1; then
	TIMEOUT_BIN=gtimeout
else
	TIMEOUT_BIN=""
fi

# Kill-after grace: SIGTERM alone can be ignored (pacman mid-write, brew's
# ruby) and would hang the timeout forever. Unset defaults to 30s; EMPTY
# disables the escalation (-k omitted entirely).
RETRY_KILL_AFTER=${RETRY_KILL_AFTER-30}

# retry's execution helper. $1 = timeout seconds ("0" disables), rest =
# command. timeout(1) can only exec binaries, so a function-first command
# re-enters through a child bash with the function (and its helpers)
# exported; everything else goes to the timeout binary directly.
_retry_run() {
	local t="$1"
	shift
	if [ -z "$TIMEOUT_BIN" ] || [ "$t" -eq 0 ]; then
		"$@"
		return
	fi
	local -a ka=()
	# -k only when configured: `-k ""` is rejected with rc 125.
	if [ -n "$RETRY_KILL_AFTER" ]; then
		ka=(-k "$RETRY_KILL_AFTER")
	fi
	if declare -F "$1" >/dev/null 2>&1; then
		local fn
		# The whitelist must carry the WHOLE dependency closure of the
		# wrapped command (sudo_cmd -> native_sudo -> have_native_cmd ->
		# native_bin_path -> is_wsl): one missing link made every exported
		# call die with "command not found" in the child.
		for fn in "$1" retry _retry_run native_sudo have_native_cmd native_bin_path is_wsl warn; do
			declare -F "$fn" >/dev/null 2>&1 && export -f "$fn"
		done
		"$TIMEOUT_BIN" ${ka[@]+"${ka[@]}"} "$t" bash -c '"$@"' _ "$@"
	else
		"$TIMEOUT_BIN" ${ka[@]+"${ka[@]}"} "$t" "$@"
	fi
}

# ──────────────────────────── retry ────────────────────────────
# Retry wrapper for every network-flavoured command (downloads, git, package
# managers): exponential backoff (15s→30s→60s→120s) plus a per-attempt
# timeout — a black-holed connection would otherwise hang the installer
# forever. rc 124 is timeout's own exit code.
#
# Usage: retry [-n attempts] [-d base_delay] [-m max_delay] [-t timeout]
#              [-s desc] cmd...
#   -n  total attempts, NOT retries (default 5)
#   -d  first sleep in seconds (default 15)
#   -m  sleep cap in seconds (default 120)
#   -t  per-attempt timeout in seconds (default 600; 0 disables) — pass a
#       larger value for legitimately long operations (package installs,
#       big clones)
#   -s  human description for the warning line (default: the command)
# Returns the command's last exit code (124 = timed out). Safe under set -e;
# cmd's own flags are untouched — getopts stops at the first non-option
# word, so only the leading -n/-d/-m/-t/-s belong to retry.
retry() {
	local attempts=5 base=15 max=120 timeout_s=600 desc=""
	local opt
	# A leading -- may guard a wrapped command that itself starts with an
	# option-looking word; strip it BEFORE parsing.
	[ "${1:-}" = "--" ] && shift
	# OPTIND=1: getopts resumes at $OPTIND on the next call in the same
	# shell — without the reset a second retry() call misparses.
	OPTIND=1
	while getopts ":n:d:m:t:s:" opt "$@"; do
		case "$opt" in
		n) attempts=$OPTARG ;;
		d) base=$OPTARG ;;
		m) max=$OPTARG ;;
		t) timeout_s=$OPTARG ;;
		s) desc=$OPTARG ;;
		*) return 2 ;;
		esac
	done
	shift $((OPTIND - 1))
	[ $# -gt 0 ] || return 2
	# Nested call (see RETRY_ACTIVE_COUNT): run once, no sleeps.
	if [ "$RETRY_ACTIVE_COUNT" -gt 0 ]; then
		if _retry_run "$timeout_s" "$@"; then
			return 0
		else
			return "$?"
		fi
	fi
	RETRY_ACTIVE_COUNT=$((RETRY_ACTIVE_COUNT + 1))
	local attempt rc=1 wait_s
	for ((attempt = 1; attempt <= attempts; attempt++)); do
		if _retry_run "$timeout_s" "$@"; then
			RETRY_ACTIVE_COUNT=$((RETRY_ACTIVE_COUNT - 1))
			return 0
		else
			# Inside the else, $? is still the wrapped command's status.
			rc=$?
		fi
		if [ "$attempt" -lt "$attempts" ]; then
			wait_s=$base
			[ "$wait_s" -gt "$max" ] && wait_s=$max
			if [ "$rc" -eq 124 ] && [ -n "$TIMEOUT_BIN" ] && [ "$timeout_s" -gt 0 ]; then
				warn "${desc:-$1} timed out after ${timeout_s}s (attempt $attempt/$attempts) — retrying in ${wait_s}s..."
			else
				warn "${desc:-$1} failed (attempt $attempt/$attempts) — retrying in ${wait_s}s..."
			fi
			sleep "$wait_s"
			base=$((base * 2))
		fi
	done
	RETRY_ACTIVE_COUNT=$((RETRY_ACTIVE_COUNT - 1))
	return "$rc"
}
