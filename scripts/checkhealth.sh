#!/usr/bin/env bash
# monkey-scripts entry point for dependency checks.
#
# NOT meant to be executed on its own: a project's checkhealth.sh sources this
# file, declares its dependency data, then calls checkhealth_main "$@".
#
#   #!/usr/bin/env bash
#   set -euo pipefail
#   . "$(dirname "$0")/scripts/checkhealth.sh"
#   PROJECT=monkey-zsh
#   REQUIRED_CHECKS=(...)
#   ...
#   checkhealth_main "$@"
#
# Sourcing fails fast (with an actionable message) when scripts/ is missing —
# that only happens if the repo was cloned without the subtree; install.sh
# (which can fetch monkey-scripts on the fly) is the recovery path.

# fail() must not abort the run: checkhealth collects failures and reports
# them in print_summary, which decides the exit status.
MONKEY_FAIL_EXITS=false
INSTALL_MODE=false
SKIP_CONFIG_CHECKS=false

_MONKEY_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ ! -f "$_MONKEY_LIB_DIR/lib/common.sh" ]; then
	echo "monkey-scripts not found next to this file ($_MONKEY_LIB_DIR/lib)." >&2
	echo "Clone the repo with its subtree, or run its install.sh first:" >&2
	echo "  git subtree add -P scripts master https://github.com/QMonkey/monkey-scripts.git" >&2
	exit 1
fi
# shellcheck source=/dev/null
. "$_MONKEY_LIB_DIR/lib/common.sh"
. "$_MONKEY_LIB_DIR/lib/sudo.sh"
. "$_MONKEY_LIB_DIR/lib/pkg.sh"
. "$_MONKEY_LIB_DIR/lib/config.sh"
. "$_MONKEY_LIB_DIR/lib/checks.sh"
. "$_MONKEY_LIB_DIR/lib/optional.sh"

# Data defaults: every project overwrites the ones it uses right after
# sourcing this file, so an unused one is simply an empty list.
REQUIRED_CHECKS=()
EXTRA_SPECS=() # installed, never listed (checked by an @call hook)
RECOMMENDED_CHECKS=()
OPTIONAL_CHECKS=()
CONFIG_LINKS=()
CONFIG_HINTS=()
ADVISORY_SECTIONS=()

usage() {
	cat <<EOF
Usage: $0 [OPTIONS]

Check and optionally install dependencies for ${PROJECT:-this project}.

OPTIONS
  -i, --install    Install missing dependencies
  --skip-check-config
                   Skip config-file checks (install.sh passes this: the
                   config symlinks are linked after this script runs)
  -h, --help       Show this help

Exit code: 1 if any required dependency is missing, 0 otherwise.
EOF
	exit 0
}

parse_args() {
	while [ $# -gt 0 ]; do
		case "$1" in
		-i | --install) INSTALL_MODE=true ;;
		--skip-check-config) SKIP_CONFIG_CHECKS=true ;;
		-h | --help) usage ;;
		*)
			echo "Unknown option: $1"
			usage
			;;
		esac
		shift
	done
}

print_summary() {
	if [ "$REQUIRED_FAILURES" -eq 0 ]; then
		echo -e "${GREEN}${BOLD}All required dependencies satisfied.${NC}"
		exit 0
	fi
	echo -e "${RED}${BOLD}Some required dependencies are missing.${NC}"
	if ! $INSTALL_MODE; then
		echo -e "Run ${CYAN}$0 --install${NC} to install them automatically."
	fi
	exit 1
}

# Project hook: extra section run right before print_summary (wezterm uses it
# to hand over to install.sh when the toolchain is missing).
checkhealth_extra() { :; }

# Project hook: probes printed between the title and Platform (monkey-hyprland
# reports the compositor version there). Anything that must influence the exit
# status belongs in checkhealth_extra instead — run_required_checks resets
# REQUIRED_FAILURES after this hook ran.
print_header_extra() { :; }

