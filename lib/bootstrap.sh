# shellcheck shell=bash
# monkey-scripts/lib/bootstrap.sh — shared sourcing head of both entry
# points (install.sh / checkhealth.sh): resolve the lib dir, fail fast on an
# incomplete subtree, source the framework.
#
# The entry point sets EXTRA_LIBS (whitespace-separated lib names)
# BEFORE sourcing this file; those are appended after the common set:
#   install.sh     EXTRA_LIBS="kmscon"
#   checkhealth.sh EXTRA_LIBS="checks missing clipboard"

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ ! -f "$LIB_DIR/common.sh" ]; then
	echo "monkey-scripts not found next to this file ($LIB_DIR)." >&2
	echo "This checkout's scripts/ is incomplete (outdated or partial clone)." >&2
	echo "  git -C $(dirname "$LIB_DIR") pull    # or re-clone, or run the project's install.sh" >&2
	exit 1
fi
# shellcheck source=/dev/null
for _lib in common retry sudo tty output clone pkg distro brew toolchain template config env ${EXTRA_LIBS:-}; do
	. "$LIB_DIR/$_lib.sh"
done
unset _lib EXTRA_LIBS
