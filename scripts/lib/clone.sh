# shellcheck shell=bash
# monkey-scripts/lib/clone.sh — clone / checkhealth / autostart / finish.
#
# Sourced by scripts/install.sh (not by checkhealth.sh).
#
# Data contract (project side):
#   PROJECT / PROJECT_REPO / INSTALL_DIR
#   AUTOSTART_FILES    accumulated by write_tty_autostart (summary line)
#   SUMMARY_LINES      completion text, one echo -e per entry; an entry
#                      starting with "?VAR|" prints only when $VAR is set
#   FINISH_INJECT      1 (default) → print/perform the TIOCSTI injection hint
#   INSTALL_RUN_CHECKHEALTH  1 (default) → run checkhealth --install in main

clone_monkey_project() {
	# git must exist before anything here runs: the pull and the clone both
	# need it. ensure_git installs it via the package manager when missing
	# (setup_sudo has already run by the time this step is reached).
	ensure_git
	# On the curl|bash path this function is not what obtained the checkout:
	# the bootstrap in the project's install.sh had to clone before it could
	# reach this framework at all, and it clones into the same INSTALL_DIR.
	# So the first branch normally just confirms a checkout this run already
	# has (and pulls it, a no-op right after a clone) — one clone, not two.
	if [ -d "$INSTALL_DIR/.git" ]; then
		info "$PROJECT is at $INSTALL_DIR — pulling latest..."
		retry -s "git pull" git -C "$INSTALL_DIR" pull --ff-only ||
			warn "git pull failed — keeping existing version."
	elif [ -e "$INSTALL_DIR" ]; then
		# Existing non-git dir is fine (e.g. git clone with .git removed).
		warn "$INSTALL_DIR exists but is not a git repository — using it as-is."
	else
		info "Cloning $PROJECT to $INSTALL_DIR..."
		retry -s "git clone" git clone "$PROJECT_REPO" "$INSTALL_DIR"
	fi
	ok "$PROJECT ready at $INSTALL_DIR."
}

# PATH preseed before detection: checkhealth runs as a subprocess and only
# inherits the current shell's env. persist_path writes the go/bin, cargo/bin
# and npm-global/bin blocks to the profile LATER in main, so on a first run
# freshly installed binaries would be reported missing and re-installed by
# the retry loop.
#
# Two PATH tiers by design:
#   FRONT  ~/.local/bin — the brew-first whitelist (see _brew_first_link in
#          pkg.sh): only tools explicitly meant to beat the system versions.
#   BACK   Homebrew's bin dirs — appended, NEVER prepended: brew's binaries
#          must not shadow the system's (brew's python@3.x used to hide
#          /usr/bin/python3). Skipped when the dir does not exist, so
#          machines without Homebrew are unaffected.
# Export only — nothing is written to any profile here.
_preseed_path() {
	local d
	for d in "$HOME/.local/bin" \
		"$HOME/go/bin" \
		"$HOME/.cargo/bin" \
		"$HOME/.npm-global/bin"; do
		[ -d "$d" ] || continue
		case ":$PATH:" in *":$d:"*) ;; *) export PATH="$d:$PATH" ;; esac
	done
	for d in $BREW_BIN_DIRS; do
		[ -d "$d" ] || continue
		case ":$PATH:" in *":$d:"*) ;; *) export PATH="$PATH:$d" ;; esac
	done
}

# Run $INSTALL_DIR/checkhealth.sh --install --skip-check-config with retries.
# --install checks first and installs after; transient failures (network
# blips, apt locks, aborted downloads) heal on retry. After the first pass
# everything installed is skipped, so retries are cheap verifications.
# Three attempts, exit code 0 wins.
run_checkhealth() {
	_preseed_path
	info "Running checkhealth.sh --install to install remaining dependencies..."
	if retry -t 3600 -s "checkhealth" bash "$INSTALL_DIR/checkhealth.sh" --install --skip-check-config; then
		ok "Dependency check complete."
	else
		warn "Some dependencies could not be installed automatically."
		warn "Run 'cd $INSTALL_DIR && ./checkhealth.sh' to review remaining items."
	fi
}

# Plain run (no --install): verification only, never fatal.
verify_checkhealth() {
	_preseed_path
	bash "$INSTALL_DIR/checkhealth.sh" --skip-check-config || true
}

# go install drops binaries in $(go env GOPATH)/bin (default ~/go/bin);
# rustup installs cargo & rust-analyzer to ~/.cargo/bin; a built-from-source
# tool lives in /usr/local/bin. None is guaranteed to be on PATH, so persist
# exports for the detected shell (zsh→.zprofile, bash→.profile/.bash_profile).
persist_path() {
	# shellcheck disable=SC2016 # the block is written to profiles verbatim
	local block='case ":$PATH:" in *":/usr/local/bin:"*) ;; *) export PATH="/usr/local/bin:$PATH" ;; esac
case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) export PATH="$HOME/.local/bin:$PATH" ;; esac
case ":$PATH:" in *":$HOME/go/bin:"*) ;; *) export PATH="$HOME/go/bin:$PATH" ;; esac
case ":$PATH:" in *":$HOME/.cargo/bin:"*) ;; *) export PATH="$HOME/.cargo/bin:$PATH" ;; esac
case ":$PATH:" in *":$HOME/.npm-global/bin:"*) ;; *) export PATH="$HOME/.npm-global/bin:$PATH" ;; esac'
	append_env_block "monkey PATH" "$block"
	ok "PATH persistence added for /usr/local/bin, ~/.local/bin, go/bin, cargo/bin and npm-global/bin."
}

