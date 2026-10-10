# monkey-scripts/lib/checks.sh — dependency checks for checkhealth.sh.
#
# Sourced by scripts/checkhealth.sh only.
#
# A dependency is one spec string:
#   id|check|desc|install|ver_regex|fallback|token
#     id        binary (or sentinel) name; recorded in MISSING_* and used
#               for package-name lookups
#     check     bin (default) | ext | anyof:a b c | anyofext:a b c |
#               ver:MIN | ver:MIN!bad bad (versions that pass MIN but are
#               known broken, exact match on the extracted version)
#     desc      printed text (default: id)
#     install   pkg (default) | pkg:name,name | npm:x | go:x | cargo:x |
#               pip:x | brew:x | rustup | rustup-component:x |
#               python-unversioned | none
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
		have_native_cmd "$SPEC_ID"
		return
		;;
	*)
		have_native_cmd "$SPEC_ID"
		;;
	esac
}

record_missing() {
	local mode="$1" id="$2"
	case "$mode" in
	required)
		REQUIRED_FAILURES=$((REQUIRED_FAILURES + 1))
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
	ver=$(extract_version "$SPEC_ID" "${SPEC_VER_RE:-[0-9]+\.[0-9]+}")
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

# ──────────────────────── install strategies ────────────────────────
# Runs one strategy step; returns non-zero when the step failed.
_strategy_step() {
	local kind="$1" args="$2" spec="$3"
	case "$kind" in
	pkg)
		if [ -n "$args" ]; then
			# args are binaries, not package names: the distro package is
			# whatever pkg_name maps them to (cc → gcc, then clang).
			local -a names=() b
			for b in $args; do
				names+=("$(pkg_name "$b")")
			done
			install_pkg "${names[@]}"
		else
			install_pkg "$(pkg_name "$SPEC_ID")"
		fi
		;;
	npm)
		ensure_npm || return 1
		npm_install_g $args
		;;
	go)
		go_install $args
		;;
	cargo)
		ensure_rust || return 1
		retry -t 1800 -s "cargo install $args" cargo install $args
		;;
	pip)
		# ensure_pip first: the fallback dies with command-not-found when
		# pip3 is missing (Leap 16). stderr stays visible — a silently
		# swallowed pip error is what made the Leap 16 pylsp failure
		# undiagnosable.
		ensure_pip || return 1
		retry -t 1800 -s "pip3 install $args" sudo_cmd pip3 install $args ||
			retry -t 1800 -s "pip3 install $args" pip3 install $args
		;;
	brew)
		have_native_cmd brew || return 1
		# zig/zls pull LLVM and marksman pulls the .NET runtime as formula
		# dependencies — installs that dwarf a normal bottle.
		local bt=1800
		case "$args" in
		zig | zls | marksman) bt=7200 ;;
		esac
		brew_install_retry "$bt" "brew install $args" $args
		;;
	rustup)
		ensure_rust
		;;
	rustup-component)
		ensure_rust || return 1
		retry -t 1800 -s "rustup component add $args" rustup component add $args
		;;
	python-unversioned)
		install_python_for_gtags
		;;
	none)
		return 1
		;;
	*)
		install_pkg "$kind${args:+:$args}"
		;;
	esac
}

# Split one comma-separated strategy step off <rest> (e.g. "pkg,pip:x"):
# sets _STRATEGY_KIND / _STRATEGY_ARGS / _STRATEGY_REST (what remains after
# the step) and returns 1 when the list is exhausted. Shared by
# install_strategy (execution) and optional_hint (hint derivation).
_strategy_split() {
	[ -n "$1" ] || return 1
	local step="${1%%,*}"
	_STRATEGY_KIND="${step%%:*}"
	_STRATEGY_ARGS=""
	[ "$step" != "$_STRATEGY_KIND" ] && _STRATEGY_ARGS="${step#*:}"
	if [ "$1" = "$step" ]; then
		_STRATEGY_REST=""
	else
		_STRATEGY_REST="${1#*,}"
	fi
}

