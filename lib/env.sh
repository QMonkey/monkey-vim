# shellcheck shell=bash
# monkey-scripts/lib/env.sh — PATH seeding / persistence, shell env-file
# infrastructure, compositor autostart. Sourced by scripts/install.sh and
# scripts/checkhealth.sh (each entry point calls export_path for its own
# process right after os_init).
#
#   bin_dirs / export_path / persist_path — the framework bin-dir set: one
#       source of truth emitting idempotent PATH-update lines
#   _path_prepend_snippet — the ONE rendering of such a line
#   path_dirs_snippet — the ONE ordered rendering: Homebrew's insert FIRST,
#       then bin_dirs. export_path evals it; persist_path writes it as a
#       single head block, so the priority cannot depend on which writer
#       touched the profiles last. brew_ensure calls persist_path too
#       (past install.sh's gate), keeping Homebrew's carve-out: its PATH
#       lands in the profiles even when PERSIST_PATH=0.
#   export_brew_path — Homebrew's insert for THIS host, applied to the live
#       session: PREPENDED like any other bin dir on macOS (there brew IS
#       the host's package manager), POSITIONAL on Linux/WSL (a coverage
#       lane that must not outrank system paths) — see _brew_path_snippet
#   write_tty_autostart / autostart_block — guarded compositor exec block
#   shell_env_files / append_env_block — which profile files exist and how
#       blocks land in them
#   PROXY_ENV_KEYS / no_proxy_floor — the proxy trio every networked project
#       env file seeds, named once, plus the loopback floor NO_PROXY needs

