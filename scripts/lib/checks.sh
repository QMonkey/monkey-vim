# monkey-scripts/lib/checks.sh — dependency CHECK side: spec model, probes,
# and the checkhealth display sections. Sourced by scripts/checkhealth.sh
# (via lib/bootstrap.sh EXTRA_LIBS).
#
# A dependency is one spec string:
#   id|check|desc|install|ver_regex|fallback|token|group
#     id        binary (or sentinel) name; recorded in MISSING_* and used
#               for package-name lookups
#     check     bin (default) | ext | anyof:a b c | anyofext:a b c |
#               ver:MIN | ver:MIN!bad bad (versions that pass MIN but are
#               known broken, exact match on the extracted version) |
#               py:module (Python module probe — pylsp plugins ship no
#               binary; import the module instead) |
#               match:bin (companion whose major.minor version must equal
#               <bin>'s — zls vs zig; master missing ⇒ pass)
#     desc      printed text (default: id)
#     install   pkg (default) | pkg:name,name | npm:x | go:x | cargo:x |
#               pip:x | brew:x | rustup | rustup-component:x |
#               python-unversioned | zig-zls-pair | none
#     ver_regex version regex (default: [0-9]+\.[0-9]+)
#     fallback  binary accepted instead of id (warn, not fail)
#     token     version output must mention this (warn only)
#     group     optional-checks display group (empty = ungrouped)
#
# Sections of REQUIRED_CHECKS:
#   @header|Title   bold section title (a blank line precedes every title
#                   after the first section; the section is closed by a blank)
#   @note|text      indented note line under the current title
#   @clipboard      clipboard check (CHECK_CLIPBOARD=required)
#   @config         "Config files" section (CONFIG_PHASE=required)
#
# The INSTALL machinery over these specs lives elsewhere: install_strategy /
# install_strategy_step in lib/pkg.sh, the missing-installer passes in
# lib/missing.sh, the clipboard domain in lib/clipboard.sh.

REQUIRED_FAILURES=0
MISSING_REQUIRED=()
MISSING_RECOMMENDED=()
MISSING_OPTIONAL=()

parse_spec() {
	# Plain heredoc, NOT a herestring (`<<<`): legacy sh.vim misparses `<<<`
	# and breaks highlighting for the rest of the file.
	IFS='|' read -r SPEC_ID SPEC_CHECK SPEC_DESC SPEC_INSTALL SPEC_VER_RE SPEC_FALLBACK SPEC_TOKEN SPEC_GROUP <<EOF
$1
EOF
	SPEC_CHECK="${SPEC_CHECK:-bin}"
	SPEC_DESC="${SPEC_DESC:-$SPEC_ID}"
	SPEC_INSTALL="${SPEC_INSTALL:-pkg}"
}

# /usr/lib* lookup for D-Bus services and polkit agents that live outside PATH.
ext_paths_ok() {
	local b="$1" p
	for p in "/usr/lib/$b" "/usr/libexec/$b" "/usr/lib/policykit-1-gnome/$b" "/usr/lib/polkit-gnome/$b"; do
		[ -x "$p" ] && return 0
	done
	return 1
}

