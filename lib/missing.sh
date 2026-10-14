# monkey-scripts/lib/missing.sh — the missing-dependency INSTALLER: turn the
# MISSING_* lists of lib/checks.sh into package-manager transactions.
# Sourced by scripts/checkhealth.sh (via lib/bootstrap.sh EXTRA_LIBS), AFTER
# lib/checks.sh (spec model / probes) and lib/pkg.sh (install_pkg, install
# strategies, get_install_hint).

# ──────────────────────── install missing ────────────────────────
# Dedupe package names, order kept: two binaries can map to the SAME package
# and the "Run:" hint would then repeat it. Pattern match, not `local -A`:
# macOS still ships bash 3.2 (same reason pkg_name is a case function).
dedupe_pkgs() {
	local -a out=()
	local p
	for p in "$@"; do
		[ -n "$p" ] || continue
		case " ${out[*]-} " in *" $p "*) continue ;; esac
		out+=("$p")
	done
	echo "${out[*]-}"
}

# Collect the ids whose spec install strategy is plain "pkg" into
# _PKG_BATCH_IDS / _PKG_BATCH_NAMES — they batch into ONE package-manager
# call; strategies with side effects (npm/go/pip/…) stay per-tool. Shared by
# the required / recommended / optional install passes.
_collect_pkg_batch() {
	_PKG_BATCH_IDS=()
	_PKG_BATCH_NAMES=()
	local id
	for id in "$@"; do
		load_spec_for "$id"
		if [ "${SPEC_INSTALL:-pkg}" = "pkg" ]; then
			_PKG_BATCH_IDS+=("$id")
			_PKG_BATCH_NAMES+=("$(pkg_name "$id")")
		fi
	done
}

# ✓/✗ line for one install outcome; the hint names the human command
# (usually a package name, sometimes a URL). Shared by every reporting site
# of the installer passes below.
report_install_ok() { echo -e "  ${GREEN}✓ $1 installed${NC}"; }
report_install_fail() {
	echo -e "  ${RED}✗ failed to install $1${NC}"
	echo -e "    hint: $(get_install_hint "$2")"
}

# Default required re-probe: installed = resolves on PATH or a known ext path.
_reprobe_default() {
	have_native_cmd "$1" || ext_paths_ok "$1"
}