# Install everything a spec's strategy asks for, step by step, stopping as
# soon as the dependency actually probes positive.
install_strategy() {
	local spec="$1" strategy rest
	parse_spec "$spec"
	strategy="$SPEC_INSTALL"
	[ -n "$strategy" ] || strategy="pkg"
	[ "$strategy" = "none" ] && return 1
	rest="$strategy"
	while _strategy_split "$rest"; do
		rest="$_STRATEGY_REST"
		_strategy_step "$_STRATEGY_KIND" "$_STRATEGY_ARGS" "$spec" || true
		# The step may have just CREATED a bin dir (go/cargo install into
		# GOPATH[0]/bin, CARGO_HOME/bin, npm prefix/bin) — re-seed so the
		# probe below can actually resolve the freshly installed binary.
		if probe_spec "$spec"; then
			return 0
		fi
	done
	return 1
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

check_terminal_caps() {
	[ "${CHECK_TERMINAL_CAPS:-0}" = 1 ] || return 0
	print_bold_header "Terminal capabilities"
	# Two probes, both present in the original scripts:
	#   term (default) — "TERM=… (true color capable)", any truecolor hint counts
	#   colorterm      — report COLORTERM itself when it says truecolor
	if [ "${TERMCAPS_STYLE:-term}" = colorterm ]; then
		if [ -n "${COLORTERM:-}" ]; then
			ok "COLORTERM=${COLORTERM}"
		elif [[ "${TERM:-}" =~ (256color|tmux|screen|alacritty|kitty|wezterm|xterm-kitty) ]]; then
			ok "TERM=${TERM} (true color capable)"
		else
			warn "TERM=${TERM} — true color may not work"
		fi
	elif [ -n "${COLORTERM:-}" ] || [[ "${TERM:-}" =~ (256color|tmux|screen|alacritty|kitty|wezterm|xterm-kitty) ]]; then
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

# ──────────────────────── clipboard ────────────────────────
# What the current session needs: pbcopy/pbpaste (built in) on macOS,
# wl-copy/wl-paste on Wayland, xclip or xsel on X11. Prints "ok",
# "missing <package>" or "n/a" (no graphical session — SSH, console — where a
# system clipboard cannot be reached anyway).
clipboard_state() {
	if [ "$OS" = "macos" ]; then
		echo ok
	elif [ "${XDG_SESSION_TYPE:-}" = wayland ] || [ -n "${WAYLAND_DISPLAY:-}" ]; then
		if have_native_cmd wl-copy; then
			echo ok
		else
			echo "missing wl-clipboard"
		fi
	elif [ "${XDG_SESSION_TYPE:-}" = x11 ] || [ -n "${DISPLAY:-}" ]; then
		if have_native_cmd xclip || have_native_cmd xsel; then
			echo ok
		else
			echo "missing xclip"
		fi
	else
		echo n/a
	fi
}

# Required clipboard check (tmux-yank): WSL uses the Windows clip.exe
# through interop — have_native_cmd must NOT be applied to it.
check_clipboard_required() {
	if [ "$OS" = "macos" ]; then
		check_spec "pbcopy|bin|pbcopy (macOS built-in)|none" || true
	elif is_wsl; then
		if command -v clip.exe &>/dev/null; then
			ok "clip.exe (WSL)"
			if [ -r /proc/sys/fs/binfmt_misc/WSLInterop ] &&
				[ "$(head -1 /proc/sys/fs/binfmt_misc/WSLInterop 2>/dev/null)" = "enabled" ]; then
				ok "WSL interop (binfmt WSLInterop enabled)"
			else
				warn "WSL interop broken — .exe calls (yank/extrakto/fzf-url) will fail"
				echo -e "         See README Troubleshooting: re-register /proc/sys/fs/binfmt_misc/WSLInterop"
			fi
		else
			fail "clip.exe (WSL)"
			# Upstream hands clip.exe to the package manager anyway: the
			# install step attempts it and reports what is still missing.
			record_missing required "clip.exe"
		fi
	else
		# tmux-yank prefers wl-copy on Wayland (its helpers check wl-copy
		# BEFORE xsel); under XWayland xclip works too, so any one of the
		# three suffices.
		local tool="" t hint="xclip"
		for t in wl-copy xclip xsel; do
			if have_native_cmd "$t"; then
				tool="$t"
				break
			fi
		done
		[ -n "${WAYLAND_DISPLAY:-}" ] && hint="wl-clipboard"
		if [ -n "$tool" ]; then
			ok "${tool} (clipboard)"
		else
			fail "xclip / xsel / wl-copy (Wayland: install wl-clipboard)"
			record_missing required "$hint"
		fi
	fi
}

# A display server alone is not enough: the editor needs an actual clipboard
# provider binary (wl-copy on Wayland, xclip/xsel on X11, pbcopy on macOS).
check_clipboard_warn() {
	local cb_state cb_pkg
	cb_state=$(clipboard_state)
	case "$cb_state" in
	ok) ok "Clipboard support available" ;;
	n/a) warn "No display server — clipboard may be unavailable" ;;
	missing*)
		cb_pkg="${cb_state#missing }"
		warn "Clipboard provider missing (${cb_pkg}) — install with: $(get_install_hint "$cb_pkg")"
		;;
	esac
}

check_clipboard_display() {
	if [ -n "${DISPLAY:-}" ] || [ -n "${WAYLAND_DISPLAY:-}" ] || [ "$OS" = "macos" ]; then
		ok "Clipboard support available"
	else
		warn "No display server — clipboard may be unavailable"
	fi
}