# Availability of the parsed spec; sets PROBE_MATCH to what matched.
probe_spec() {
	parse_spec "$1"
	PROBE_MATCH=""
	local b
	case "$SPEC_CHECK" in
	anyof:* | anyofext:*)
		local list="${SPEC_CHECK#*:}"
		for b in $list; do
			if have_native_cmd "$b"; then
				PROBE_MATCH="$b"
				return 0
			fi
			case "$SPEC_CHECK" in
			anyofext:*)
				if ext_paths_ok "$b"; then
					PROBE_MATCH="$b"
					return 0
				fi
				;;
			esac
		done
		return 1
		;;
	ext)
		if have_native_cmd "$SPEC_ID"; then
			PROBE_MATCH="$SPEC_ID"
			return 0
		fi
		ext_paths_ok "$SPEC_ID" || return 1
		PROBE_MATCH="$SPEC_ID"
		return 0
		;;
	ver:*)
		# Version detectability IS the probe (a rustup shim for an
		# uninstalled component is present but answers nothing). Mirrors
		# check_version_spec's one leniency: a declared fallback accepts an
		# unparsable version (binary there, nothing more to say).
		have_native_cmd "$SPEC_ID" || return 1
		local ver
		ver=$(extract_version "$SPEC_ID" "${SPEC_VER_RE:-$DEFAULT_VER_RE}")
		if [ -z "$ver" ]; then
			[ -n "$SPEC_FALLBACK" ] && return 0
			return 1
		fi
		return 0
		;;
	py:*)
		# pylsp plugins (python-lsp-black & friends) ship NO binary — they
		# are Python modules loaded through pylsp's plugin entry points, so
		# a `bin` check would fail forever on an otherwise working install.
		# Probe by importing the module with the same interpreter the
		# distro's pylsp runs under. Requires python3; absent python3 means
		# the plugin cannot work either way.
		if have_native_cmd python3 && python3 -c "import ${SPEC_CHECK#py:}" >/dev/null 2>&1; then
			PROBE_MATCH="${SPEC_CHECK#py:}"
			return 0
		fi
		return 1
		;;
	match:*)
		# Companion tools whose major.minor MUST track a master tool's
		# version (observed: zls 0.16 refuses to serve zig 0.17 outright —
		# presence alone lies, the binary answers --version and then dies).
		# Probe version AGREEMENT instead. The master itself being missing
		# is not the companion's failure — pass here; the master's own spec
		# reports it (avoids double-reporting one root cause).
		local master="${SPEC_CHECK#match:}" my_ver master_ver
		have_native_cmd "$SPEC_ID" || return 1
		if ! have_native_cmd "$master"; then
			PROBE_MATCH="$SPEC_ID"
			return 0
		fi
		my_ver=$(extract_version "$SPEC_ID" "${SPEC_VER_RE:-$DEFAULT_VER_RE}")
		master_ver=$(extract_version "$master" "${SPEC_VER_RE:-$DEFAULT_VER_RE}")
		if [ -n "$my_ver" ] && [ -n "$master_ver" ] && [ "$my_ver" = "$master_ver" ]; then
			PROBE_MATCH="$SPEC_ID"
			return 0
		fi
		return 1
		;;
	*)
		have_native_cmd "$SPEC_ID"
		;;
	esac
}

# One required-check failure: count it. print_summary decides the exit
# status off REQUIRED_FAILURES; shared by record_missing (required mode) and
# config.sh's link checks (which have no id to install).
count_required_failure() {
	REQUIRED_FAILURES=$((REQUIRED_FAILURES + 1))
}

record_missing() {
	local mode="$1" id="$2"
	case "$mode" in
	required)
		count_required_failure
		[ "$id" = "-" ] && return 0 # informational: nothing to install
		MISSING_REQUIRED+=("$id")
		;;
	recommended)
		MISSING_RECOMMENDED+=("$id")
		;;
	optional)
		MISSING_OPTIONAL+=("$id")
		;;
	esac
}

check_version_spec() {
	local mode="$1" ver
	# "ver:MIN" or "ver:MIN!bad bad" — the exclusion list names versions that
	# satisfy the minimum but are KNOWN BROKEN (e.g. tmux 3.7–3.7b). Exact
	# string match on the extracted version.
	local vspec="${SPEC_CHECK#ver:}"
	local min="${vspec%%!*}" bad=""
	[ "$vspec" != "$min" ] && bad="${vspec#*!}"
	if ! have_native_cmd "$SPEC_ID"; then
		if [ -n "$SPEC_FALLBACK" ] && have_native_cmd "$SPEC_FALLBACK"; then
			warn "${SPEC_DESC} binary not found, but ${SPEC_FALLBACK} is available"
			return 0
		fi
		fail "${SPEC_DESC} (${SPEC_ID} not found)"
		record_missing "$mode" "$SPEC_INSTALL_ID"
		return 1
	fi
	ver=$(extract_version "$SPEC_ID" "${SPEC_VER_RE:-$DEFAULT_VER_RE}")
	if [ -z "$ver" ]; then
		if [ -n "$SPEC_FALLBACK" ]; then
			# E.g. Hyprland: binary present, version string unparsable — not fatal.
			ok "${SPEC_DESC} (version string unparsable)"
			return 0
		fi
		fail "${SPEC_DESC} (could not detect version)"
		record_missing "$mode" "$SPEC_INSTALL_ID"
		return 1
	fi
	local v
	for v in $bad; do
		if [ "$ver" = "$v" ]; then
			fail "${SPEC_DESC} ${ver} (known broken — need >= ${min}, excluding: ${bad})"
			record_missing "$mode" "$SPEC_INSTALL_ID"
			return 1
		fi
	done
	if version_ge "$ver" "$min"; then
		ok "${SPEC_DESC} ${ver}"
		if [ -n "$SPEC_TOKEN" ]; then
			if "$SPEC_ID" --version 2>/dev/null | grep -qi -- "$SPEC_TOKEN"; then
				ok "${SPEC_TOKEN} config support built in"
			else
				warn "version string does not mention ${SPEC_TOKEN} — check that your build supports it"
			fi
		fi
		return 0
	fi
	fail "${SPEC_DESC} ${ver} (need >= ${min})"
	record_missing "$mode" "$SPEC_INSTALL_ID"
	return 1
}

