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
	# append_env_block <marker> <block> [head|normal|tail] — append/guard one
	# block in every shell env file, then keep the file ordered by block class:
	#   [head]    env deps other blocks consume (PATH exports, secrets sourcing)
	#   [normal]  everything else (default; also pre-class content and the user's own lines)
	#   [tail]    process-replacing exec blocks (tmux / compositor autostart)
	#             — always last; later appends partition BEFORE them
	# The class lives in the MARKER LINE's front ("# [tail] marker ..."); dedup
	# matches on the bare marker text (a substring of annotated lines too), so
	# pre-class blocks match without duplicating and get annotated on the next
	# run. Ordering = a stable partition (head, normal, tail; within a class:
	# appearance order = the install chain's order = the family's dependency
	# order). Leading content sorts as head. No content matching, no component
	# coupling: a component declares its own class; the partition is the rule.
	local marker="$1"
	local block="$2"
	local class="${3:-normal}"
	local f
	ENV_BLOCK_FILES=""
	while IFS= read -r f; do
		[ -n "$f" ] || continue
		[ -f "$f" ] || touch "$f"
		if ! grep -qF -- "$marker" "$f" 2>/dev/null; then
			printf '\n# [%s] %s\n%b\n' "$class" "$marker" "$block" >>"$f"
			ok "Added '$marker' to $f"
		else
			# Present: normalize the marker line's class annotation (the
			# block content stays untouched) — the class must persist in
			# the file; the partition pass reads it from here.
			awk -v m="$marker" -v c="$class" '
				index($0, m) > 0 && $0 ~ /^[[:space:]]*#/ {
					print "# [" c "] " m
					next
				}
				{ print }
			' "$f" >"$f.monkey-tmp" && mv "$f.monkey-tmp" "$f"
		fi
		# Stable partition: head / normal / tail; within a class the
		# appearance order is kept; leading content (no marker) sorts as
		# head. Idempotent: an already-partitioned file re-emits unchanged.
		awk '
			/^[[:space:]]*#[[:space:]]*\[(head|normal|tail)\][[:space:]]/ {
				nseg++
				segcls[nseg] = ($0 ~ /\[head\]/) ? 0 : ($0 ~ /\[tail\]/) ? 2 : 1
				segline[nseg, ++segcnt[nseg]] = $0
				pending = 1
				next
			}
			{
				if (!pending) { nseg++; segcls[nseg] = 0; pending = 1 }
				segline[nseg, ++segcnt[nseg]] = $0
			}
			END {
				for (c = 0; c <= 2; c++)
					for (sg = 1; sg <= nseg; sg++)
						if (segcls[sg] == c)
							for (k = 1; k <= segcnt[sg]; k++)
								print segline[sg, k]
			}
		' "$f" >"$f.monkey-tmp" && mv "$f.monkey-tmp" "$f"
		ENV_BLOCK_FILES="$ENV_BLOCK_FILES $f"
	done < <(shell_env_files)
}

