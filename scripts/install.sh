#!/usr/bin/env bash
# monkey-scripts entry point for installers.
#
# NOT meant to be executed on its own: a project's install.sh sources this
# file, declares its data and its step hooks, then calls install_main "$@".
#
#   #!/usr/bin/env bash
#   set -euo pipefail
#   . "$(dirname "$0")/scripts/install.sh"      # or the curl|bash bootstrap
#   PROJECT=monkey-zsh
#   PROJECT_REPO=https://github.com/QMonkey/monkey-zsh.git
#   install_step_tool() { install_zsh; echo ""; }
#   SUMMARY_LINES=(...)
#   install_main "$@"
#
# Hook order inside install_main (a hook prints its own trailing blank):
#   banner → OS info → setup_sudo → prepare → tool → post → clone
#   → checkhealth → refresh PATH → autostart → symlinks (+step_symlinks)
#   → persist PATH (PERSIST_POS=before_links runs it earlier) → after
#   → completion summary

# fail() aborts: an installer must stop at the first fatal step.
MONKEY_FAIL_EXITS=true

EXTRA_LIBS="kmscon"
. "$(dirname "${BASH_SOURCE[0]}")/lib/bootstrap.sh"

# Data defaults — a project overwrites whatever it uses after sourcing.
SYMLINKS=()
ENSURE_DIRS=()
ENSURE_FILES=()
INSTALL_INFO=()
SUMMARY_LINES=()
AUTOSTART_FILES=""
PERSIST_PATH=0
PERSIST_POS=after_links # before_links | after_links
FINISH_INJECT=1
LINUX_ONLY=0
CHECKHEALTH_MODE=run # run | verify | none
CHECKHEALTH_POS=tool # tool | after_links

# ──────────────────────── step hooks ────────────────────────
# Each hook prints its own trailing blank line when it produced output.
install_step_prepare() { :; }
install_step_tool() { :; }
install_step_post_tool() { :; }
install_step_autostart() { :; }
# Runs inside the symlink step, before its closing blank — for extras that
# belong to the same output block (monkey-nvim's efm-langserver link).
install_step_symlinks() { :; }
install_step_after() { :; }
# Extra info lines right after the OS announcement (monkey-vim announces its
# WSL build there).
install_print_info() { :; }

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
				*)
					KMSCON_TTYS=$2
					shift
					;;
				esac
			fi
			;;
		*) args+=("$1") ;;
		esac
		shift
	done
	_INSTALL_ARGS=("${args[@]+"${args[@]}"}")
}

run_checkhealth_step() {
	case "${CHECKHEALTH_MODE:-run}" in
	run)
		run_checkhealth
		;;
	verify)
		verify_checkhealth
		;;
	esac
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
	if retry -t "$RETRY_T_HEAVY" -s "checkhealth" bash "$INSTALL_DIR/checkhealth.sh" --install --skip-check-config; then
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

# ──────────────────────── position-gated steps ────────────────────────
# Steps the project can MOVE in the pipeline: CHECKHEALTH_POS (tool |
# after_links) and PERSIST_POS (before_links | after_links) name the phase
# each runs in. The gate helpers keep install_main a flat, linear sequence
# — every step appears exactly once, at its default position.
checkhealth_step() { # <pos: tool | after_links>
	[ "${CHECKHEALTH_MODE:-run}" = none ] && return 0
	[ "${CHECKHEALTH_POS:-tool}" = "$1" ] || return 0
	run_checkhealth_step
	echo ""
}
persist_path_step() { # <pos: before_links | after_links>
	[ "$PERSIST_PATH" = 1 ] || return 0
	[ "${PERSIST_POS:-after_links}" = "$1" ] || return 0
	persist_path
	echo ""
}

install_main() {
	require_home
	OS=$(os_detect)

	print_banner "${PROJECT} installer"
	if [ "$LINUX_ONLY" = 1 ] && { [ "$OS" = "macos" ] || [ "$OS" = "unknown" ]; }; then
		warn "Current system is not Linux — ${PROJECT} is Wayland/Linux-only, skipping."
		exit 0
	fi
	# One id per distro (Ubuntu is no longer folded into Debian, and neither
	# is Fedora into CentOS), so the line reports exactly what was detected.
	info "Detected OS: ${CYAN}${OS}${NC}"
	# Build-flavor notes (monkey-vim's WSL GTK3 line) belong right after the
	# OS announcement, before the layout lines.
	install_print_info
	info "${PROJECT}: ${CYAN}${INSTALL_DIR}${NC}"
	local line
	for line in ${INSTALL_INFO[@]+"${INSTALL_INFO[@]}"}; do
		info "$line"
	done
	echo ""

	# No blank line here: the original installers let the first hook's
	# output follow setup_sudo directly (a project that wants separation
	# opens its prepare hook with `echo ""`).
	setup_sudo

	# Seed the framework bin dirs BEFORE anything runs: with no [ -d ]
	# filter the entries are seeded even when the dirs do not exist yet, so
	# binaries installed by any later step resolve immediately.
	export_path

	install_step_prepare
	install_step_tool
	install_step_post_tool

	clone_project
	echo ""

	checkhealth_step tool

	install_step_autostart

	persist_path_step before_links

	setup_symlinks
	install_step_symlinks
	echo ""

	checkhealth_step after_links

	persist_path_step after_links

	install_step_after
	finish_install
}