# ──────────────────────── pipeline ────────────────────────
# One fixed order for every repo:
#   required (+config when CONFIG_PHASE=required)
#   → install required → recommended → install recommended
#   → config when CONFIG_PHASE=early
#   → clipboard provider → optional listing → install optional
#   → terminal capabilities → advisory sections
#   → config when CONFIG_PHASE=end (default)
#   → project hook → summary
#
# Data switches understood by the pipeline (all optional):
#   CONFIG_PHASE=required|early|end   where the "Config files" section runs
#   ADVISORY_PHASE=early|end          where ADVISORY_SECTIONS run
#   INSTALL_REQUIRED_PHASE=early|late where install_missing_required runs
#                                      (late = after Terminal capabilities,
#                                      as in upstream zsh / monkey-tmux)
#   INSTALL_OPTIONAL_PHASE=early|late where install_missing_optional runs
#                                      (late = listing first, then install,
#                                      as in upstream zsh)
#   CHECK_TERMINAL_CAPS=1             print the "Terminal capabilities" section
#   TERMCAPS_STYLE=term|colorterm     color probe: TERM=… vs COLORTERM=…
#   CHECK_LANG=1                      ...and the LANG line under it
#   CHECK_CLIPBOARD=required|warn|display   clipboard handling
#   INSTALL_OPTIONAL=1                install missing optional tools too
#   OPTIONAL_INSTALL_TITLE="…"        header of the optional install batch
#                                      (default "Installing optional tools")
#   OPTIONAL_TRAILING_BLANK=0         no spacer after the optional section
#   OPTIONAL_ALL_PRESENT_MSG="…"      printed under --install when nothing
#                                     in the optional list is missing
#   OPTIONAL_DONE_MSG="…"             printed after a non-empty optional
#                                     install batch
#
# REQUIRED_CHECKS markers (see lib/checks.sh): "@header|Title" is printed
# bold — embed ${NC} inside the title to end the bold span early, e.g.
# "@header|python3${NC} (TIOCSTI injection)"; "@call|fn" hands the line to a
# project-defined check function.
# Project hooks that override the generic behaviour: print_header_extra,
# checkhealth_extra, install_missing_required, install_missing_optional,
# install_optional_bin (per-binary install table, used by the optional
# batch), optional_hint (FAIL hint in the optional listing), install_pkg.
checkhealth_main() {
	parse_args "$@"
	require_home
	OS=$(os_detect)
	OS_FAMILY=$(os_family "$OS")

	print_header
	print_header_extra
	print_platform
	run_required_checks
	if [ "${ADVISORY_PHASE:-end}" = "early" ]; then
		check_advisory_sections
	fi
	# INSTALL_REQUIRED_PHASE / INSTALL_OPTIONAL_PHASE: upstream zsh and
	# monkey-tmux run their install steps AFTER Terminal capabilities, the
	# rest before Recommended. Default: early.
	if [ "${INSTALL_REQUIRED_PHASE:-early}" != "late" ]; then
		install_missing_required
	fi
	check_recommended_tools
	install_missing_recommended
	if [ "${CONFIG_PHASE:-end}" = "early" ]; then
		check_config_files
	fi
	install_clipboard
	# Optional tools are installed BEFORE they are listed: the listing then
	# reflects what the installer just did (the nvim/vim order).
	if [ "${INSTALL_OPTIONAL_PHASE:-early}" != "late" ]; then
		install_missing_optional
	fi
	check_optional_tools
	check_terminal_caps
	if [ "${ADVISORY_PHASE:-end}" = "end" ]; then
		check_advisory_sections
	fi
	if [ "${CONFIG_PHASE:-end}" = "end" ]; then
		check_config_files
	fi
	if [ "${INSTALL_REQUIRED_PHASE:-early}" = "late" ]; then
		install_missing_required
	fi
	if [ "${INSTALL_OPTIONAL_PHASE:-early}" = "late" ]; then
		install_missing_optional
	fi
	checkhealth_extra
	print_summary
}
