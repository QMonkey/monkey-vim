# monkey-scripts/lib/config.sh — declarative symlinks (install) + config
# checks (checkhealth).
#
# Sourced by scripts/install.sh and scripts/checkhealth.sh.
#
# Data contract (project side):
#   SYMLINKS=("src|dst" "src|dst|keep")   link_config <src> <dst> <mode>
#   ENSURE_DIRS=("path" ...)              mkdir -p, reported once per dir
#   ENSURE_FILES=("path" ...)             touch when missing
#   CONFIG_LINKS=("src|dst|desc|mode|name|hint")  checkhealth: required links
#   CONFIG_HINTS=("type|params|ok|incomplete|missing")  advisory, config section
#   ADVISORY_SECTIONS=("title|note|type|params|ok|incomplete|missing")
#
# Link modes (install side, the third SYMLINKS field):
#   "" (default) — a foreign target is left alone with a warning,
#   "keep"       — an existing target is skipped with an info line and a
#                  missing source is skipped silently (efm-langserver,
#                  .clang-format — the repo may not even ship the source),
#   "strict"     — checkhealth only: the link must resolve to THIS repo.

# ──────────────────────── install side ────────────────────────
# Usage: link_config <src> <dst> [mode]. Never overwrites an existing target
# that is not this repo's link (ln -sfn into a real directory would create the
# link INSIDE it).
#
# mode ""     — a foreign target is reported with a warning + the re-link line
#        keep  — an existing target is skipped with an info line, and a missing
#                source is skipped silently: the entry guards something the repo
#                may not even ship (efm-langserver, .clang-format, configs/<dir>)
link_config() {
	local src="$1" dst="$2" mode="${3:-}"
	if [ -e "$dst" ] || [ -L "$dst" ]; then
		if [ "$mode" = "keep" ]; then
			info "$(basename "$dst") already exists — skipping."
		elif [ -L "$dst" ] && [ "$(readlink -f "$dst" 2>/dev/null || readlink "$dst")" = "$(readlink -f "$src" 2>/dev/null || readlink "$src")" ]; then
			ok "$(basename "$dst") already linked."
		else
			warn "$dst exists and is not this repo's link — skipping."
			echo -e "    re-link manually with: ${CYAN}ln -sfn $src $dst${NC}"
		fi
		return 0
	fi
	# A missing source is always silent: SYMLINKS may list optional files.
	[ -e "$src" ] || return 0
	mkdir -p "$(dirname "$dst")"
	ln -sfn "$src" "$dst"
	# Label = dst without the home prefix (".zshrc → <repo>/.zshrc"), which
	# is how the per-repo installers have always reported their links.
	ok "${dst#"$HOME"/} → $src"
}

setup_symlinks() {
	info "Setting up configuration symlinks..."
	local entry src dst mode
	for entry in ${SYMLINKS[@]+"${SYMLINKS[@]}"}; do
		IFS='|' read -r src dst mode <<EOF
$entry
EOF
		link_config "$src" "$dst" "$mode"
	done
	local d f
	for d in ${ENSURE_DIRS[@]+"${ENSURE_DIRS[@]}"}; do
		if [ -d "$d" ]; then
			ok "$d exists"
		else
			mkdir -p "$d"
			ok "created $d"
		fi
	done
	for f in ${ENSURE_FILES[@]+"${ENSURE_FILES[@]}"}; do
		if [ -f "$f" ]; then
			ok "$(basename "$f") exists"
		else
			touch "$f"
			ok "$(basename "$f") ready"
		fi
	done
}

