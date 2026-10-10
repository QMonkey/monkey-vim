# shellcheck shell=bash
# monkey-scripts/lib/clone.sh — clone / download.
#
# Sourced by scripts/install.sh (not by checkhealth.sh).
#
# Data contract (project side):
#   PROJECT / PROJECT_REPO / INSTALL_DIR

# ────────────────── interrupted-clone repair ──────────────────
# A clone killed mid-transfer leaves a dir with .git but no HEAD; every
# later operation fails forever (`git pull` dies, `git clone` refuses with
# "already exists", nvim's vim.pack repair dies with "ambiguous argument
# 'HEAD'" — one clone timeout took 34 plugins down with it on openSUSE).
# Removal is the only repair; healthy checkouts and dirs without .git are
# untouched.
repair_broken_clone() {
	local dir="$1"
	[ -n "$dir" ] && [ -d "$dir/.git" ] || return 0
	if ! git -C "$dir" rev-parse HEAD >/dev/null 2>&1; then
		warn "removing broken git clone (interrupted clone, no HEAD): ${dir#"$HOME"/}"
		rm -rf -- "$dir"
	fi
	return 0
}

# clone_repo [--submodules] [--<git-clone-option>...] <url> <dir> — the
# framework's git clone; owns every state a target dir can be in:
#   missing            → clone (options like --branch=main pass through)
#   .git, HEAD ok      → pull --ff-only (failure keeps the checkout, rc 0)
#   .git, HEAD broken  → rm -rf, then a clean clone
#   no .git            → left untouched with a warning, rc 1 (user data)
#   --submodules       shallow two-step fetch (clone --depth=1, then a
#                      retried `submodule update --init --recursive` after
#                      BOTH paths — the one-step combination is flaky on the
#                      remote side). Shallow is implied: do not pass --depth.
# The flag and git-clone options may appear anywhere relative to the two
# bare positionals — the parser classifies by shape, so
# `clone_repo --branch=main <url> <dir>` and `clone_repo <url> <dir>
# --branch=main` are the same call. (The first draft parsed positionally
# and the wezterm call site passed options FIRST — it only ever "worked"
# because git re-parses stray tokens as trailing options while $dir
# silently held a garbage value and the pull path was unreachable.) A
# killed clone attempt leaves a .git-only partial dir behind — repaired
# before returning.
_clone_submodules() {
	retry -t 1800 -s "git submodule update" git -C "$1" submodule update --init --recursive
}

clone_repo() {
	local raw="$*" submodules=0 has_depth=0
	local -a git_args=() positional=()
	while [ $# -gt 0 ]; do
		case "$1" in
		--submodules) submodules=1 ;;
		--depth*)
			has_depth=1
			git_args+=("$1")
			;;
		-*) git_args+=("$1") ;;  # git-clone options (--branch=main, ...)
		*) positional+=("$1") ;; # the two bare positionals: url, dir
		esac
		shift
	done
	if [ ${#positional[@]} -ne 2 ]; then
		die "clone_repo: expected <url> <dir> plus optional flags — got: $raw"
	fi
	local url=${positional[0]} dir=${positional[1]}
	repair_broken_clone "$dir"
	if [ -d "$dir/.git" ]; then
		info "git repo already at ${dir#"$HOME"/} — pulling latest..."
		retry -s "git pull" git -C "$dir" pull --ff-only ||
			warn "git pull failed — keeping the existing checkout."
		[ "$submodules" = 1 ] || return 0
		_clone_submodules "$dir"
		return
	fi
	if [ -e "$dir" ]; then
		warn "$dir exists and is not a git clone — leaving it untouched."
		return 1
	fi
	if [ "$submodules" = 1 ] && [ "$has_depth" = 0 ]; then
		git_args+=(--depth=1)
	fi
	if retry -t 1800 -s "git clone ${dir##*/}" git clone ${git_args[@]+"${git_args[@]}"} "$url" "$dir"; then
		[ "$submodules" = 1 ] || return 0
		_clone_submodules "$dir"
		return
	fi
	repair_broken_clone "$dir"
	return 1
}

clone_project() {
	# git must exist before the pull/clone; ensure_git installs it when
	# missing (setup_sudo has already run by this step).
	ensure_git
	# On the curl|bash path the bootstrap already cloned into INSTALL_DIR,
	# so clone_repo normally just confirms (and pulls) — one clone, not two.
	# A non-git INSTALL_DIR is left untouched and used as-is.
	clone_repo "$PROJECT_REPO" "$INSTALL_DIR" ||
		warn "$INSTALL_DIR exists but is not a git repository — using it as-is."
	ok "$PROJECT ready at $INSTALL_DIR."
}

# fetch_url_or_clone <url> <repo-url> <dest> [label] — download <url>; when
# the CDN is unreachable (raw.githubusercontent.com outages while github.com
# git endpoints still responded), fall back to a shallow clone of <repo-url>
# and copy the script out. <dest> must end with the script's basename.
fetch_url_or_clone() {
	local url="$1" repo_url="$2" dest="$3" label="${4:-download}"
	if retry -s "$label download" curl -fsSL "$url" -o "$dest"; then
		return 0
	fi
	local base dir
	base="${url##*/}"
	warn "$label download failed — falling back to a git clone..."
	# clone_repo owns the clone mechanics (retries, broken-clone repair).
	# Clone into a SUBDIR of the mktemp dir: clone_repo refuses an existing
	# non-git directory, and mktemp -d creates the parent.
	dir="$(mktemp -d)" || return 1
	if ! clone_repo --depth=1 "$repo_url" "$dir/repo"; then
		rm -rf "$dir"
		return 1
	fi
	if [ ! -f "$dir/repo/$base" ]; then
		warn "$base not found in $repo_url — the git clone fallback cannot help."
		rm -rf "$dir"
		return 1
	fi
	mkdir -p "$(dirname "$dest")"
	mv "$dir/repo/$base" "$dest" && rm -rf "$dir"
}
