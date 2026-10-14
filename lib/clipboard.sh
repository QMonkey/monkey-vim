# monkey-scripts/lib/clipboard.sh — clipboard provider detection and install,
# keyed on CHECK_CLIPBOARD (required | warn | display). Sourced by
# scripts/checkhealth.sh (via lib/bootstrap.sh EXTRA_LIBS), AFTER lib/checks.sh
# (check_spec / record_missing) and lib/pkg.sh (install_pkg).

# ──────────────────────── clipboard ────────────────────────
# First available clipboard provider, in tmux-yank's preference order
# (wl-copy wins, then xclip, then xsel); empty when none. The ONE probe list
# every clipboard consumer goes through.
_clipboard_tool() {
	local t
	for t in wl-copy xclip xsel; do
		if have_native_cmd "$t"; then
			printf '%s' "$t"
			return 0
		fi
	done
	return 1
}

# What the current session needs: pbcopy/pbpaste (built in) on macOS,
# wl-copy/wl-paste on Wayland, xclip or xsel on X11. Prints the state:
#   "ok" | "ok <tool>" (which provider matched) | "missing <package>" | "n/a"
# (no graphical session — SSH, console — where a system clipboard cannot be
# reached anyway). Shared by the warn-level check and the installer pass.
clipboard_state() {
	if [ "$OS" = "macos" ]; then
		echo ok
	elif [ "${XDG_SESSION_TYPE:-}" = wayland ] || [ -n "${WAYLAND_DISPLAY:-}" ]; then
		if have_native_cmd wl-copy; then
			echo "ok wl-copy"
		else
			echo "missing wl-clipboard"
		fi
	elif [ "${XDG_SESSION_TYPE:-}" = x11 ] || [ -n "${DISPLAY:-}" ]; then
		local tool
		tool=$(_clipboard_tool) && echo "ok ${tool}" || echo "missing xclip"
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
		# No session gate here (unlike clipboard_state): under XWayland
		# xclip works too, so ANY of the three providers suffices.
		local tool hint="xclip"
		tool=$(_clipboard_tool) || true
		[ -n "${WAYLAND_DISPLAY:-}" ] && hint="wl-clipboard"
		if [ -n "$tool" ]; then
			ok "${tool} (clipboard)"
		else
			fail "xclip / xsel / wl-copy (install: ${hint})"
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
	ok*) ok "Clipboard support available" ;;
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
	ok* | n/a) return 0 ;;
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
