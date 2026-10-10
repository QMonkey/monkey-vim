# shellcheck shell=bash
# monkey-scripts/lib/env.sh — PATH seeding / persistence, shell env-file
# infrastructure, compositor autostart. Sourced by scripts/install.sh and
# scripts/checkhealth.sh (BEFORE clone.sh and checks.sh, which rely on
# export_path mid-run).
#
#   bin_dirs / export_path / persist_path — the framework bin-dir set: one
#       source of truth emitting idempotent PATH-update lines
#   export_path_pre_win / persist_brew_path — Homebrew's POSITIONAL insert
#       (not part of persist_path; runs even when PERSIST_PATH=0)
#   write_tty_autostart / autostart_block — guarded compositor exec block
#   shell_env_files / append_env_block — which profile files exist and how
#       blocks land in them

# Homebrew prefixes: the single source of truth. install_linuxbrew probes
# these to adopt an existing install; export_path seeds each real prefix's
# bin dir as the brew PATH tier. /usr/local/bin stays out of the tier: a
# system path the default PATH already carries (see bin_dirs).
BREW_PREFIXES="/home/linuxbrew/.linuxbrew /opt/homebrew /usr/local"

# ────────────────────── shell env files ──────────────────────
shell_env_files() {
	# The TARGET login shell decides WHICH profile files: zsh → ~/.zprofile;
	# bash → ~/.bash_profile (or ~/.profile) + ~/.bashrc. Falls back to
	# $SHELL, then bash (macOS has no getent; its $SHELL already reflects
	# the login shell).
	local shell_bin
	# No getent on macOS — guard the call (a bare 127 would trip set -e
	# before the dscl fallback below ever runs).
	if have_native_cmd getent; then
		shell_bin=$(getent passwd "$(id -un)" 2>/dev/null | cut -d: -f7)
	fi
	if [ -z "$shell_bin" ] && [ "$(uname -s)" = Darwin ]; then
		# $SHELL is a login-time snapshot and goes stale right after a chsh.
		shell_bin=$(dscl . -read /Users/"$(id -un)" UserShell 2>/dev/null | awk '{print $2}')
	fi
	shell_bin=${shell_bin:-${SHELL:-bash}}
	shell_bin=${shell_bin##*/}
	case "$shell_bin" in
	zsh)
		printf '%s\n' "$HOME/.zprofile"
		;;
	bash)
		if [ -f "$HOME/.bash_profile" ]; then
			printf '%s\n' "$HOME/.bash_profile"
		else
			printf '%s\n' "$HOME/.profile"
		fi
		printf '%s\n' "$HOME/.bashrc"
		;;
	*)
		printf '%s\n' "$HOME/.profile"
		;;
	esac
}

# Files the LAST append_env_block call touched/verified. Shared channel:
# read it IMMEDIATELY after your own append_env_block call
# (write_tty_autostart does) — any later call overwrites it.
ENV_BLOCK_FILES=""

append_env_block() {
	# Usage: append_env_block <marker> <block>
	# Appends <block> guarded by <marker> to every shell env file, once.
	# The touched files are collected in ENV_BLOCK_FILES (callers that need
	# bookkeeping — e.g. write_tty_autostart's AUTOSTART_FILES — read it).
	local marker="$1"
	local block="$2"
	local f
	ENV_BLOCK_FILES=""
	while IFS= read -r f; do
		[ -n "$f" ] || continue
		[ -f "$f" ] || touch "$f"
		if ! grep -qF -- "$marker" "$f" 2>/dev/null; then
			printf '\n# %s\n%b\n' "$marker" "$block" >>"$f"
			ok "Added '$marker' to $f"
		fi
		ENV_BLOCK_FILES="$ENV_BLOCK_FILES $f"
	done < <(shell_env_files)
}

