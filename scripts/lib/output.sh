# monkey-scripts/lib/output.sh — terminal output helpers: banner, section
# headers, the Platform block, install hints, and the installer's completion
# summary.
#
# Sourced by scripts/install.sh and scripts/checkhealth.sh.
#
# Data contract (project side, completion summary):
#   SUMMARY_LINES      completion text, one echo -e per entry; an entry
#                      starting with "?VAR|" prints only when $VAR is set
#   FINISH_INJECT      1 (default) → print/perform the TIOCSTI injection hint
#
# The hint functions here derive the human command from the same strategy
# chain the `install` field of a dependency spec uses — a project may
# override `optional_hint` after sourcing this file.

# ────────────────────── banner ──────────────────────
# 80-column box (the smallest standard terminal width); the title is
# centered inside it. The border is generated from WIDTH so the character
# count can never drift from the padding math again.
print_banner() {
	local title="$1" width=80 pad border right
	printf -v border '═%.0s' {1..80}
	pad=$(((width - ${#title}) / 2))
	[ "$pad" -gt 0 ] || pad=0
	right=$((width - pad - ${#title}))
	[ "$right" -gt 0 ] || right=0
	echo ""
	echo -e "${BOLD}╔${border}╗${NC}"
	echo -e "${BOLD}║$(printf '%*s' "$pad" '')${title}$(printf '%*s' "$right" '')║${NC}"
	echo -e "${BOLD}╚${border}╝${NC}"
	echo ""
}

# Bold section title. A data-provided title may already carry ${NC} to end
# the bold span early ("python3${NC} (TIOCSTI injection)") — do not reset a
# second time, so the byte stream matches a hand-written header exactly.
print_bold_header() {
	case "$1" in
	*"${NC}"*) echo -e "${BOLD}$1" ;;
	*) echo -e "${BOLD}$1${NC}" ;;
	esac
}

# ────────────────────── checkhealth header ──────────────────────
print_header() {
	echo -e "${BOLD}${PROJECT} dependency check${NC}"
	echo ""
}

# ────────────────────── platform ──────────────────────
# Human-readable package manager for the Platform block.
pkg_manager_name() {
	case "$(pkg_manager)" in
	apt) echo "apt" ;;
	pacman) echo "pacman" ;;
	zypper) echo "zypper" ;;
	dnf) echo "dnf" ;;
	brew) echo "homebrew" ;;
	*) echo "" ;;
	esac
}

print_platform() {
	echo -e "${BOLD}Platform${NC}"
	echo -e "  OS: ${CYAN}$(uname -s)${NC}"
	local pm
	pm=$(pkg_manager_name)
	if [ -n "$pm" ]; then
		echo -e "  Package manager: ${CYAN}${pm}${NC}"
	else
		warn "Unsupported OS — install dependencies manually"
	fi
	echo ""
}

# Human install command for one or more package names — the "Run:" line and
# the hint after a failed install. The manager id comes from pkg_manager()
# (lib/pkg.sh); this is the rendering side, kept with the other hint helpers.
get_install_hint() {
	case "$(pkg_manager)" in
	apt) echo "sudo apt-get install ${*}" ;;
	pacman) echo "sudo pacman -S ${*}" ;;
	zypper) echo "sudo zypper install ${*}" ;;
	dnf) echo "sudo dnf install ${*}" ;;
	brew) echo "brew install ${*}" ;;
	*)
		case "${OS:-unknown}" in
		linux-unknown) echo "install ${*} manually or 'brew install ${*}'" ;;
		*) echo "install ${*} manually" ;;
		esac
		;;
	esac
}

# ──────────────────────── hints ────────────────────────
# Human command for one strategy step ("" when unknown).
# KEEP IN SYNC with lib/pkg.sh install_strategy_step: the two case tables
# walk the SAME set of kinds — one executes a step, this one renders its
# human-readable command. A new kind needs a row in BOTH.
_strategy_hint() {
	local kind="$1" args="$2" b
	case "$kind" in
	pkg)
		if [ -n "$args" ]; then
			for b in $args; do
				get_install_hint "$b"
			done | tr '\n' ' '
		else
			get_install_hint "$SPEC_ID"
		fi
		;;
	npm)
		echo "npm install -g $args"
		;;
	go)
		echo "go install $args"
		;;
	cargo)
		echo "cargo install $args"
		;;
	pip)
		echo "pip3 install --user $args"
		;;
	brew)
		echo "brew install $args"
		;;
	zig-zls-pair)
		echo "brew install zls zig@<zls-version>  # version-locked pair (zls ceiling)"
		;;
	rustup)
		echo "https://rustup.rs/"
		;;
	rustup-component)
		echo "rustup component add $args"
		;;
	python-unversioned)
		echo "ln -s \$(command -v python3) /usr/local/bin/python"
		;;
	esac
}

# Default hint: join the hints of every strategy step with "# or:".
# Projects may define their own `optional_hint` after sourcing this file.
optional_hint() {
	local bin="$1" strategy rest h out=""
	load_spec_for "$bin"
	strategy="${SPEC_INSTALL:-pkg}"
	rest="$strategy"
	while _strategy_split "$rest"; do
		rest="$_STRATEGY_REST"
		h=$(_strategy_hint "$_STRATEGY_KIND" "$_STRATEGY_ARGS")
		[ -n "$h" ] || continue
		if [ -z "$out" ]; then
			out="$h"
		else
			out="$out # or: $h"
		fi
	done
	case "$bin" in
	# Wording/comments the pure strategy chain cannot express.
	clangd) out="${out}  # or clangd-15+" ;;
	zig) out="${out}  # or: https://ziglang.org/download/" ;;
	zls) out="${out}  # or: https://zigtools.org/zls/install/  (must match zig version)" ;;
	cargo) out="https://rustup.rs/  # then: rustup component add rust-analyzer" ;;
	rust-analyzer) out="rustup component add rust-analyzer" ;;
	go) out="https://go.dev/dl/" ;;
	node) out="https://nodejs.org/  # or: $(get_install_hint nodejs npm)" ;;
	esac
	printf '%s' "$out"
}

# ────────────────────── completion summary ──────────────────────
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