install_clipboard() {
	# install_pkg is a no-op returning failure outside --install mode; skip
	# entirely so check-only runs don't report a bogus install failure.
	${INSTALL_MODE:-false} || return 0
	[ "${CHECK_CLIPBOARD:-}" = "warn" ] || return 0
	local state pkg
	state=$(clipboard_state)
	case "$state" in
	ok | n/a) return 0 ;;
	missing*)
		pkg="${state#missing }"
		echo -e "  ${YELLOW}→ installing clipboard provider ${pkg}...${NC}"
		if install_pkg "$pkg"; then
			echo -e "  ${GREEN}✓ ${pkg} installed${NC}"
		else
			echo -e "  ${RED}✗ failed to install ${pkg}${NC}"
			echo -e "    hint: $(get_install_hint "$pkg")"
			return 1
		fi
		;;
	esac
}

# ──────────────────────── install missing ────────────────────────
# Dedupe package names, order kept: two binaries can map to the SAME package
# and the "Run:" hint would then repeat it.
dedupe_pkgs() {
	local -A seen=()
	local -a out=()
	local p
	for p in "$@"; do
		[ -z "${seen[$p]:-}" ] || continue
		seen[$p]=1
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
	local id spec
	for id in "$@"; do
		spec=$(find_spec "$id") || spec="$id"
		parse_spec "$spec"
		if [ "${SPEC_INSTALL:-pkg}" = "pkg" ]; then
			_PKG_BATCH_IDS+=("$id")
			_PKG_BATCH_NAMES+=("$(pkg_name "$id")")
		fi
	done
}

