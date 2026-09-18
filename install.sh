{
	info "Installing Vim build dependencies..."
	refresh_pkg
	case "$OS" in
	debian)
		common=(git curl build-essential
			libwayland-dev libcairo2-dev
			libgpm-dev libncurses-dev
			python3-dev lua5.4 liblua5.4-dev
			perl libperl-dev ruby ruby-dev)
		if is_wsl_kernel; then
			gui=(libgtk-3-dev libx11-dev libxt-dev libxpm-dev)
		else
			# Non-WSL: prefer GTK4 (no X11 dependency)
			gui=(libgtk-4-dev)
		fi
		sudo_cmd apt-get install -y "${common[@]}" "${gui[@]}"
		;;
	arch)
		common=(base-devel git curl
			wayland gpm ncurses
			lua perl python ruby)
		if is_wsl_kernel; then
			gui=(gtk3 libx11 libxt libxpm)
		else
			gui=(gtk4)
		fi
		sudo_cmd pacman -S --needed --noconfirm "${common[@]}" "${gui[@]}"
		;;
	opensuse)
		sudo_cmd zypper --non-interactive install -y -t pattern devel_basis
		# Leap 16 names: python-devel and perl-devel do not exist (python3
		# needs -devel-suffixed python3-devel only; perl headers ship in the
		# main perl package), and xorg-x11-devel was removed — use the
		# individual libX*-devel packages. One unknown name aborts the whole
		# zypper transaction, so these must resolve exactly.
		common=(git curl
			wayland-devel cairo-devel
			gpm-devel ncurses-devel
			python3-devel
			ruby-devel lua-devel perl)
		if is_wsl_kernel; then
			gui=(gtk3-devel libX11-devel libXpm-devel libXt-devel)
		else
			gui=(gtk4-devel)
		fi
		sudo_cmd zypper --non-interactive install -y "${common[@]}" "${gui[@]}"
		;;
	centos)
		sudo_cmd dnf install -y epel-release || true
		common=(gcc make git curl
			wayland-devel cairo-devel
			gpm-devel ncurses-devel
			python3-devel ruby-devel lua-devel
			perl perl-devel perl-ExtUtils-ParseXS
			perl-ExtUtils-CBuilder perl-ExtUtils-Embed)
		if is_wsl_kernel; then
			gui=(gtk3-devel libX11-devel libXpm-devel libXt-devel)
		else
			gui=(gtk4-devel)
		fi
		sudo_cmd dnf install -y "${common[@]}" "${gui[@]}"
		;;
	macos)
		# Terminal-only build (--enable-gui=no); no gtk/cairo needed. git is
		# required regardless — build_vim and clone_monkey_vim both clone.
		if have_native_cmd brew; then
			brew install git python3 ruby lua
		else
			warn "Homebrew not found — cannot install vim build deps. Install it first: https://brew.sh"
		fi
		;;
	*)
		warn "Unknown OS ($OS). Attempting to continue with whatever is available."
		;;
	esac
	hash -r # re-scan PATH: fresh binaries must not be shadowed by cached shim paths
	ok "Build dependencies installed."
}
