# shellcheck shell=bash
# monkey-scripts/lib/clone.sh — clone / checkhealth / finish.
#
# Sourced by scripts/install.sh (not by checkhealth.sh).
#
# Data contract (project side):
#   PROJECT / PROJECT_REPO / INSTALL_DIR
#   AUTOSTART_FILES    accumulated by write_tty_autostart (lib/env.sh;
#                      summary line)
#   SUMMARY_LINES      completion text, one echo -e per entry; an entry
#                      starting with "?VAR|" prints only when $VAR is set
#   FINISH_INJECT      1 (default) → print/perform the TIOCSTI injection hint
#   INSTALL_RUN_CHECKHEALTH  1 (default) → run checkhealth --install in main

# ────────────────── interrupted-clone repair ──────────────────
# A git clone killed mid-transfer (retry timeout, network drop) leaves a
# directory carrying .git but no checked-out worktree and no HEAD. Every
# later operation on it then fails forever: `git pull` dies, a fresh
# `git clone` refuses with "already exists", and nvim's vim.pack lock
# repair dies with "ambiguous argument 'HEAD'" — taking every OTHER plugin
# down with it (observed on openSUSE: one clone timeout, 34 plugins dead).
# A directory whose HEAD is unreadable cannot resume — removal is the only
# repair, so the caller's clone/pull starts clean. Healthy checkouts and
# dirs without .git are untouched.
repair_broken_clone() {
	local dir="$1"
	[ -n "$dir" ] && [ -d "$dir/.git" ] || return 0
	if ! git -C "$dir" rev-parse HEAD >/dev/null 2>&1; then
		warn "removing broken git clone (interrupted clone, no HEAD): ${dir#"$HOME"/}"
		rm -rf -- "$dir"
	fi
	return 0
}

# clone_repo [--submodules] [--<git-clone-option>...] <url> <dir> — the
# framework's git clone, a patch over `git clone` that owns the three states
# a target dir can be in, so projects stop hand-rolling the if/else:
#   --submodules       SHALLOW TWO-STEP fetch, the reliable variant (the
#                      one-step `--recurse-submodules --depth=1` combination
#                      is flaky on the remote side): part 1 `git clone
#                      --depth=1` — shallow is IMPLIED, do not pass --depth
#                      yourself; part 2 `git submodule update --init
#                      --recursive` (retried) after BOTH paths — fresh clone
#                      and pull. Idempotent (already-checked-out submodules
#                      are skipped), so one unconditional call covers both;
#                      failure propagates
#   missing            → clone (options like --branch=main pass through)
#   .git, HEAD ok      → pull --ff-only (failure keeps the checkout, rc 0)
#   .git, HEAD broken  → rm -rf, then a clean clone (an interrupted clone
#                        cannot resume, and `git clone` would refuse
#                        "already exists" forever)
#   no .git            → left untouched with a warning, rc 1 (user data —
#                        `git clone` would refuse too)
# The flag and the git-clone options may appear ANYWHERE relative to the two
# bare positionals <url> <dir> — the parser classifies by shape, so
# `clone_repo --branch=main <url> <dir>` and `clone_repo <url> <dir>
# --branch=main` are the same call. (The first draft parsed positionally and
# the wezterm call site passed options FIRST — it only ever "worked" because
# git re-parses stray tokens as trailing options, while $dir silently held a
# garbage value and the pull path was unreachable.)
# A killed clone attempt leaves a .git-only partial dir behind — repaired
# before returning, so the caller's next outer attempt (checkhealth retry,
# re-run) can actually clone.
_clone_submodules() {
	retry -t 1800 -s "git submodule update" git -C "$1" submodule update --init --recursive
}