# Project-level re-probe (sway/hyprland upstream style): one "installed" /
# "still missing" line per entry of REQUIRED_REPROBE_LIST, probed via
# REQUIRED_REPROBE_FN (default _reprobe_default) and displayed via
# REQUIRED_NAME_FN. Projects without the list keep the run_required_checks
# behaviour (_required_tail_checks) instead.
_required_reprobe() {
	local rb probe_fn name_fn label
	probe_fn=${REQUIRED_REPROBE_FN:-_reprobe_default}
	name_fn=${REQUIRED_NAME_FN:-}
	MISSING_REQUIRED=()
	REQUIRED_FAILURES=0
	for rb in ${REQUIRED_REPROBE_LIST[@]+"${REQUIRED_REPROBE_LIST[@]}"}; do
		case "$rb" in
		@*) continue ;;
		*\|*)
			# A full spec entry: probe and label through the spec itself —
			# REQUIRED_REPROBE_LIST=("${REQUIRED_CHECKS[@]}") then needs no
			# parallel name/availability tables.
			parse_spec "$rb"
			if probe_spec "$rb"; then
				ok "$SPEC_DESC installed"
			else
				MISSING_REQUIRED+=("$SPEC_ID")
				fail "$SPEC_DESC still missing"
				count_required_failure
			fi
			;;
		*)
			label="$rb"
			if [ -n "$name_fn" ]; then label=$("$name_fn" "$rb"); fi
			if "$probe_fn" "$rb"; then
				ok "$label installed"
			else
				MISSING_REQUIRED+=("$rb")
				fail "$label still missing"
				count_required_failure
			fi
			;;
		esac
	done
	if [ ${#MISSING_REQUIRED[@]} -eq 0 ]; then
		echo -e "${GREEN}All required tools now available.${NC}"
	elif [ -n "${REQUIRED_MANUAL_HINT:-}" ]; then
		echo -e "${RED}${REQUIRED_MANUAL_HINT}${NC}"
	fi
}

# Post-install re-check when there is no reprobe list: rerun the required
# checks and turn whatever is still missing into a "Run:" hint.
_required_tail_checks() {
	run_required_checks
	if [ ${#MISSING_REQUIRED[@]} -eq 0 ]; then
		echo -e "${GREEN}All required tools now available.${NC}"
	else
		local -a hint_pkgs=()
		local id
		for id in "${MISSING_REQUIRED[@]}"; do
			hint_pkgs+=("$(pkg_name "$id")")
		done
		echo -e "${RED}Run: $(get_install_hint "$(dedupe_pkgs ${hint_pkgs[@]+"${hint_pkgs[@]}"})")${NC}"
	fi
}

# One installer pass over a list of missing ids — the shared skeleton of the
# required / recommended / optional steps. Plain "pkg" strategies batch into
# ONE package-manager transaction; side-effecting strategies (npm/go/pip/
# brew/…) install per tool. The mode only switches the reporting style:
#   required    — batch failure tolerated (the reprobe/tail reports it)
#   recommended — batch reports "Done." / "Failed. Run: ...", per-tool ✓/✗
#   optional    — batch re-probes per binary; per-tool installs may delegate
#                 to a project-defined install_optional_bin hook
_install_missing_pass() {
	local mode="$1" title="$2"
	shift 2
	local -a missing=("$@")
	[ ${#missing[@]} -gt 0 ] || return 0
	echo -e "${YELLOW}${title}: ${missing[*]}...${NC}"
	_collect_pkg_batch "${missing[@]}"
	local id
	if [ ${#_PKG_BATCH_NAMES[@]} -gt 0 ]; then
		case "$mode" in
		required)
			install_pkg ${_PKG_BATCH_NAMES[@]+"${_PKG_BATCH_NAMES[@]}"} || true
			;;
		recommended)
			if install_pkg ${_PKG_BATCH_NAMES[@]+"${_PKG_BATCH_NAMES[@]}"}; then
				echo -e "${GREEN}Done.${NC}"
			else
				echo -e "${RED}Failed. Run: $(get_install_hint "$(dedupe_pkgs ${_PKG_BATCH_NAMES[@]+"${_PKG_BATCH_NAMES[@]}"})")${NC}"
			fi
			;;
		optional)
			if install_pkg ${_PKG_BATCH_NAMES[@]+"${_PKG_BATCH_NAMES[@]}"}; then
				for id in "${_PKG_BATCH_IDS[@]}"; do
					load_spec_for "$id"
					if probe_spec "$SPEC_RAW"; then
						report_install_ok "$id"
					else
						report_install_fail "$id" "$id"
					fi
				done
			else
				for id in "${_PKG_BATCH_IDS[@]}"; do
					report_install_fail "$id" "$id"
				done
			fi
			;;
		esac
	fi
	for id in "${missing[@]}"; do
		load_spec_for "$id"
		[ "${SPEC_INSTALL:-pkg}" = "pkg" ] && continue # batched above
		case "$mode" in
		required)
			info "installing ${id}..."
			install_strategy "$SPEC_RAW" || warn "could not install ${id}"
			;;
		recommended)
			if install_strategy "$SPEC_RAW"; then
				echo -e "  ${GREEN}✓ ${id} available${NC}"
			else
				report_install_fail "$id" "$(pkg_name "$id")"
			fi
			;;
		optional)
			echo -e "  ${YELLOW}→ installing ${id}...${NC}"
			local installed_ok=true
			# A project may carry upstream's per-binary install table verbatim
			# (monkey-nvim / monkey-vim); otherwise run the spec strategy.
			if declare -F install_optional_bin >/dev/null 2>&1; then
				install_optional_bin "$id" || installed_ok=false
			elif ! install_strategy "$SPEC_RAW"; then
				installed_ok=false
			fi
			if $installed_ok; then
				report_install_ok "$id"
			else
				report_install_fail "$id" "$id"
			fi
			;;
		esac
	done
}

install_missing_required() {
	${INSTALL_MODE:-false} || return 0
	[ ${#MISSING_REQUIRED[@]} -gt 0 ] || return 0
	_install_missing_pass required "Installing" ${MISSING_REQUIRED[@]+"${MISSING_REQUIRED[@]}"}
	# [*] in the guard, never [@]: an UNSET array's @+ expansion is zero
	# words, so `[ -n "${arr[@]+SET}" ]` degenerates to always-true `[ -n ]`.
	if [ -n "${REQUIRED_REPROBE_LIST[*]+SET}" ] && [ ${#REQUIRED_REPROBE_LIST[*]} -gt 0 ]; then
		_required_reprobe
	else
		_required_tail_checks
	fi
	echo ""
}

install_missing_recommended() {
	${INSTALL_MODE:-false} || return 0
	[ ${#MISSING_RECOMMENDED[@]} -gt 0 ] || return 0
	_install_missing_pass recommended "Installing" ${MISSING_RECOMMENDED[@]+"${MISSING_RECOMMENDED[@]}"}
	echo ""
}

# Probes OPTIONAL_CHECKS itself instead of trusting MISSING_OPTIONAL: the
# step runs BEFORE the listing, so the listing's verdict is not available.
install_missing_optional() {
	${INSTALL_MODE:-false} || return 0
	[ "${INSTALL_OPTIONAL:-0}" = 1 ] || return 0
	local -a missing=()
	local e
	for e in ${OPTIONAL_CHECKS[@]+"${OPTIONAL_CHECKS[@]}"}; do
		parse_spec "$e"
		probe_spec "$e" || missing+=("$SPEC_ID")
	done
	if [ ${#missing[@]} -eq 0 ]; then
		if [ -n "${OPTIONAL_ALL_PRESENT_MSG:-}" ]; then
			echo -e "${GREEN}${OPTIONAL_ALL_PRESENT_MSG}${NC}"
			echo ""
		fi
		return 0
	fi
	_install_missing_pass optional "${OPTIONAL_INSTALL_TITLE:-Installing optional tools}" ${missing[@]+"${missing[@]}"}
	# Optional trailing summary for projects whose original printed one
	# after a non-empty install batch (monkey-nvim, monkey-vim).
	[ -n "${OPTIONAL_DONE_MSG:-}" ] && echo -e "${GREEN}${OPTIONAL_DONE_MSG}${NC}"
	echo ""
}