# Dispatch an "@call|fn" marker to a project-defined check function.
_run_call_hook() {
	local fn="$1"
	if declare -F "$fn" >/dev/null 2>&1; then
		"$fn"
	else
		warn "unknown check hook: $fn"
	fi
}

# One dependency line. Sets SPEC_* globals for the caller.
check_spec() {
	local spec="$1" mode="${2:-required}"
	parse_spec "$spec"
	# "-" disables installation bookkeeping (informational but fatal).
	SPEC_INSTALL_ID="$SPEC_ID"
	[ "$SPEC_INSTALL" = "none" ] && SPEC_INSTALL_ID="-"
	case "$SPEC_CHECK" in
	ver:*)
		check_version_spec "$mode"
		return
		;;
	esac
	if probe_spec "$spec"; then
		case "$SPEC_CHECK" in
		anyof:* | anyofext:* | ext)
			ok "${SPEC_DESC} (${PROBE_MATCH})"
			;;
		*)
			ok "${SPEC_DESC}"
			;;
		esac
		return 0
	fi
	fail "${SPEC_DESC}"
	record_missing "$mode" "$SPEC_INSTALL_ID"
	return 1
}

# Look up the spec of an id across every dependency list. EXTRA_SPECS holds
# specs whose CHECK is done by a project hook (@call) but whose INSTALL is
# described here — they are installed, never listed.
find_spec() {
	local id="$1" e
	for e in ${EXTRA_SPECS[@]+"${EXTRA_SPECS[@]}"} ${REQUIRED_CHECKS[@]+"${REQUIRED_CHECKS[@]}"} ${RECOMMENDED_CHECKS[@]+"${RECOMMENDED_CHECKS[@]}"} ${OPTIONAL_CHECKS[@]+"${OPTIONAL_CHECKS[@]}"}; do
		case "$e" in @*) continue ;; esac
		parse_spec "$e"
		if [ "$SPEC_ID" = "$id" ]; then
			printf '%s' "$e"
			return 0
		fi
	done
	return 1
}

# parse_spec for an id: resolve through find_spec, fall back to the bare id
# as its own spec. Sets the SPEC_* globals plus SPEC_RAW (the full spec
# string — install_strategy takes a spec, not an id).
load_spec_for() {
	local spec
	spec=$(find_spec "$1") || spec="$1"
	parse_spec "$spec"
	SPEC_RAW="$spec"
}

# ──────────────────────── sections ────────────────────────
check_main_version() {
	[ -n "${MAIN_VERSION:-}" ] || return 0
	parse_spec "$MAIN_VERSION"
	print_bold_header "${MAIN_VERSION_TITLE:-$SPEC_DESC}"
	check_spec "$MAIN_VERSION" required || true
	echo ""
}

# REQUIRED_CHECKS is an ordered, sectioned list:
#   @header|Title   bold section title (a blank line precedes every title
#                   after the first section)
#   @note|text      indented note under the current title
#   @config         the "Config files" section (CONFIG_PHASE=required)
#   @clipboard      clipboard check (CHECK_CLIPBOARD=required)
#   @call|fn        project-defined check function (print your own line with
#                   ok/warn/fail and record with "record_missing required id")
#   anything else    one dependency spec
# A blank line closes each section.
run_required_checks() {
	REQUIRED_FAILURES=0
	MISSING_REQUIRED=()
	check_main_version
	local entry group_open=0 config_placed=0
	for entry in ${REQUIRED_CHECKS[@]+"${REQUIRED_CHECKS[@]}"}; do
		case "$entry" in
		@header\|*)
			[ "$group_open" = 1 ] && echo ""
			print_bold_header "${entry#@header|}"
			group_open=1
			;;
		@note\|*)
			echo "  ${entry#@note|}"
			;;
		@call\|*)
			_run_call_hook "${entry#@call|}"
			;;
		@clipboard)
			if [ "${CHECK_CLIPBOARD:-}" = "required" ]; then
				check_clipboard_required
			fi
			;;
		@config)
			[ "$group_open" = 1 ] && echo ""
			check_config_files
			group_open=0
			config_placed=1
			;;
		@*) ;;
		*)
			check_spec "$entry" required || true
			;;
		esac
	done
	[ "$group_open" = 1 ] && echo ""
	if [ "${CONFIG_PHASE:-end}" = "required" ] && [ "$config_placed" = 0 ]; then
		# No "@config" marker in the list: place the section here.
		# check_config_files prints its own trailing blank.
		check_config_files
	fi
	return 0
}