# ────────────────────── compositor autostart (guarded VT login) ──────────────────────
# autostart_block — the guarded exec block. POSIX sh: it lands in
# ~/.profile too, which display managers may source with a minimal shell.
# Guards, cheapest first (desktop terminals / tmux panes short-circuit with
# zero forks):
#   1. $WAYLAND_DISPLAY / $DISPLAY both unset
#   2. stdin is a real VT (/dev/ttyN) — excludes ssh, tmux panes, desktop
#      terminals (their stdin stays a pty even when the tmux server was
#      VT-started)
#   3. no <proc> running — single-instance policy: other VT logins fall
#      through to a plain shell instead of a second compositor
#   4. kmscon session (TERM=kmscon, the kmscon >= 10.0.0 default) → wrap
#      the compositor in kmscon-launch-gui (backgrounds the terminal, lets
#      the compositor take DRM master, restores kmscon). TERM is the ONLY
#      detection: pre-10.0.0 builds lack the OSC handoff the wrapper needs.
autostart_block() {
	local exec_cmd="$1" pgrep_name="$2"
	# NOTE: no marker line of its own — append_env_block writes it.
	cat <<EOF
# Keep this block ABOVE any "exec tmux" auto-start block: on a bare TTY
# exec replaces the login shell with the compositor, so the tmux
# auto-start line is never reached and the desktop never runs inside a
# tmux pane. Inside a desktop terminal the env guards short-circuit and
# the tmux auto-start runs normally.
if [ -z "\${WAYLAND_DISPLAY:-}" ] && [ -z "\${DISPLAY:-}" ]; then
    case "\$(tty 2>/dev/null)" in
    /dev/tty[0-9]*)
        if pgrep -x $pgrep_name >/dev/null 2>&1; then
            : # single instance: the compositor already owns a session
        elif [ "\${TERM:-}" = kmscon ]; then
            if command -v kmscon-launch-gui >/dev/null 2>&1; then
                exec kmscon-launch-gui $exec_cmd
            else
                echo "kmscon session: kmscon-launch-gui not found — start $exec_cmd manually." >&2
            fi
        else
            exec $exec_cmd
        fi
        ;;
    esac
fi
EOF
}

# write_tty_autostart <exec_cmd> <pgrep_name> — append the guarded block to
# every shell env file (marker-guarded, via append_env_block) and record
# the touched files in AUTOSTART_FILES for the summary. WSL has no VT login
# — the block would be dead code there; WSLg renders single GUI apps
# without a compositor.
write_tty_autostart() {
	local exec_cmd="$1" pgrep_name="$2"
	if is_wsl; then
		info "WSL detected — skipping autostart setup (no VT login; WSLg covers GUI apps)."
		return 0
	fi
	append_env_block "$PROJECT autostart (remove these lines to disable)" \
		"$(autostart_block "$exec_cmd" "$pgrep_name")"
	AUTOSTART_FILES="$AUTOSTART_FILES $ENV_BLOCK_FILES"
}