# Homebrew prefixes: the single source of truth, split by host OS, one prefix
# per line. A brew already on PATH leads the list — its REAL prefix comes
# from command -v resolved by parameter expansion (no forks), so a custom
# install location gets seeded like the standard ones instead of only after
# brew_ensure ran. The OS candidates follow: a mac never has /home/linuxbrew
# and a Linux host never has /opt/homebrew, so a union list only ever put the
# OTHER system's prefix on PATH. /usr/local is a candidate on both: the
# Intel-mac prefix and the legacy Linuxbrew one. Reads the framework's $OS,
# which os_init has already validated (and exported) by the time any of this
# runs, so there is no unset/unknown arm left to take.
brew_prefixes() {
	local discovered cand list="/opt/homebrew /usr/local"
	[ "$OS" = macos ] || list="/home/linuxbrew/.linuxbrew /usr/local"
	# A shell function or alias named brew would answer "brew", not a path —
	# require the resolved binary before turning it into a prefix.
	if discovered=$(command -v brew) && [ -x "$discovered" ]; then
		discovered=${discovered%/*}
		discovered=${discovered%/*}
		printf '%s\n' "$discovered"
	fi
	for cand in $list; do
		[ "$cand" = "${discovered:-}" ] || printf '%s\n' "$cand"
	done
}

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

# env_source_line <path> — the ONE rendering of a profile line that sources an
# env file: `[[ -f X ]] && { set -a; source X; set +a; }`.
#
# X is spelled ~-relative while the file sits under $HOME, which is the default
# for every ${XDG_CONFIG_HOME:-$HOME/.config}-derived path, and absolute
# otherwise so an override never ends up naming a different file. `~` is the
# form a profile normally reads as, and it survives a $HOME containing spaces;
# with HOME unset bash still resolves ~ through the passwd entry where "$HOME"
# would expand to nothing and the guard would silently no-op. Measured in both
# shells: ~ still expands when $HOME itself contains spaces, so the ~-form needs
# no quoting; the absolute form is quoted because a path outside $HOME may.
#
# PATH lines are the opposite case and keep a literal $HOME (see bin_dirs):
# a ~ inside double quotes or a case pattern does NOT expand, so `PATH="~/.x"`
# would put the two characters ~ into PATH and the idempotency guard would
# never match the expanded value PATH actually holds.
env_source_line() {
	# Declaring and deriving in one `local` would leave _shown empty: bash
	# expands every word of a local command before assigning any of them.
	local _p="$1"
	local _shown
	# Readable ~ form whenever nothing in the tail would need escaping; anything
	# else (space, quote, $ , backtick, glob) goes through printf %q on the
	# absolute path, because double quotes alone would still expand $ and
	# backticks, and ~ cannot be quoted without losing its own expansion.
	local _tail _shown
	case "$_p" in
	"$HOME"/*)
		_tail=${_p#"$HOME/"}
		case $_tail in
		*[!A-Za-z0-9._/-]*) _shown=$(printf '%q' "$_p") ;;
		*) _shown="~/$_tail" ;;
		esac
		;;
	*) _shown=$(printf '%q' "$_p") ;;
	esac
	printf '[[ -f %s ]] && { set -a; source %s; set +a; }\n' "$_shown" "$_shown"
}

# PROXY_ENV_KEYS — the proxy trio every project env file seeds for its
# network-talking consumer. This is the single source for the KEY LIST (which
# names get filled); the `KEY=` lines themselves must exist in each template,
# because render_fill only ever fills a line that is already there. What each
# reader actually honours was measured on this host with the installed curl
# and Go toolchain, not read off documentation:
#   Go net/http (smart-suggestion's transport) — honours all six spellings for
#     both schemes, so HTTPS_PROXY/HTTP_PROXY/NO_PROXY are enough.
#   curl (minuet-ai.nvim spawns it) — HTTPS_PROXY/https_proxy work for https
#     URLs, NO_PROXY works either way, but for a PLAIN http URL curl only
#     reads lowercase http_proxy and ignores HTTP_PROXY.
# So the uppercase trio covers an https gateway in every consumer; a plain
# http gateway reached through curl needs a hand-written `http_proxy=` line in
# the same file — render_fill only ever touches the seeded keys, so that extra
# line survives every re-run.
#
# Seeding it in every project is deliberate: a host that installs only the
# editor and the shell (no agent tooling) has nothing else to fill in, and an
# install run from a minimal environment (sudo, cron, a first boot) has no
# inherited value to depend on either. The cost is that the same value now
# lives in one file per project, and render_fill NEVER rewrites a non-empty
# line — so rotating a proxy means editing every file that carries it, and
# leaving the trio empty in one file while another holds a value is not inert:
# the later-sourced empty line clears the earlier value for that subtree
# (verified: an empty assignment blanks an inherited one in bash and zsh, and
# curl as well as Go read an empty proxy as "do not proxy").
PROXY_ENV_KEYS="HTTPS_PROXY HTTP_PROXY NO_PROXY"

# no_proxy_floor [value] — NO_PROXY is additive by nature (exclusions only
# grow), so the loopback binds are appended to whatever the caller already
# listed rather than replacing it. Every consumer that dials a local endpoint
# needs this: with a proxy exported and no loopback entry, curl and Go both
# send http://127.0.0.1:… through the proxy, and the symptom (timeout from a
# completion request) sits far from the cause. Prints the merged list; the
# caller exports NO_PROXY to it before render_fill, which is what puts it in
# the file — templates always leave the line empty so the fill mode takes this
# value instead of a seeded default.
no_proxy_floor() {
	local np="${1-${NO_PROXY:-}}"
	local _d
	for _d in localhost 127.0.0.1 ::1; do
		case ",$np," in
		*,"$_d,"*) ;;
		*) np="${np:+$np,}$_d" ;;
		esac
	done
	printf '%s' "$np"
}

append_env_block() {
	# append_env_block <marker> <block> [head|normal|tail] — write one block into
	# every shell env file, then order that file by block class:
	#   [head]    env deps other blocks consume (PATH exports, secrets sourcing)
	#   [normal]  everything else, the user's own lines included (default)
	#   [tail]    process-replacing exec blocks (tmux / compositor autostart)
	# The class rides on the marker line ("# [tail] <marker>"), so every
	# component declares its own placement and none inspects another's text.
	# Dedup is a substring test on the bare marker: an existing block is never
	# written twice, and is then left exactly as it is — relabelling an
	# annotation this installer did not write is not its job.
	#
	# The rewrite is a stable partition: head, normal, tail, and within a class
	# the append order (= the chain's dependency order); anything whose line
	# carries no class — a block from a pre-class installer, or the user's own
	# preamble — counts as unmarked and sorts first. It SETS the layout
	# instead of inheriting it: blank
	# lines are separators, not content, so exactly one remains between blocks,
	# none at the top and none after the last line, while blanks inside a block
	# survive as its text. An already-correct file re-emits byte for byte, which
	# is what makes the pass idempotent.
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
		fi
		# Order the file and normalize its separators (see the rules above).
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
				first = 1
				for (c = 0; c <= 2; c++)
					for (sg = 1; sg <= nseg; sg++) {
						if (segcls[sg] != c) continue
						lo = 1
						while (lo <= segcnt[sg] && segline[sg, lo] ~ /^[[:space:]]*$/) lo++
						hi = segcnt[sg]
						while (hi >= lo && segline[sg, hi] ~ /^[[:space:]]*$/) hi--
						if (lo > hi) continue
						if (!first) print ""
						first = 0
						for (k = lo; k <= hi; k++) print segline[sg, k]
					}
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
# tools that write runtime files there fail (nvim serverstart(),
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
	"" | "/run/user/$uid") printf '%s\n' "${XDG_RUNTIME_DIR:-/run/user/$uid}" ;;
	# Another user's /run/user/N: unownable for this uid — ignore it.
	/run/user/*) printf '%s\n' "/run/user/$uid" ;;
	# A deliberate custom path (containers, custom setups): respect it.
	*) printf '%s\n' "$XDG_RUNTIME_DIR" ;;
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
	warn "Could not create $dir — nvim serverstart() will keep failing (fzf-lua and other RPC users)."
	warn "  Manual fix:  sudo touch $marker && sudo systemctl start user-runtime-dir@$uid.service"
}

# xdg_runtime_fix_cmd — print an `export XDG_RUNTIME_DIR=…` statement when
# the current value is unusable for this uid; empty string when fine.
# ensure_xdg_runtime_dir repairs SYSTEM state, but a child can never change
# the parent shell's env — the stale /run/user/0 a WSL root-boot session
# inherited survives it (the repair can log "ready" while the same shell's
# `systemctl --user` still fails, skipping service registration).
# Only the parent shell can export the fix; finish_install delivers it
# via TIOCSTI. Guard is state-based, not WSL-based: normal logins and `su`
# already carry pam_systemd's correct value → idempotent no-op.
xdg_runtime_fix_cmd() {
	local dir
	dir=$(runtime_dir_path)
	case "$XDG_RUNTIME_DIR" in
	"$dir") return 0 ;; # correct, empty, or deliberate custom — nothing to fix
	/run/user/*) ;;     # another user's dir (WSL root-boot session) — fix it
	*) return 0 ;;      # empty — PAM covers normal logins, nothing to repair
	esac
	# Only offer the fix when the target dir exists and is ours; otherwise
	# the export would point systemctl --user at a dead socket anyway.
	[ -d "$dir" ] && [ -w "$dir" ] || return 0
	printf 'export XDG_RUNTIME_DIR=%q' "$dir"
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
                printf '%s\n' "kmscon session: kmscon-launch-gui not found — start $exec_cmd manually." >&2
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
# _path_dir_renderable <dir> — can this text be pasted into a PATH snippet that
# a login shell will re-parse? Anything that would stop being one literal
# directory name there is refused at the boundary instead of escaped at render
# time, which keeps the emitted line byte-identical on every ordinary host: a
# double quote or a backslash breaks out of the quoting, a backquote or a `$(`
# runs a command, and a newline splits the line. A bare dollar sign is fine —
# parameter expansion cannot run anything, and '$HOME/…' is the framework's own
# idiom. Only environment-derived values reach this check: the framework's own
# '$HOME/.local/bin' and '${CARGO_HOME:-$HOME/.cargo}/bin' expressions are
# authored to be expanded by the login shell and are never validated.
_path_dir_renderable() {
	local _bad=$'"`\\'
	# shellcheck disable=SC2016 # the two-character sequence $( is matched
	# literally here; nothing is substituted at this point.
	case "$1" in
	*["$_bad"]* | *'$('* | *$'\n'*) return 1 ;;
	esac
	return 0
}

# _path_prepend_snippet <dir>... — the ONE rendering of a bin_dirs-style
# idempotent PATH line. ARGUMENT ORDER IS THE RESULTING PATH ORDER ($1 ends up
# ahead of $2), so callers name dirs high → low like the positional arm of
# _path_pre_win_snippet already does. Each dir gets its own guard, so a dir the
# host already carries is left where it is. POSIX text, $PATH literal.
_path_prepend_snippet() {
	local -a _dirs=("$@")
	local _d _i
	# Each line prepends, so the last-named dir has to run first.
	for ((_i = ${#_dirs[@]} - 1; _i >= 0; _i--)); do
		_d=${_dirs[_i]}
		# shellcheck disable=SC2016 # $PATH must stay literal in the line
		printf 'case ":$PATH:" in *":%s:"*) ;; *) export PATH="%s:$PATH" ;; esac\n' "$_d" "$_d"
	done
}

# bin_dirs — the ONE source of truth for the framework's user-local bin dirs;
# emits idempotent PATH-update lines, LOW → HIGH priority order (consumers
# prepend in yield order, so the LAST emitted dir ends up first on PATH).
# Resolution mirrors the tools (pure parameter expansion, no `go env`):
#   GOBIN, else every GOPATH entry's bin, else ~/go/bin ($HOME stays
#   literal); ${CARGO_HOME:-$HOME/.cargo}/bin; ~/.local/bin; ~/.npm-global/bin.
# (/usr/local/bin is deliberately absent: a system path the default PATH
# already carries.)
# Priority (high → low): ~/.local/bin, cargo, go, npm.
# Consumed only by path_dirs_snippet, which decides what a not-yet-existing
# dir means for this rendering (it is seeded anyway — future-proofing).
# This stdout is a DATA channel: persist_path captures it into the profile
# block verbatim, so a message here must go to stderr or it lands in the
# sourced file as shell text.
bin_dirs() {
	local -a go_dirs=()
	if [ -n "${GOBIN:-}" ]; then
		if _path_dir_renderable "$GOBIN"; then
			go_dirs+=("$GOBIN")
		else
			warn "GOBIN $(printf '%q' "$GOBIN") holds a character a login shell would re-parse (quote, backslash, backquote or command substitution) — left out of the PATH block" >&2
		fi
	else
		# Split GOPATH on ':' ONLY (temporarily narrowed IFS — paths with
		# spaces survive); the escaped default keeps $HOME literal.
		local gopath_entry old_ifs=$IFS
		IFS=':'
		for gopath_entry in ${GOPATH:-\$HOME/go}; do
			if [ -n "${GOPATH:-}" ] && ! _path_dir_renderable "$gopath_entry"; then
				warn "GOPATH entry $(printf '%q' "$gopath_entry") holds a character a login shell would re-parse — its bin dir is left out of the PATH block" >&2
				continue
			fi
			go_dirs+=("$gopath_entry/bin")
		done
		IFS=$old_ifs
	fi
	# Named high → low; the helper emits the lines in the order that yields
	# exactly this PATH (npm deepest, ~/.local/bin first).
	_path_prepend_snippet '$HOME/.local/bin' '${CARGO_HOME:-$HOME/.cargo}/bin' \
		${go_dirs[@]+"${go_dirs[@]}"} '$HOME/.npm-global/bin'
}

# path_dirs_snippet — the ONE ordered PATH rendering: Homebrew's insert
# FIRST, then the framework bin dirs. One list, one block, so the priority is
# fixed by construction instead of by which writer touched the profile last
# (prepend lines execute top-to-bottom, so the tier rendered last is the tier
# that ends up ahead).
# The brew tier still goes through _brew_path_snippet, which is where the
# host decides HOW brew is placed, not whether it comes first:
#   macOS — a prepend like every other dir, so running it first is what
#     drops it right below the user dirs and above /usr/local/bin.
#   Linux/WSL — a positional insert (append, or before the first /mnt),
#     whose landing spot is independent of the user dirs above it.
# /usr/local is skipped: a system path the default PATH already carries
# (path_helper on macOS), and seeding it as a "brew bin dir" would only
# shadow the real prefix.
path_dirs_snippet() {
	local p
	for p in $(brew_prefixes); do
		[ "$p" = /usr/local ] && continue
		# One of the reported prefixes is derived from PATH through
		# `command -v brew`, so it gets the same boundary check as the go
		# dirs; the two literal candidates can never fail it.
		_path_dir_renderable "$p" || continue
		_brew_path_snippet "$p/bin" "$p/sbin"
	done
	bin_dirs
}

export_path() {
	# No [ -d ] filter anywhere in the snippet: not-yet-existing dirs
	# (rustup's ~/.cargo/bin at startup, GOPATH/bin before the first install)
	# are seeded anyway and resolve the moment a binary lands in them — no
	# re-seeds mid-run.
	eval "$(path_dirs_snippet)"
}

persist_path() {
	# The SAME lines export_path evals — written to the profiles verbatim;
	# the case guards re-check at shell startup. brew_ensure calls this too
	# (not through install.sh's persist_path_step gate), so a host that
	# bootstraps Homebrew gets its PATH persisted even with PERSIST_PATH=0 —
	# Homebrew's carve-out, applied to the whole block.
	# No summary line of its own: append_env_block reports each file it
	# actually wrote, and this runs twice in a brew-carrying install
	# (brew_ensure, then the gate) — a "persistence added" on the second,
	# fully deduped call would be a lie.
	append_env_block "bin dirs + Homebrew PATH (framework installer)" \
		"$(path_dirs_snippet)" "head"
}

# _brew_path_snippet <dir>... — Homebrew's PATH insert for THIS host, asking
# the host which place brew deserves rather than guessing from the chain:
#   macOS — brew is the host's package manager (the only lane of its chain),
#     so the prefix is seeded exactly like a framework bin dir: prepended,
#     which is what `brew shellenv` does. Appending it leaves Apple's stubs in
#     /usr/bin (an old git, a CLT python3) ahead of every keg.
#   Linux/WSL — a coverage lane behind the distro index, so the prefix must
#     NOT outrank system paths; positional insert, ahead of the WSL shims only.
# Callers name dirs high → low (bin sbin); both arms honour that order.
_brew_path_snippet() {
	if [ "$OS" = macos ]; then
		_path_prepend_snippet "$@"
		return 0
	fi
	_path_pre_win_snippet "$@"
}

# _path_pre_win_snippet <dir>... — the Linux/WSL arm: ONE rendering of the
# positioning algorithm for a GROUP of dirs installed as a unit (brew's
# bin+sbin): no-op when ANY group dir is already in PATH; insert before the
# FIRST /mnt entry; front when /mnt is first; plain append otherwise. POSIX
# text with $PATH left LIVE — path_dirs_snippet yields it to export_path
# (which evals it) and to persist_path (which bakes it into the profiles).
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

export_brew_path() {
	# The snippet assigns PATH (already exported — the assignment keeps the
	# export attribute); the Linux arm's `unset p` cleans up after its /mnt case.
	eval "$(_brew_path_snippet "$@")"
}