# ──────────────────────── checkhealth side ────────────────────────
# Advisory probe shared by CONFIG_HINTS and ADVISORY_SECTIONS.
#   type=path   — any candidate exists (a trailing "/" requires a non-empty
#                 directory); if none exists but ANY candidate's parent
#                 directory does, report "incomplete" when it is set.
#   type=exec   — like path, but files must be executable (tmux-fingers...)
#   type=cmd    — any candidate resolves on PATH
#   type=any    — mixed list: tokens containing "/" are paths, the rest cmds
#   type=nerdfont — fc-list knows a Nerd Font
# Prints one status line and returns 0 (present) / 1 (missing). When both
# <incomplete> and <missing> are empty nothing is printed (silent advisory).
# A "{ver}" placeholder in <ok> expands to the first version of the cmd.
probe_advisory() {
	local type="$1" params="$2" ok_msg="$3" incomplete="$4" missing="$5"
	local tok found="" parent_ok=0
	case "$type" in
	nerdfont)
		if fc-list 2>/dev/null | grep -qi "nerd"; then
			ok "${ok_msg:-Nerd Font found}"
			return 0
		fi
		[ -n "$missing" ] && warn "$missing"
		return 1
		;;
	esac
	for tok in $params; do
		# "!dir" — an incomplete-install marker: the dir exists, so the
		# component is there but not functional yet. It never counts as
		# "found" (tmux-fingers' plugin dir, the efm-langserver source dir).
		case "$tok" in
		\!*)
			[ -d "${tok#!}" ] && parent_ok=1
			continue
			;;
		esac
		case "$type" in
		cmd)
			have_native_cmd "$tok" && found="$tok" && break
			;;
		path | exec | marker)
			case "$tok" in
			*/)
				if [ -d "${tok%/}" ] && [ -n "$(ls -A "${tok%/}" 2>/dev/null)" ]; then found="$tok"; break; fi
				;;
			*)
				if [ -e "$tok" ]; then
					if [ "$type" != exec ] || [ -x "$tok" ] || [ -d "$tok" ]; then
						found="$tok"
						break
					fi
				fi
				;;
			esac
			# A candidate under $HOME whose parent dir exists means "the
			# component is there, half of it is missing" → <incomplete>.
			# System parents (/usr/local/bin) are excluded: their existence
			# says nothing about us.
			case "$tok" in
			"$HOME"/*) [ -e "$(dirname "$tok")" ] && parent_ok=1 ;;
			esac
			;;
		any)
			case "$tok" in
			*/*)
				if [ -e "$tok" ]; then
					found="$tok"
					break
				fi
				case "$tok" in
				"$HOME"/*) [ -e "$(dirname "$tok")" ] && parent_ok=1 ;;
				esac
				;;
			*)
				have_native_cmd "$tok" && found="$tok" && break
				;;
			esac
			;;
		esac
	done
	if [ -n "$found" ]; then
		if [ -n "$ok_msg" ] && [[ "$ok_msg" == *"{ver}"* ]]; then
			local ver=""
			case "$type" in
			cmd | any)
				ver=$("$found" --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)*' | head -1)
				;;
			esac
			ok "${ok_msg//\{ver\}/${ver:-?}}"
		else
			ok "${ok_msg:-$found}"
		fi
		return 0
	fi
	if [ "$parent_ok" = 1 ] && [ -n "$incomplete" ]; then
		warn "$(printf '%b' "$incomplete")"
		return 1
	fi
	# Nothing relevant around: stay silent unless a message was provided.
	[ -n "$missing" ] || return 1
	warn "$missing"
	return 1
}

# The "Config files" section: required links first, then advisory entries.
# --skip-check-config (passed by install.sh): the config symlinks are linked
# AFTER this script runs in most repos, so judging them here would fail every
# chained run and burn all three retries. Standalone runs (the manual
# diagnosis entry point) still get the full check.
check_config_files() {
	if ${SKIP_CONFIG_CHECKS:-false}; then
		warn "config checks skipped (handled by the installer)"
		return 0
	fi
	print_bold_header "Config files"
	check_config_links
	local entry type params ok_msg incomplete missing
	for entry in ${CONFIG_HINTS[@]+"${CONFIG_HINTS[@]}"}; do
		IFS='|' read -r type params ok_msg incomplete missing <<EOF
$entry
EOF
		probe_advisory "$type" "$params" "$ok_msg" "$incomplete" "$missing" || true
	done
	echo ""
}

check_config_links() {
	# CONFIG_LINKS: src|dst|desc|mode|name|hint
	#   desc — happy-path line (".zshrc → /repo/.zshrc")
	#   name — what warn lines talk about (".zshrc");
	#          the missing-link hint always shows dst as "~/…"
	#   hint — verbatim missing-fail message when the project's upstream
	#          text differs from the generic one (ln -sf vs -sfn, literal
	#          placeholders, mkdir prefixes, …)
	local entry src dst desc mode name hint
	for entry in ${CONFIG_LINKS[@]+"${CONFIG_LINKS[@]}"}; do
		IFS='|' read -r src dst desc mode name hint <<EOF
$entry
EOF
		desc="${desc:-$dst}"
		if [ -z "$name" ]; then
			name="${dst/#$HOME/\~}"
		fi
		if [ -L "$dst" ]; then
			local target
			target=$(readlink -f "$dst" 2>/dev/null || readlink "$dst")
			if [ "$mode" = "strict" ]; then
				if [ "$target" = "$src" ]; then
					ok "${desc} → ${target}"
				else
					warn "${desc} → ${target} (not this repo: ${src})"
				fi
			elif [ -e "$target" ]; then
				ok "${desc} → ${target}"
			else
				fail "${desc} symlink broken → ${target}"
				REQUIRED_FAILURES=$((REQUIRED_FAILURES + 1))
			fi
		elif [ -e "$dst" ]; then
			if [ "$mode" = "strict" ]; then
				warn "${name} is a plain entry (old per-file links) — re-link: ln -sfn ${src} ${dst}"
			else
				warn "${name} exists but is not a symlink"
			fi
		else
			local missing_msg
			missing_msg="${name} not found (run: ln -sfn ${src} ${dst/#$HOME/\~})"
			fail "${hint:-$missing_msg}"
			REQUIRED_FAILURES=$((REQUIRED_FAILURES + 1))
		fi
	done
}

# Standalone advisory sections (fonts, tmux-fingers, wezterm plugins, ...).
check_advisory_sections() {
	local entry title note type params ok_msg incomplete missing
	for entry in ${ADVISORY_SECTIONS[@]+"${ADVISORY_SECTIONS[@]}"}; do
		IFS='|' read -r title note type params ok_msg incomplete missing <<EOF
$entry
EOF
		print_bold_header "$title"
		[ -n "$note" ] && echo "  $note"
		probe_advisory "$type" "$params" "$ok_msg" "$incomplete" "$missing" || true
		echo ""
	done
}