check_recommended_tools() {
	[ ${#RECOMMENDED_CHECKS[@]} -gt 0 ] || return 0
	print_bold_header "Recommended tools"
	[ -n "${RECOMMENDED_NOTE:-}" ] && echo "  $RECOMMENDED_NOTE"
	local entry
	for entry in "${RECOMMENDED_CHECKS[@]}"; do
		# "@call|fn" — same project hook as in REQUIRED_CHECKS (monkey-vim's
		# Debian bat → batcat alias).
		case "$entry" in
		@call\|*)
			_run_call_hook "${entry#@call|}"
			;;
		*)
			check_spec "$entry" recommended || true
			;;
		esac
	done
	echo ""
}

# Optional tools are OPTIONAL_CHECKS specs like any other; the optional 8th
# spec field groups them (a group change prints a bold, indented group name
# and closes the previous group with a blank line). A missing optional tool
# never touches REQUIRED_FAILURES — it degrades features, nothing more.
check_optional_tools() {
	[ ${#OPTIONAL_CHECKS[@]} -gt 0 ] || return 0
	print_bold_header "${OPTIONAL_SECTION_TITLE:-Optional tools}"
	[ -n "${OPTIONAL_SECTION_NOTE:-}" ] && echo "  $OPTIONAL_SECTION_NOTE"
	local entry group="" prev="" bin
	for entry in "${OPTIONAL_CHECKS[@]}"; do
		parse_spec "$entry"
		group="$SPEC_GROUP"
		if [ "$group" != "$prev" ]; then
			[ -n "$prev" ] && echo "" # close the previous group
			if [ -n "$group" ]; then
				[ -z "$prev" ] && echo "" # header/note → first group
				echo -e "  ${BOLD}${group}${NC}"
			fi
			prev="$group"
		fi
		if [ -n "$group" ]; then
			bin="$SPEC_ID"
			if probe_spec "$entry"; then
				ok "  ${bin}"
			else
				fail "  ${bin}  ${NC}$(optional_hint "$bin")"
				MISSING_OPTIONAL+=("$bin")
			fi
		else
			check_spec "$entry" optional || true
		fi
	done
	# Section spacer; tmux's original prints none (its optional list is
	# immediately followed by Terminal capabilities).
	if [ "${OPTIONAL_TRAILING_BLANK:-1}" = 1 ]; then
		echo ""
	fi
	return 0
}

# Any truecolor hint in TERM (unanchored, as in the original scripts).
_term_truecolor() {
	[[ "${TERM:-}" =~ (256color|tmux|screen|alacritty|kitty|wezterm|xterm-kitty) ]]
}

check_terminal_caps() {
	[ "${CHECK_TERMINAL_CAPS:-0}" = 1 ] || return 0
	print_bold_header "Terminal capabilities"
	# Two probes, both present in the original scripts:
	#   term (default) — "TERM=… (true color capable)", any truecolor hint counts
	#   colorterm      — report COLORTERM itself when it says truecolor
	if [ "${TERMCAPS_STYLE:-term}" = colorterm ] && [ -n "${COLORTERM:-}" ]; then
		ok "COLORTERM=${COLORTERM}"
	elif [ -n "${COLORTERM:-}" ] || _term_truecolor; then
		ok "TERM=${TERM} (true color capable)"
	else
		warn "TERM=${TERM} — true color may not work"
	fi
	case "${CHECK_CLIPBOARD:-}" in
	warn) check_clipboard_warn ;;
	display) check_clipboard_display ;;
	esac
	if [ "${CHECK_LANG:-0}" = 1 ]; then
		if [[ "${LANG:-}" == *".UTF-8" || "${LANG:-}" == *".utf8" ]]; then
			ok "LANG=${LANG}"
		else
			warn "LANG=${LANG} (UTF-8 recommended)"
		fi
	fi
	echo ""
}
