# monkey-scripts/lib/tty.sh — TIOCSTI injection into the controlling
# terminal. Sourced by lib/bootstrap.sh (both entry points); the only
# consumer is output.sh's finish_install.

# ────────────────────── TIOCSTI injection ──────────────────────
# Type <cmd> + newline into the controlling terminal: the parent shell
# executes it after this script (and any wrapper chaining it) has fully
# exited, so injection can never disturb the run itself.
#   Linux: kernel 6.2+ gates TIOCSTI behind CAP_SYS_ADMIN (CONFIG_LEGACY_
#     TIOCSTI off — WSL2 ships it off), so the injection always runs under
#     sudo (silent under the NOPASSWD drop-in). The TARGET tty is resolved
#     by path (TIOCSTI_TTY), never /dev/tty: sudo >= 1.9.14 (use_pty) runs
#     the command in its own pty, and bytes injected into /dev/tty there
#     die with sudo — rc 0 regardless, which is how the silent no-op
#     slipped past every check (the bug the TIOCSTI_TTY plumbing fixes).
#   macOS: TIOCSTI exists and no kernel gate applies — verified injection
#     succeeding on an unsandboxed PTY (codex#45119); sandboxed/Seatbelt
#     contexts deny it with EPERM (surfaced as a failure). Plain run —
#     sudo would only add a password prompt.
# python3 first, perl as fallback, plain error when both are missing.

# ────────────────────── interactive-reader guard ──────────────────────
# A succeeding ioctl only proves the bytes entered the tty input queue —
# someone must READ it afterwards. Without an interactive shell behind the
# terminal (SSH one-shots, piped harness runs) the pty dies and the queued
# command evaporates while the log says OK (observed on an openSUSE
# Tumbleweed VM run, 2026-10). The guard walks the ancestor chain for an
# interactive shell whose fd 0 is our controlling tty, and refuses to
# inject without one. `ps` is the single source of truth on every platform
# (`args=` / `ppid=`; -ww disables width truncation).

_is_interactive_shell() {
	# Interactive = argv0 is a shell and every remaining argument is a pure
	# option flag (`zsh -i` sits at a prompt; `zsh -c cmd` never does).
	# Known limit: ps flattens quoting, so a flag with a SEPARATE value word
	# (zsh -o SOMETHING) reads as a positional — real interactive shells are
	# launched bare, so this never bites in practice.
	local -a words
	# Plain heredoc, NOT a herestring (`<<<`): legacy sh.vim (nvim/vim
	# without tree-sitter for sh) parses `<<<` as a heredoc BEGIN whose
	# delimiter never matches, rendering EVERY following line as one
	# unterminated heredoc (observed: the rest of this file highlighted as
	# shHereDoc, 2026-10). `read -a` splits on IFS whitespace identically.
	local ps_out
	ps_out=$(ps -ww -o args= -p "$1" 2>/dev/null)
	read -r -a words <<EOF
$ps_out
EOF
	((${#words[@]} > 0)) || return 1
	local prog="${words[0]##*/}" a
	prog="${prog#-}" # login shells carry a leading dash ("-zsh")
	case "$prog" in
	zsh | bash | sh | dash | ksh | mksh | fish | csh | tcsh) ;;
	*) return 1 ;;
	esac
	for a in "${words[@]:1}"; do
		case "$a" in
		-c | --command | --eval) return 1 ;;
		--) return 1 ;;
		-*) ;;         # pure flag (-i, -l, --norc, ...)
		*) return 1 ;; # positional: a script file or inline command
		esac
	done
	return 0
}

# _stdin_tty_of <pid> — what <pid> has open on fd 0, empty when unknown.
# lsof covers macOS too; Linux falls back to a /proc readlink.
_stdin_tty_of() {
	if command -v lsof >/dev/null 2>&1; then
		lsof -a -p "$1" -d 0 -Fn 2>/dev/null | sed -n 's/^n//p' | head -n 1
	elif [ -d "/proc/$1" ]; then
		readlink "/proc/$1/fd/0" 2>/dev/null
	fi
}