# ────────────────── compositor autostart (guarded VT login) ──────────────────
# The guarded autostart block. POSIX sh: it lands in ~/.profile too, which
# display managers may source with a minimal shell. Guards, cheapest first,
# so shells inside a desktop terminal or tmux pane short-circuit with zero
# forks:
#   1. $WAYLAND_DISPLAY / $DISPLAY both unset — one of them is set in any
#      desktop session (Wayland or X11).
#   2. stdin is a real VT (/dev/ttyN) — excludes ssh (/dev/pts/N), tmux
#      panes and desktop terminals in one check. Immune to inherited env: a
#      TTY-started tmux server passes XDG_VTNR down to its panes, but their
#      stdin stays a pty.
#   3. no <proc> running — single-instance policy: once the compositor owns a
#      session, VT logins on other consoles fall through to a plain shell (the
#      escape hatch instead of a second compositor).
#   4. kmscon session (TERM=kmscon — the kmscon >= 10.0.0 default, terminfo
#      shipped alongside) → wrap the compositor in kmscon-launch-gui: the
#      wrapper backgrounds the kmscon terminal (private OSC escape), lets the
#      compositor take DRM master on the same VT, and restores kmscon after.
#      Without the wrapper installed, skip the GUI start instead of bare-
#      execing the compositor underneath a live kmscon renderer. The TERM
#      check is deliberately the ONLY detection: sessions that do not set
#      TERM=kmscon are pre-10.0.0 or user-overridden builds, and those lack
#      the OSC background/foreground handoff the wrapper depends on — for
#      them the plain exec is as good as it gets.
autostart_block() {
	local exec_cmd="$1" pgrep_name="$2"
	cat <<EOF
# $PROJECT autostart (remove these lines to disable)
# Keep the block below ABOVE any "exec tmux" auto-start block: on a bare TTY
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

write_tty_autostart() {
	local exec_cmd="$1" pgrep_name="$2"
	local marker="# $PROJECT autostart" f
	# WSL has no VT login — stdin never resolves to /dev/ttyN, so the guarded
	# block would be dead code. WSLg renders single GUI apps without a
	# compositor.
	if is_wsl; then
		info "WSL detected — skipping autostart setup (no VT login; WSLg covers GUI apps)."
		return 0
	fi
	while IFS= read -r f; do
		[ -n "$f" ] || continue
		[ -f "$f" ] || touch "$f"
		if grep -qF -- "$marker" "$f"; then
			ok "autostart block already present in $f."
		else
			# Ordering vs a tmux auto-start block needs no insert logic: the
			# meta-installer installs compositor repos before the tmux repo,
			# so this block is always appended first.
			printf '\n%s\n' "$(autostart_block "$exec_cmd" "$pgrep_name")" >>"$f"
			ok "Added autostart block to $f."
		fi
		AUTOSTART_FILES="$AUTOSTART_FILES $f"
	done < <(shell_env_files)
}

# ────────────────── completion ──────────────────
finish_install() {
	echo -e "${GREEN}${BOLD}${PROJECT} installation complete!${NC}"
	echo ""
	local line cond var text
	for line in ${SUMMARY_LINES[@]+"${SUMMARY_LINES[@]}"}; do
		cond=""
		case "$line" in
		\?*)
			cond="${line%%|*}"
			var="${cond#\?}"
			text="${line#*|}"
			[ -n "${!var:-}" ] || continue
			;;
		*)
			text="$line"
			;;
		esac
		echo -e "$text"
	done
	echo ""
	if [ "${FINISH_INJECT:-1}" = 1 ]; then
		# PATH exports were written to shell rc files, but they only apply to
		# shells started AFTER this point. A child process can never change
		# the parent shell's environment, so spell out how to pick it up now.
		local env_file
		env_file="$(shell_env_files | head -1)"
		# ACQUIRE_TIOCSTI protocol: only the script that claimed the injection
		# right acts. When chained, the wrapper holds the right and injects
		# once at its own end — per-component hints would be redundant there.
		if [ "${ACQUIRE_TIOCSTI:-$PROJECT}" != "$PROJECT" ]; then
			: # wrapper holds the injection right
		elif inject_tty "source ${env_file}"; then
			echo -e "  ${GREEN}Injected 'source ${env_file}' into the current terminal.${NC}"
		else
			echo -e "  ${YELLOW}New PATH takes effect in NEW shells. To use it in this terminal now:${NC}"
			echo -e "    ${CYAN}source ${env_file}${NC}    ${YELLOW}# or simply: ${CYAN}exec \$SHELL${NC}"
		fi
		echo ""
	fi
}