clone_repo() {
	local raw="$*" submodules=0 has_depth=0
	local -a git_args=() positional=()
	while [ $# -gt 0 ]; do
		case "$1" in
		--submodules) submodules=1 ;;
		--depth*)
			has_depth=1
			git_args+=("$1")
			;;
		-*) git_args+=("$1") ;;  # git-clone options (--branch=main, ...)
		*) positional+=("$1") ;; # the two bare positionals: url, dir
		esac
		shift
	done
	if [ ${#positional[@]} -ne 2 ]; then
		die "clone_repo: expected <url> <dir> plus optional flags — got: $raw"
	fi
	local url=${positional[0]} dir=${positional[1]}
	repair_broken_clone "$dir"
	if [ -d "$dir/.git" ]; then
		info "git repo already at ${dir#"$HOME"/} — pulling latest..."
		retry -s "git pull" git -C "$dir" pull --ff-only ||
			warn "git pull failed — keeping the existing checkout."
		[ "$submodules" = 1 ] || return 0
		_clone_submodules "$dir"
		return
	fi
	if [ -e "$dir" ]; then
		warn "$dir exists and is not a git clone — leaving it untouched."
		return 1
	fi
	if [ "$submodules" = 1 ] && [ "$has_depth" = 0 ]; then
		git_args+=(--depth=1)
	fi
	if retry -t 1800 -s "git clone ${dir##*/}" git clone ${git_args[@]+"${git_args[@]}"} "$url" "$dir"; then
		[ "$submodules" = 1 ] || return 0
		_clone_submodules "$dir"
		return
	fi
	repair_broken_clone "$dir"
	return 1
}

clone_project() {
	# git must exist before anything here runs: the pull and the clone both
	# need it. ensure_git installs it via the package manager when missing
	# (setup_sudo has already run by the time this step is reached).
	ensure_git
	# On the curl|bash path this function is not what obtained the checkout:
	# the bootstrap in the project's install.sh had to clone before it could
	# reach this framework at all, and it clones into the same INSTALL_DIR.
	# So clone_repo normally just confirms (and pulls) a checkout this run
	# already has — one clone, not two. A non-git INSTALL_DIR (zip extract,
	# stray files) is left untouched — the install proceeds with it as-is.
	clone_repo "$PROJECT_REPO" "$INSTALL_DIR" ||
		warn "$INSTALL_DIR exists but is not a git repository — using it as-is."
	ok "$PROJECT ready at $INSTALL_DIR."
}

# Run $INSTALL_DIR/checkhealth.sh --install --skip-check-config with retries.
# --install checks first and installs after; transient failures (network
# blips, apt locks, aborted downloads) heal on retry. After the first pass
# everything installed is skipped, so retries are cheap verifications.
# Three attempts, exit code 0 wins.
run_checkhealth() {
	info "Running checkhealth.sh --install to install remaining dependencies..."
	# Chain marker: a chained --install keeps the NOPASSWD drop-in default —
	# the installer's own setup_sudo has already granted, and long chained
	# runs need it (see checkhealth_main in checkhealth.sh). Manual runs
	# default to timestamp-only authentication.
	INSTALL_CHAIN=1
	export INSTALL_CHAIN
	if retry -t 3600 -s "checkhealth" bash "$INSTALL_DIR/checkhealth.sh" --install --skip-check-config; then
		ok "Dependency check complete."
	else
		warn "Some dependencies could not be installed automatically."
		warn "Run 'cd $INSTALL_DIR && ./checkhealth.sh' to review remaining items."
	fi
}

# Plain run (no --install): verification only, never fatal.
verify_checkhealth() {
	bash "$INSTALL_DIR/checkhealth.sh" --skip-check-config || true
}

# Insert one or more lines into SUMMARY_LINES so that the FIRST inserted
# line lands at <index> (later ones follow in order). <index> may be
# negative — counted from the end (-1 = before the last line), which is how
# variable outcomes ("kmscon:" console line, RDP lines) slot ahead of the
# fixed "Update:" tail; small positive indexes slot into the fixed head
# (the compositor "Autostart:" line lands at 2, after Config/Start).
# Lines pass through finish_install verbatim: a leading "?VAR|" makes an
# entry conditional (see the data contract above).
summary_insert_at() {
	local idx=$1
	shift
	local len=${#SUMMARY_LINES[@]}
	[ "$idx" -lt 0 ] && idx=$((len + idx))
	local -a head=("${SUMMARY_LINES[@]:0:idx}") tail=("${SUMMARY_LINES[@]:idx}")
	SUMMARY_LINES=(${head[@]+"${head[@]}"} "$@" ${tail[@]+"${tail[@]}"})
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