_has_interactive_reader() {
	# Block only on POSITIVE knowledge; any ps trouble means "cannot judge"
	# — inject as before.
	command -v ps >/dev/null 2>&1 || return 0
	local my_tty pid ppid fd0 n=0
	# Our controlling tty, exported as TIOCSTI_TTY: inject_tty must NOT
	# reopen /dev/tty under sudo — sudo >= 1.9.14 (use_pty) gives the child
	# a private pty, and bytes injected there die with sudo.
	my_tty=$(ps -o tty= -p "$$" 2>/dev/null)
	my_tty="${my_tty//[[:space:]]/}"
	TIOCSTI_TTY=""
	[ -n "$my_tty" ] && TIOCSTI_TTY="/dev/$my_tty"
	pid=$$
	while [ "$pid" -gt 1 ] && [ "$n" -lt 25 ]; do
		if _is_interactive_shell "$pid"; then
			# ...AND it must actually read the terminal: an interactive-
			# LOOKING shell with a pipe on fd 0 (`zsh -i < feeder`) never
			# consumes the tty queue — the false positive that logged
			# "injected (via sudo)" while nothing executed. An empty
			# _stdin_tty_of answer (dead/foreign PID) just fails the match.
			fd0=$(_stdin_tty_of "$pid")
			if [ -n "$my_tty" ] && { [ "$fd0" = "/dev/$my_tty" ] || [ "$fd0" = "/dev/tty" ]; }; then
				return 0
			fi
		fi
		ppid=$(ps -o ppid= -p "$pid" 2>/dev/null) || return 0
		ppid="${ppid//[!0-9]/}"
		[ -n "$ppid" ] || return 0
		pid=$ppid
		n=$((n + 1))
	done
	return 1
}

inject_tty() {
	local cmd="$1" err py3 perlx tiocsti=0x5412 label=""
	[ -n "$cmd" ] || return 1
	# Reader guard first: without a consumer the injection is a silent
	# no-op, however many ioctls "succeed".
	if ! _has_interactive_reader; then
		warn "no interactive shell is attached to this terminal — skipping injection; run: $cmd"
		return 1
	fi
	# No writable controlling terminal (CI, nested pipes).
	if ! [ -w /dev/tty ]; then
		warn "inject_tty: /dev/tty is not writable — no controlling terminal to inject into."
		return 1
	fi
	py3=$(command -v python3 2>/dev/null)
	perlx=$(command -v perl 2>/dev/null)
	# One implementation, two platforms — only the prefix (sudo_cmd on
	# Linux) and the perl constant differ. The TARGET is TIOCSTI_TTY, never
	# /dev/tty under sudo (see _has_interactive_reader).
	local target="${TIOCSTI_TTY:-/dev/tty}"
	local -a runner=()
	if [ "$(uname -s)" != Darwin ] && have_native_cmd sudo; then
		runner=(sudo_cmd)
		label=" (via sudo)"
	fi
	[ "$(uname -s)" = Darwin ] && tiocsti=0x80017472
	if [ -n "$py3" ]; then
		# termios.TIOCSTI carries the per-platform constant automatically.
		if err=$(${runner[@]+"${runner[@]}"} "$py3" -c 'import sys,os,fcntl,termios
cmd = sys.argv[1] + "\n"
fd = os.open(sys.argv[2], os.O_WRONLY)
for b in cmd.encode():
    buf = bytearray(1); buf[0] = b
    fcntl.ioctl(fd, termios.TIOCSTI, buf)' "$cmd" "$target" 2>&1); then
			ok "injected via python3${label}."
			return 0
		fi
	fi
	if [ -n "$perlx" ]; then
		if err=$(${runner[@]+"${runner[@]}"} "$perlx" -e '
			my ($cmd, $tio, $tty_path) = @ARGV;
			open(my $tty, ">", $tty_path) or die "open $tty_path: $!\n";
			for my $ch (split //, $cmd . "\n") {
				ioctl($tty, hex($tio), $ch) or die "TIOCSTI ioctl failed: $!\n";
			}
		' "$cmd" "$tiocsti" "$target" 2>&1); then
			ok "injected via perl${label}."
			return 0
		fi
	fi
	warn "inject_tty failed: ${err:-python3/perl not found}"
	return 1
}
