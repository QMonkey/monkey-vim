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

_MONKEY_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ ! -f "$_MONKEY_LIB_DIR/lib/common.sh" ]; then
	echo "monkey-scripts not found next to this file ($_MONKEY_LIB_DIR/lib)." >&2
	echo "This checkout's scripts/ is incomplete (outdated or partial clone)." >&2
	echo "  git -C $(dirname "$_MONKEY_LIB_DIR") pull    # or re-clone the project" >&2
	exit 1
fi
# shellcheck source=/dev/null
. "$_MONKEY_LIB_DIR/lib/common.sh"
. "$_MONKEY_LIB_DIR/lib/sudo.sh"
. "$_MONKEY_LIB_DIR/lib/pkg.sh"
. "$_MONKEY_LIB_DIR/lib/config.sh"
. "$_MONKEY_LIB_DIR/lib/env.sh"
. "$_MONKEY_LIB_DIR/lib/clone.sh"
. "$_MONKEY_LIB_DIR/lib/kmscon.sh"

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

	if [ "$CHECKHEALTH_POS" != "after_links" ] && [ "${CHECKHEALTH_MODE:-run}" != "none" ]; then
		run_checkhealth_step
		echo ""
	fi

	install_step_autostart

	if [ "$PERSIST_PATH" = 1 ] && [ "${PERSIST_POS:-after_links}" = "before_links" ]; then
		persist_path
		echo ""
	fi

	setup_symlinks
	install_step_symlinks
	echo ""

	if [ "$CHECKHEALTH_POS" = "after_links" ] && [ "${CHECKHEALTH_MODE:-run}" != "none" ]; then
		run_checkhealth_step
		echo ""
	fi

	if [ "$PERSIST_PATH" = 1 ] && [ "${PERSIST_POS:-after_links}" = "after_links" ]; then
		persist_path
		echo ""
	fi

	install_step_after
	finish_install
}