install_missing_required() {
	${INSTALL_MODE:-false} || return 0
	[ ${#MISSING_REQUIRED[@]} -gt 0 ] || return 0
	echo -e "${YELLOW}Installing: ${MISSING_REQUIRED[*]}...${NC}"
	local id spec
	_collect_pkg_batch "${MISSING_REQUIRED[@]}"
	if [ ${#_PKG_BATCH_NAMES[@]} -gt 0 ]; then
		install_pkg ${_PKG_BATCH_NAMES[@]+"${_PKG_BATCH_NAMES[@]}"} || true
	fi
	for id in "${MISSING_REQUIRED[@]}"; do
		spec=$(find_spec "$id") || spec="$id"
		parse_spec "$spec"
		[ "${SPEC_INSTALL:-pkg}" = "pkg" ] && continue
		info "installing ${id}..."
		install_strategy "$spec" || warn "could not install ${id}"
	done
	# Project-level re-probe (sway/hyprland upstream style): one "installed" /
	# "still missing" line per entry of REQUIRED_REPROBE_LIST, probed via
	# REQUIRED_REPROBE_FN (default below) and displayed via REQUIRED_NAME_FN.
	# Projects without the list keep the run_required_checks behaviour below.
	# [*] in the guard, never [@]: an UNSET array's @+ expansion is zero
	# words, so `[ -n "${arr[@]+SET}" ]` degenerates to always-true `[ -n ]`.
	if [ -n "${REQUIRED_REPROBE_LIST[*]+SET}" ] && [ ${#REQUIRED_REPROBE_LIST[*]} -gt 0 ]; then
		local rb probe_fn name_fn label
		probe_fn=${REQUIRED_REPROBE_FN:-_reprobe_default}
		name_fn=${REQUIRED_NAME_FN:-}
		MISSING_REQUIRED=()
		REQUIRED_FAILURES=0

		# Default re-probe: installed = resolves on PATH or a known ext path.
		_reprobe_default() {
			have_native_cmd "$1" || ext_paths_ok "$1"
		}
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
					REQUIRED_FAILURES=$((REQUIRED_FAILURES + 1))
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
					REQUIRED_FAILURES=$((REQUIRED_FAILURES + 1))
				fi
				;;
			esac
		done
		if [ ${#MISSING_REQUIRED[@]} -eq 0 ]; then
			echo -e "${GREEN}All required tools now available.${NC}"
		elif [ -n "${REQUIRED_MANUAL_HINT:-}" ]; then
			echo -e "${RED}${REQUIRED_MANUAL_HINT}${NC}"
		fi
	else
		run_required_checks
		if [ ${#MISSING_REQUIRED[@]} -eq 0 ]; then
			echo -e "${GREEN}All required tools now available.${NC}"
		else
			local -a hint_pkgs=()
			for id in "${MISSING_REQUIRED[@]}"; do
				hint_pkgs+=("$(pkg_name "$id")")
			done
			echo -e "${RED}Run: $(get_install_hint "$(dedupe_pkgs ${hint_pkgs[@]+"${hint_pkgs[@]}"})")${NC}"
		fi
	fi
	echo ""
}

install_missing_recommended() {
	${INSTALL_MODE:-false} || return 0
	[ ${#MISSING_RECOMMENDED[@]} -gt 0 ] || return 0
	echo -e "${YELLOW}Installing: ${MISSING_RECOMMENDED[*]}...${NC}"
	local id spec
	_collect_pkg_batch "${MISSING_RECOMMENDED[@]}"
	if [ ${#_PKG_BATCH_NAMES[@]} -gt 0 ]; then
		if install_pkg ${_PKG_BATCH_NAMES[@]+"${_PKG_BATCH_NAMES[@]}"}; then
			echo -e "${GREEN}Done.${NC}"
		else
			echo -e "${RED}Failed. Run: $(get_install_hint "$(dedupe_pkgs ${_PKG_BATCH_NAMES[@]+"${_PKG_BATCH_NAMES[@]}"})")${NC}"
		fi
	fi
	for id in "${MISSING_RECOMMENDED[@]}"; do
		spec=$(find_spec "$id") || spec="$id"
		parse_spec "$spec"
		[ "${SPEC_INSTALL:-pkg}" = "pkg" ] && continue
		if install_strategy "$spec"; then
			echo -e "  ${GREEN}✓ ${id} available${NC}"
		else
			echo -e "  ${RED}✗ failed to install ${id}${NC}"
			echo -e "    hint: $(get_install_hint "$(pkg_name "$id")")"
		fi
	done
	echo ""
}

# Probes OPTIONAL_CHECKS itself instead of trusting MISSING_OPTIONAL: the
# step runs BEFORE the listing, so the listing's verdict is not available.
install_missing_optional() {
	${INSTALL_MODE:-false} || return 0
	[ "${INSTALL_OPTIONAL:-0}" = 1 ] || return 0
	local -a missing=()
	local e bin spec
	for e in ${OPTIONAL_CHECKS[@]+"${OPTIONAL_CHECKS[@]}"}; do
		parse_spec "$e"
		bin="$SPEC_ID"
		probe_spec "$e" || missing+=("$bin")
	done
	if [ ${#missing[@]} -eq 0 ]; then
		if [ -n "${OPTIONAL_ALL_PRESENT_MSG:-}" ]; then
			echo -e "${GREEN}${OPTIONAL_ALL_PRESENT_MSG}${NC}"
			echo ""
		fi
		return 0
	fi
	echo -e "${YELLOW}${OPTIONAL_INSTALL_TITLE:-Installing optional tools}: ${missing[*]}...${NC}"
	# Plain pkg strategies batch into ONE transaction; side-effecting
	# strategies (npm/go/pip/brew/…) install per tool below.
	_collect_pkg_batch "${missing[@]}"
	if [ ${#_PKG_BATCH_IDS[@]} -gt 0 ]; then
		if install_pkg ${_PKG_BATCH_NAMES[@]+"${_PKG_BATCH_NAMES[@]}"}; then
			local bin spec
			for bin in "${_PKG_BATCH_IDS[@]}"; do
				spec=$(find_spec "$bin") || spec="$bin"
				if probe_spec "$spec"; then
					echo -e "  ${GREEN}✓ ${bin} installed${NC}"
				else
					echo -e "  ${RED}✗ failed to install ${bin}${NC}"
					echo -e "    hint: $(get_install_hint "$bin")"
				fi
			done
		else
			for bin in "${_PKG_BATCH_IDS[@]}"; do
				echo -e "  ${RED}✗ failed to install ${bin}${NC}"
				echo -e "    hint: $(get_install_hint "$bin")"
			done
		fi
	fi
	local installed_ok
	for bin in "${missing[@]}"; do
		spec=$(find_spec "$bin") || spec="$bin"
		parse_spec "$spec"
		[ "${SPEC_INSTALL:-pkg}" = "pkg" ] && continue # batched above
		echo -e "  ${YELLOW}→ installing ${bin}...${NC}"
		installed_ok=true
		# A project may carry upstream's per-binary install table verbatim
		# (monkey-nvim / monkey-vim); otherwise run the spec strategy.
		if declare -F install_optional_bin >/dev/null 2>&1; then
			install_optional_bin "$bin" || installed_ok=false
		elif ! install_strategy "$spec"; then
			installed_ok=false
		fi
		if $installed_ok; then
			echo -e "  ${GREEN}✓ ${bin} installed${NC}"
		else
			echo -e "  ${RED}✗ failed to install ${bin}${NC}"
			echo -e "    hint: $(get_install_hint "$bin")"
		fi
	done
	# Optional trailing summary for projects whose original printed one
	# after a non-empty install batch (monkey-nvim, monkey-vim).
	if [ -n "${OPTIONAL_DONE_MSG:-}" ]; then
		echo -e "${GREEN}${OPTIONAL_DONE_MSG}${NC}"
	fi
	echo ""
}