# ────────────────────── bin dirs / PATH ──────────────────────
# bin_dirs — the ONE source of truth for the framework's bin-dir set;
# emits idempotent PATH-update lines, LOW → HIGH priority order (consumers
# prepend in yield order, so the LAST emitted dir ends up first on PATH).
# Resolution mirrors the tools (pure parameter expansion, no `go env`):
#   GOBIN, else every GOPATH entry's bin, else ~/go/bin ($HOME stays
#   literal); ${CARGO_HOME:-$HOME/.cargo}/bin; ~/.local/bin; ~/.npm-global/bin.
# (/usr/local/bin is deliberately absent: a system path the default PATH
# already carries.)
# Priority (high → low): ~/.local/bin, cargo, go, npm.
#   export_path  — eval: export every dir, existing or not
#   persist_path — append_env_block: one case-line per dir (unconditional:
#                  a not-yet-existing dir is future-proofing)
bin_dirs() {
	local -a go_dirs=()
	if [ -n "${GOBIN:-}" ]; then
		go_dirs+=("$GOBIN")
	else
		# Split GOPATH on ':' ONLY (temporarily narrowed IFS — paths with
		# spaces survive); the escaped default keeps $HOME literal.
		local gopath_entry old_ifs=$IFS
		IFS=':'
		for gopath_entry in ${GOPATH:-\$HOME/go}; do
			go_dirs+=("$gopath_entry/bin")
		done
		IFS=$old_ifs
	fi
	printf '%s\n' 'case ":$PATH:" in *":$HOME/.npm-global/bin:"*) ;; *) export PATH="$HOME/.npm-global/bin:$PATH" ;; esac'
	local d i
	for ((i = ${#go_dirs[@]} - 1; i >= 0; i--)); do
		d=${go_dirs[i]}
		printf 'case ":$PATH:" in *":%s:"*) ;; *) export PATH="%s:$PATH" ;; esac\n' "$d" "$d"
	done
	printf '%s\n' 'case ":$PATH:" in *":${CARGO_HOME:-$HOME/.cargo}/bin:"*) ;; *) export PATH="${CARGO_HOME:-$HOME/.cargo}/bin:$PATH" ;; esac'
	printf '%s\n' 'case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) export PATH="$HOME/.local/bin:$PATH" ;; esac'
}

export_path() {
	# No [ -d ] filter: not-yet-existing dirs (rustup's ~/.cargo/bin at
	# startup, GOPATH/bin before the first install) are seeded anyway and
	# resolve the moment a binary lands in them — no re-seeds mid-run.
	eval "$(bin_dirs)"
	# Brew tier: AFTER system paths, BEFORE the WSL shims (see header).
	# Derived from BREW_PREFIXES; /usr/local/bin stays out — a system path
	# the default PATH already carries (see bin_dirs).
	local p
	for p in $BREW_PREFIXES; do
		[ "$p" = /usr/local ] && continue
		export_path_pre_win "$p/bin"
	done
}

persist_path() {
	# The SAME lines export_path evals — written to the profiles verbatim;
	# the case guards re-check at shell startup.
	# shellcheck disable=SC2016 # $PATH must stay literal in the block
	append_env_block "user-local bin dirs (framework installer)" "$(bin_dirs)"
	ok "PATH persistence added for the user-local framework bin dirs (~/.local/bin, GOBIN/GOPATH/cargo/npm-global — see bin_dirs)."
	# Brew dirs are persist_brew_path's business (positional; runs even
	# when PERSIST_PATH=0).
}

# persist_brew_path <brew_prefix> — Homebrew's profile block, called by
# install_linuxbrew at install/adopt time. Separate from persist_path:
# POSITIONAL insertion that a prepend case-line cannot express, and it
# runs even when PERSIST_PATH=0.
persist_brew_path() {
	local brew_prefix="$1"
	# One call, one block: bin and sbin are a unit (guard keyed on bin).
	local block
	block=$(_path_pre_win_snippet "$brew_prefix/bin" "$brew_prefix/sbin")
	append_env_block "Homebrew PATH (before Windows shims)" "$block"
}

# ────────────────────── compositor autostart (guarded VT login) ──────────────────────
# _path_pre_win_snippet <dir>... — the ONE rendering of the positioning
# algorithm for a GROUP of dirs installed as a unit (brew's bin+sbin):
# no-op when ANY group dir is already in PATH; insert before the FIRST
# /mnt entry; front when /mnt is first; plain append otherwise. POSIX text
# with $PATH left LIVE — export_path_pre_win evals it, persist_brew_path
# bakes it into the profile.
_path_pre_win_snippet() {
	[ $# -gt 0 ] || return 0
	local gtext="" group="" d
	for d in "$@"; do
		gtext+=$'\n*":'"$d"':"*) ;;'
		group+="${group:+:}$d"
	done
	# shellcheck disable=SC2016 # $PATH/$p must stay literal in the snippet
	cat <<EOF
case ":\$PATH:" in$gtext
:/mnt/* | ":/mnt:") PATH="$group:\$PATH" ;;
*":/mnt/"*)
	p=\${PATH%%:/mnt/*}
	PATH="\$p:$group:\${PATH#"\$p":}"
	unset p ;;
*) PATH="\$PATH:$group" ;;
esac
EOF
}

export_path_pre_win() {
	# The snippet assigns PATH (already exported — the assignment keeps the
	# export attribute); its `unset p` cleans up after the /mnt arm.
	eval "$(_path_pre_win_snippet "$@")"
}