# ────────────── /run/user/$UID repair (sessionless environments) ──────────────
# $XDG_RUNTIME_DIR comes from pam_systemd at login (logind creates
# /run/user/$UID 0700). Sessionless shells — WSL2 (it registers a logind
# session only for the distro's DEFAULT user, falling back to root without
# a /etc/wsl.conf [user] default), containers, CI, `su` — have none, and
# tools that write runtime files there fail (nvim/vim serverstart,
# fzf-lua, ...). Keyed on the SYMPTOM, not is_wsl(); the real fix is a
# proper default user (see consuming repos' README, "Precautions" → WSL2).
# runtime_dir_path resolves the dir for the REAL current user: under
# `sudo bash` / `su` $XDG_RUNTIME_DIR points at the OTHER user's
# /run/user/$UID — unownable, and repairing it would end in the misleading
# "could not create /run/user/0".
runtime_dir_path() {
	local uid
	uid=$(id -u)
	case "$XDG_RUNTIME_DIR" in
	"" | "/run/user/$uid") echo "${XDG_RUNTIME_DIR:-/run/user/$uid}" ;;
	# Another user's /run/user/N: unownable for this uid — ignore it.
	/run/user/*) echo "/run/user/$uid" ;;
	# A deliberate custom path (containers, custom setups): respect it.
	*) echo "$XDG_RUNTIME_DIR" ;;
	esac
}

ensure_xdg_runtime_dir() {
	local uid user dir marker wslconf
	uid=$(id -u)
	user=$(id -un)
	dir=$(runtime_dir_path)
	wslconf=/etc/wsl.conf

	# Already usable — the free path on every normal Linux login.
	if [ -d "$dir" ] && [ -w "$dir" ]; then
		return 0
	fi

	# Everything below needs root — report it here rather than letting the
	# user rediscover it later as a Lua/vim error with no causal trail.
	if [ "$uid" -ne 0 ] && ! have_native_cmd sudo; then
		warn "\$XDG_RUNTIME_DIR ($dir) is missing and no sudo is available — see README 'Precautions' (WSL2 default user)."
		return 0
	fi

	# ── Tier 0: fix the root cause ───────────────────────────────────────
	# WSL boots as root whenever /etc/wsl.conf has no [user] default;
	# declaring the current user gives future sessions a real logind
	# session. Only written when default= is absent; INI-aware (a
	# duplicated/misplaced section can break the boot). Effective after
	# `wsl.exe --shutdown`; tiers 1-2 repair the current boot.
	if is_wsl && [ "$uid" -ne 0 ]; then
		local msg_set msg_ok msg_warn
		msg_set="WSL boots as root (no default user) — setting $user in $wslconf..."
		msg_ok="WSL default user set to $user — effective after 'wsl.exe --shutdown'; the tiers below still repair the current boot."
		msg_warn="could not update $wslconf — add '[user] default=$user' manually (see README 'Precautions' → WSL2)."
		if sudo_cmd grep -Eq '^[[:space:]]*default[[:space:]]*=' "$wslconf" 2>/dev/null; then
			: # a default user is already declared — respect the existing choice
		elif sudo_cmd grep -q '^\[user\]' "$wslconf" 2>/dev/null; then
			# Insert right after the [user] header — appending at EOF would
			# land in the last section.
			info "$msg_set"
			if sudo_cmd sed -i "/^\[user\]/a default=${user}" "$wslconf"; then
				ok "$msg_ok"
			else
				warn "$msg_warn"
			fi
		else
			info "$msg_set"
			if printf '\n[user]\ndefault=%s\n' "$user" | sudo_cmd tee -a "$wslconf" >/dev/null; then
				ok "$msg_ok"
			else
				warn "$msg_warn"
			fi
		fi
	fi

	# Tiers 1-2 need systemd; without it nothing can create /run/user here.
	have_native_cmd systemctl || return 0

	info "Repairing \$XDG_RUNTIME_DIR ($dir) — no login session here, so logind never created it."

	# Tier 1: enable lingering — user@$UID.service at boot pulls in
	# user-runtime-dir@$UID.service and creates the directory (0700), and
	# repairs the user manager (dbus, gpg-agent). loginctl fails with ENXIO
	# where the seat daemon is `seatd` (Debian 13, WSL has no VT): then
	# write the linger marker directly — it IS the on-disk state
	# enable-linger exists to produce.
	marker="/var/lib/systemd/linger/$user"
	if have_native_cmd loginctl && loginctl enable-linger "$user" >/dev/null 2>&1; then
		ok "Enabled lingering for $user."
	elif sudo_cmd mkdir -p "$(dirname "$marker")" >/dev/null 2>&1 &&
		sudo_cmd touch "$marker" >/dev/null 2>&1; then
		ok "Enabled lingering for $user via $marker."
	fi

	# Tier 2: create the directory now. Name the runtime-dir unit explicitly
	# (user@.service only ORDERS After=user-runtime-dir@%i) and fall back to
	# the user manager.
	sudo_cmd systemctl start "user-runtime-dir@$uid.service" >/dev/null 2>&1 ||
		sudo_cmd systemctl start "user@$uid.service" >/dev/null 2>&1 || true

	if [ -d "$dir" ] && [ -w "$dir" ]; then
		ok "\$XDG_RUNTIME_DIR is ready ($dir)."
		return 0
	fi

	# Both tiers failed (no logind/seatd) — spell out both fixes.
	warn "Could not create $dir — nvim/vim serverstart() will keep failing (fzf-lua and other RPC users)."
	warn "  Manual fix:  sudo touch $marker && sudo systemctl start user-runtime-dir@$uid.service"
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
		"$(autostart_block "$exec_cmd" "$pgrep_name")" "tail"
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
	append_env_block "user-local bin dirs (framework installer)" "$(bin_dirs)" "head"
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
	append_env_block "Homebrew PATH (before Windows shims)" "$block" "head"
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
