# monkey-scripts/lib/output.sh — terminal output helpers: banner, section
# headers, the Platform block, install hints, and the installer's completion
# summary.
#
# Sourced by scripts/install.sh and scripts/checkhealth.sh.
#
# Data contract (project side, completion summary):
#   SUMMARY_LINES      completion text, one printf per entry; an entry
#                      starting with "?VAR|" prints only when $VAR is set
#   FINISH_INJECT      1 (default) → print/perform the TIOCSTI injection hint
#
# The hint functions here derive the human command from the same strategy
# chain the `install` field of a dependency spec uses — a project may
# override `optional_hint` after sourcing this file.

# ────────────────────── banner ──────────────────────
# 80-column box (the smallest standard terminal width); the title is
# centered inside it. The border is generated from WIDTH so the character
# count cannot drift from the padding math.
print_banner() {
	local title="$1" width=80 pad border right
	printf -v border '═%.0s' {1..80}
	pad=$(((width - ${#title}) / 2))
	[ "$pad" -gt 0 ] || pad=0
	right=$((width - pad - ${#title}))
	[ "$right" -gt 0 ] || right=0
	printf '\n'
	printf '%s\n' "${BOLD}╔${border}╗${NC}"
	printf '%s\n' "${BOLD}║$(printf '%*s' "$pad" '')${title}$(printf '%*s' "$right" '')║${NC}"
	printf '%s\n' "${BOLD}╚${border}╝${NC}"
	printf '\n'
}

# Bold section title. A data-provided title may already carry ${NC} to end
# the bold span early ("python3${NC} (TIOCSTI injection)") — do not reset a
# second time, so the byte stream matches a hand-written header exactly.
print_bold_header() {
	case "$1" in
	*"${NC}"*) printf '%s\n' "${BOLD}$1" ;;
	*) printf '%s\n' "${BOLD}$1${NC}" ;;
	esac
}

# ────────────────────── checkhealth header ──────────────────────
print_header() {
	printf '%s\n' "${BOLD}${PROJECT} dependency check${NC}"
	printf '\n'
}

# ────────────────────── platform ──────────────────────
# Human-readable package manager for the Platform block: pkg_manager's id,
# with Homebrew spelled out.
pkg_manager_name() {
	local pm
	pm=$(pkg_manager)
	[ "$pm" = brew ] && pm=homebrew
	printf '%s\n' "$pm"
}

print_platform() {
	printf '%s\n' "${BOLD}Platform${NC}"
	printf '%s\n' "  OS: ${CYAN}$(uname -s)${NC}"
	local pm
	pm=$(pkg_manager_name)
	if [ -n "$pm" ]; then
		printf '%s\n' "  Package manager: ${CYAN}${pm}${NC}"
	else
		warn "Unsupported OS — install dependencies manually"
	fi
	printf '\n'
}

# Human install command for one or more package names — the "Run:" line and
# the hint after a failed install. The manager id comes from pkg_manager()
# (lib/pkg.sh); this is the rendering side, kept with the other hint helpers.
get_install_hint() {
	case "$(pkg_manager)" in
	apt) printf '%s\n' "sudo apt-get install ${*}" ;;
	pacman) printf '%s\n' "sudo pacman -S ${*}" ;;
	zypper) printf '%s\n' "sudo zypper install ${*}" ;;
	dnf) printf '%s\n' "sudo dnf install ${*}" ;;
	brew) printf '%s\n' "brew install ${*}" ;;
	*) printf '%s\n' "install ${*} manually" ;;
	esac
}

# ──────────────────────── hints ────────────────────────
# Human command for one strategy step ("" = nothing to run, which is what
# `none` means and what an unknown kind answers).
# KEEP IN SYNC with lib/pkg.sh install_strategy_step: the two case tables
# walk the SAME set of kinds — one executes a step, this one renders its
# human-readable command. A new kind needs a row in BOTH.
_strategy_hint() {
	local kind="$1" args="${2:-}" b
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
		printf '%s\n' "npm install -g $args"
		;;
	go)
		printf '%s\n' "go install $args"
		;;
	pip)
		printf '%s\n' "pip3 install --user $args"
		;;
	aur)
		# The arch AUR lane: the helper is what a human would run.
		printf '%s\n' "${AUR_HELPER:-paru} -S $args"
		;;
	brew)
		printf '%s\n' "brew install $args"
		;;
	zig-zls-pair)
		printf '%s\n' "brew install zls zig@<zls-version>  # version-locked pair (zls ceiling)"
		;;
	rustup)
		printf '%s\n' "https://rustup.rs/"
		;;
	rustup-component)
		printf '%s\n' "rustup component add $args"
		;;
	python-unversioned)
		printf '%s\n' "ln -s \$(command -v python3) /usr/local/bin/python"
		;;
	none)
		# The exec arm's whole job is to return 1 (no step). No command here
		# either — the row exists so the two tables stay diffable.
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
	printf '%s\n' "${GREEN}${BOLD}${PROJECT} installation complete!${NC}"
	printf '\n'
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
		printf '%s\n' "$text"
	done
	printf '\n'
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
		else
			# XDG_RUNTIME_DIR last mile (rationale in xdg_runtime_fix_cmd):
			# only the parent shell can export the fix — queued BEFORE the
			# source line so tmux started from this shell inherits it.
			# Empty fix logs nothing: silence is the healthy-path signal.
			local xdg_fix
			xdg_fix="$(xdg_runtime_fix_cmd)"
			if [ -n "$xdg_fix" ]; then
				if inject_tty "$xdg_fix"; then
					printf '%s\n' "  ${GREEN}Injected XDG_RUNTIME_DIR fix into the current terminal.${NC}"
				else
					printf '%s\n' "    ${CYAN}${xdg_fix}${NC}"
				fi
			fi
			if inject_tty "source ${env_file}"; then
				printf '%s\n' "  ${GREEN}Injected 'source ${env_file}' into the current terminal.${NC}"
			else
				printf '%s\n' "  ${YELLOW}New PATH takes effect in NEW shells. To use it in this terminal now:${NC}"
				printf '%s\n' "    ${CYAN}source ${env_file}${NC}    ${YELLOW}# or simply: ${CYAN}exec \$SHELL${NC}"
			fi
		fi
		printf '\n'
	fi
}
