# monkey-vim

Read this in other languages: [简体中文](README.zh-CN.md)

## Introduction

The project monkey-vim, aims to make a powerful and fast terminal-native IDE.

**Positioning:** monkey-vim targets pure terminal environments — no GUI, no gvim, no built-in terminal multiplexing. Use it in:

| Environment    | Description                                                                                      |
| -------------- | ------------------------------------------------------------------------------------------------ |
| Linux Terminal | xterm, kitty, alacritty, wezterm, gnome-terminal, etc.                                           |
| macOS Terminal | Terminal.app, iTerm2, kitty, etc.                                                                |
| WSL            | Windows Subsystem for Linux (WSL2 recommended)                                                   |
| Server TTY     | Bare Linux console (tty1–tty63), Vim default 8/16-color highlighting (sonokai needs ≥256 colors) |
| kmscon         | Kernel Mode Setting console — modern TTY replacement with true color and Unicode support         |

Top-level workspace management (multiple sessions and terminals) and AI integration (agent TUIs such as Claude Code or opencode) are both delegated to tmux or your terminal emulator's tabs; in-editor splits and tabs work as usual.

## Screenshot

![vim](pictures/vim.png "vim")

## Requirements

- vim 9.1+ (9.1.1984+ for the OSC 52 clipboard over SSH; the one-click installer builds a current Vim)
- A terminal environment (no GUI / gvim support)

## Installation

Pick one of the two ways below: a one-click script, or manual setup.

### Option 1: One-click install

Build Vim and install monkey-vim with all dependencies and plugins automatically:

```bash
curl -fsSL https://raw.githubusercontent.com/QMonkey/monkey-vim/master/install.sh | bash
```

What the script does, step by step:

1. Install Vim build dependencies (GTK3/4 + Wayland or X11 per display server; Python3/Perl/Ruby/Lua)
2. Pre-authorize `sudo` once and keep the credentials alive in a background loop, so long downloads/compiles never trigger a mid-run password re-prompt (unattended runs won't stall). On WSL it also installs a temporary sudoers drop-in (removed on exit) with `timestamp_type=global` + `timestamp_timeout=-1`: tickets are keyed by uid only, so new terminal and SSH sessions, WSL clock jumps and tty changes never re-prompt — one password until WSL restarts
3. Install Homebrew (Linuxbrew) as the fallback package manager — its shellenv is persisted to your shell rc files (with PATH dedup guards) even when Homebrew already existed
4. Clone and compile Vim from source, then `make install`
5. Clone monkey-vim to `~/Documents/monkey-vim` (or update it if already cloned)
6. Install required tools + optional LSP servers via `checkhealth.sh --install` (apt/zypper/dnf/pacman/brew, npm, pip, go install, rustup). npm is installed explicitly when missing (Debian/Ubuntu `nodejs` alone doesn't provide it); global npm packages skip `sudo` whenever the npm prefix is user-writable; fzf prefers Homebrew so you get a current version instead of the distro's
7. Persist `~/go/bin`, `~/.cargo/bin` (and `/usr/local/bin`) in your shell rc files
8. Symlink `.vimrc`, `.clang-format`, and the efm-langserver config; create runtime directories
9. Install all Vim plugins (`:PlugInstall`) automatically

> The script keeps the Vim source tree at `~/Documents/vim` (no cleanup), so you can rebuild later with `git pull` + `make`.
>
> The script only rebuilds Vim when the installed one is below 9.1 **or** its `vim --version` features are incomplete — version alone isn't enough. The required features mirror the builds below: `+clipboard` and `+clipboard_provider` (clipboard providers power the osc52/tmux fallbacks; the feature landed in 9.1.1857, so distro builds of 9.1.0–9.1.1846 are rebuilt) plus, per platform, `+xterm_clipboard` (WSL), `+wayland_clipboard` or `+xterm_clipboard` (Linux desktop); the core set is `+python3 +lua +perl +ruby +terminal +cscope +multi_byte`.
>
> PATH changes only apply to shells started after the install. When it finishes, the script prints how to apply them to the current terminal (`source <rc file>` or `exec $SHELL`).

### Option 2: Manual installation

Install by hand, following the steps in order:

### 1. Git clone

```bash
git clone https://github.com/QMonkey/monkey-vim.git
```

### 2. Install dependencies

#### 2.1 Common tools

| Tool                                                          | Purpose                                                                                     | Required    |
| ------------------------------------------------------------- | ------------------------------------------------------------------------------------------- | ----------- |
| curl                                                          | Plugin manager bootstrap                                                                    | Yes         |
| git                                                           | Plugin manager, vim-fugitive                                                                | Yes         |
| [ripgrep](https://github.com/BurntSushi/ripgrep) (rg)         | ctrlsf code search + fzf.vim file search                                                    | Yes         |
| universal-ctags                                               | gutentags tag generation                                                                    | Yes         |
| [GNU Global](https://www.gnu.org/software/global/) (`global`) | gutentags gtags (GTAGS) generation & navigation                                             | Recommended |
| [Pygments](https://pygments.org/) (`pygmentize`)              | gtags parser for non-C/C++ languages (Python, Go, Rust, JS, etc.)                           | Recommended |
| [fzf](https://github.com/junegunn/fzf)                        | Fuzzy finder (fzf.vim)                                                                      | Yes         |
| [bat](https://github.com/sharkdp/bat)                         | Syntax-highlighted file preview in fzf                                                      | Recommended |
| [Homebrew](https://brew.sh/)                                  | Fallback package manager for tools not in system repos (lua-language-server, marksman, fzf) | Required    |

```bash
# Install Homebrew (all Linux distros — required for tools not in system repos)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

# Ubuntu/Debian
sudo apt-get install curl git ripgrep universal-ctags global python3-pygments nodejs npm gcc
brew install fzf bat

# OpenSUSE
sudo zypper install curl git ripgrep universal-ctags global python3-Pygments fzf bat nodejs npm gcc

# CentOS (enable EPEL for ripgrep/ctags/global/pygments/fzf/bat)
sudo dnf install epel-release
sudo dnf install curl git ripgrep universal-ctags global global-ctags python3-pygments fzf bat nodejs npm gcc

# Arch Linux
sudo pacman -S curl git ripgrep ctags global python-pygments fzf bat nodejs npm gcc

# macOS
brew install curl git ripgrep universal-ctags global pygments fzf bat node
```

#### 2.2 LSP servers

Language Server Protocol support is provided by [yegappan/lsp](https://github.com/yegappan/lsp). Install the servers for languages you use:

| Language   | LSP Server                  | Install                                                                                                                                          |
| ---------- | --------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------ |
| C/C++      | clangd                      | `sudo apt-get install clangd`, `sudo zypper install clang`, `sudo dnf install clang-tools-extra`, `sudo pacman -S clang`, or `brew install llvm` |
| Go         | gopls                       | `go install golang.org/x/tools/gopls@latest`                                                                                                     |
| Python     | python-lsp-server           | `pip3 install python-lsp-server`                                                                                                                 |
| Zig        | zls                         | `brew install zls` (recommended, keeps zig/zls matched) or download from <https://zigtools.org/zls/install/>                                     |
| Rust       | rust-analyzer               | `rustup component add rust-analyzer`                                                                                                             |
| Lua        | lua-language-server         | `brew install lua-language-server` or `sudo pacman -S lua-language-server`                                                                       |
| Shell      | bash-language-server        | `npm install -g bash-language-server`                                                                                                            |
| Vim        | vim-language-server         | `npm install -g vim-language-server`                                                                                                             |
| JavaScript | typescript-language-server  | `npm install -g typescript-language-server typescript`                                                                                           |
| TypeScript | typescript-language-server  | `npm install -g typescript-language-server typescript`                                                                                           |
| JSON       | vscode-json-language-server | `npm install -g vscode-langservers-extracted`                                                                                                    |
| YAML       | yaml-language-server        | `npm install -g yaml-language-server`                                                                                                            |
| Markdown   | marksman                    | `brew install marksman` or `sudo pacman -S marksman`                                                                                             |
| Markdown   | efm-langserver              | `go install github.com/mattn/efm-langserver@latest`                                                                                              |

Some LSP servers offload formatting/linting to **external tools** that must be installed separately. Without them the feature silently degrades (falls back to built-in diagnostics or skips the tool):

| Language | Tool              | Role                                   | Install                                                                                                                                              |
| -------- | ----------------- | -------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------- |
| C/C++    | clang-tidy        | linter (via `clangd --clang-tidy`)     | `sudo apt-get install clang-tidy`, `sudo zypper install clang`, `sudo dnf install clang-tools-extra`, `sudo pacman -S clang`, or `brew install llvm` |
| Go       | staticcheck       | linter (via `gopls` `staticcheck`)     | `go install honnef.co/go/tools/cmd/staticcheck@latest`                                                                                               |
| Shell    | shfmt             | formatter (via `bash-language-server`) | `go install mvdan.cc/sh/v3/cmd/shfmt@latest`                                                                                                         |
| Python   | black             | formatter (via `pylsp` black plugin)   | `pip3 install black`                                                                                                                                 |
| Markdown | prettier          | formatter (via `efm-langserver`)       | `npm install -g prettier`                                                                                                                            |
| Markdown | markdownlint-cli2 | linter (via `efm-langserver`)          | `npm install -g markdownlint-cli2`                                                                                                                   |

#### 2.3 C/C++

```bash
# Ubuntu/Debian
sudo apt-get install gcc g++ clangd clang-tidy

# OpenSUSE
sudo zypper install gcc gcc-c++ clang

# CentOS
sudo dnf install gcc gcc-c++ clang clang-tools-extra

# Arch Linux
sudo pacman -S gcc clang

# macOS
brew install gcc llvm
```

#### 2.4 Go

```bash
# Install the latest version of Go, then:
go install golang.org/x/tools/gopls@latest
# Optional: staticcheck linter (used by gopls)
go install honnef.co/go/tools/cmd/staticcheck@latest
```

#### 2.5 Python

```bash
# Python 3 is required (install via system package manager if not present)
pip3 install python-lsp-server
# Optional: formatters/linters (black is used by the pylsp black plugin)
pip3 install black autopep8 flake8 pylint
```

#### 2.6 JavaScript / TypeScript

```bash
# Install LSP server
npm install -g typescript-language-server typescript
```

#### 2.7 Zig

Zig syntax highlighting, indentation, and filetype detection are built into Vim 9.2+ — no plugin needed. Install Zig and the ZLS language server:

```bash
# Recommended: Homebrew keeps zig and zls versions in sync
brew install zig zls          # macOS / Linuxbrew

# Or download matched prebuilt binaries:
#   zig: https://ziglang.org/download/
#   zls: https://zigtools.org/zls/install/
```

> **Important:** zls is tied to a specific Zig version and refuses to start on a mismatch. Install `zig` and `zls` from the same source (Homebrew or the official download tool) so they stay in sync. Distro packages often lag: Ubuntu/Debian stable ship no `zig`, and Arch's `zls` trails Arch's `zig`, so they usually mismatch.

Format-on-save uses ZLS (matches `zig fmt`); no separate formatter is needed. Build-on-save diagnostics (`enable_build_on_save`) can be enabled in a `zls.json` next to `build.zig`.

#### 2.8 Rust

```bash
# Install rustup (includes rustc & cargo), then:
rustup component add rust-analyzer
```

#### 2.9 YAML

```bash
# Install LSP server
npm install -g yaml-language-server
```

#### 2.10 Shell

```bash
# Install LSP server, then the shfmt formatter it depends on
npm install -g bash-language-server
go install mvdan.cc/sh/v3/cmd/shfmt@latest
```

#### 2.11 Markdown

Preview Markdown in browser via WSL/glow:

```bash
# Option 1: glow (terminal Markdown renderer)
# https://github.com/charmbracelet/glow
brew install glow       # macOS / Linuxbrew
sudo pacman -S glow     # Arch Linux
sudo apt-get install glow  # Debian 13+
go install github.com/charmbracelet/glow@latest  # Ubuntu / OpenSUSE / CentOS, or any platform with Go

# Option 2: Open in Windows browser (WSL only)
# :!explorer.exe %
```

Format & lint are provided by [efm-langserver](https://github.com/mattn/efm-langserver) (formatter: prettier, linter: markdownlint-cli2):

```bash
go install github.com/mattn/efm-langserver@latest
npm install -g prettier markdownlint-cli2
# Link the efm config (config.yaml + .markdownlint.jsonc) to efm's default path
ln -sf $(pwd)/configs/efm-langserver ~/.config/efm-langserver
```

#### 2.12 Fonts (optional)

Vim uses common Unicode characters (⎇, │, ▸, ·, ¬) and works without extra fonts. A [Nerd Font](https://github.com/ryanoasis/nerd-fonts) is optional if you prefer the Powerline-style look.

### 3. Health check

Verify that all required dependencies and optional LSP servers are available:

```bash
./checkhealth.sh
```

Pass `--install` to automatically install missing dependencies (required tools + optional LSP servers). Supports apt/zypper/dnf/pacman/brew, npm, pip, go install, and rustup:

```bash
./checkhealth.sh --install
```

### 4. Install monkey-vim

- Linux, Mac, WSL, and kmscon

```bash
cd monkey-vim
ln -sf $(pwd)/.vimrc ~/.vimrc
ln -sf $(pwd)/configs/.clang-format ~/.clang-format   # global clang-format style (optional)
ln -sf $(pwd)/configs/efm-langserver ~/.config/efm-langserver   # efm: markdown format/lint (optional)
vim
```

### 5. Update project

```bash
cd monkey-vim
git pull
```

```vim
:PlugInstall
:PlugUpdate
:PlugUpgrade
:PlugClean
```

### 6. kmscon setup (optional)

[kmscon](https://github.com/kmscon/kmscon) is a Linux KMS/DRM-based system console that replaces the legacy tty with full Unicode support, multi-seat capability, and true color rendering. It is an excellent companion for monkey-vim on headless servers.

#### 6.1 Install kmscon

```bash
# Ubuntu/Debian (older versions without terminfo)
sudo apt-get install kmscon

# OpenSUSE (Tumbleweed / Leap 15.x)
sudo zypper install kmscon

# Arch Linux
sudo pacman -S kmscon

# CentOS — not in official/EPEL repos, build from source below instead
# Build from source (requires meson, ninja, and ncurses for tic)
git clone https://github.com/kmscon/kmscon.git
cd kmscon
meson setup builddir/
meson install -C builddir/
```

Building from source automatically compiles and installs the kmscon terminfo entry via `tic`, so vim can detect terminal capabilities correctly without any `TERM` workaround. The default prefix is `/usr/local`; append `--prefix=/usr` to the meson setup command to install system-wide.

On older systems, dependencies like `libtsm` may be too old to satisfy the build requirements. In that case, use the package manager version and apply the `TERM` workaround in section 6.3.

#### 6.2 Replace tty with kmscon (permanent)

To make kmscon the default system console instead of the legacy tty/getty, replace agetty with kmscon on the desired tty:

```bash
# Stop the existing getty on tty1
sudo systemctl stop getty@tty1.service
sudo systemctl disable getty@tty1.service

# Create a kmscon service for tty1
sudo mkdir -p /etc/systemd/system/getty.target.wants
sudo ln -s /usr/lib/systemd/system/kmsconvt@.service \
    /etc/systemd/system/getty.target.wants/kmsconvt@tty1.service

# Override ExecStart to use kmscon's own terminal type
sudo systemctl edit kmsconvt@tty1.service
```

Add the following override:

```ini
[Service]
ExecStart=
ExecStart=/usr/bin/kmscon "--vt=%I" --seats=seat0 --no-switchvt --login -- /sbin/agetty -o '-p -- \\u' - kmscon
```

The last argument `kmscon` is agetty's `<termtype>` positional argument and sets `TERM=kmscon`, which matches the terminfo entry installed during build.

The terminal type differs by kmscon version, because the `kmscon` terminfo entry is only shipped since **10.0.0**:

```ini
# kmscon 10.0.0+ (ships scripts/terminfo/kmscon.ti, default TERM=kmscon)
ExecStart=/usr/bin/kmscon "--vt=%I" --seats=seat0 --no-switchvt --login -- /sbin/agetty -o '-p -- \\u' - kmscon

# kmscon 9.x (no kmscon terminfo entry; use xterm-256color)
ExecStart=/usr/bin/kmscon "--vt=%I" --seats=seat0 --no-switchvt --login -- /sbin/agetty -o '-p -- \\u' - xterm-256color
```

If your `agetty` build supports the `--noclear` flag, you may insert it before the `-` to keep the kmscon splash on the login prompt; it is purely cosmetic.

```bash
# Start kmscon on tty1
sudo systemctl start kmsconvt@tty1.service
```

After reboot, press `Ctrl+Alt+F1` to switch to the kmscon-enhanced tty1. You can repeat this for tty2–tty6 as needed.

##### `start` vs `enable` — a common pitfall

`systemctl start` runs a unit once and ignores the `[Install]` section entirely, so it never touches `autovt@.service`. `systemctl enable` reads `[Install]` and creates symlinks, including the `Alias=autovt@.service`.

tty2–tty6 are **not** started from `getty.target.wants`; systemd-logind spawns each newly-activated VT as `autovt@ttyN.service`, which resolves through the `autovt@.service` alias. That alias ships in Debian/Ubuntu's `kmsconvt@.service`:

```ini
[Install]
WantedBy=getty.target
DefaultInstance=tty1
Alias=autovt@.service
```

So:

- `systemctl enable kmsconvt@tty1.service` → only tty1 (instance alias `autovt@tty1.service`).
- `systemctl enable kmsconvt@.service` (template, no ttyN) → **every VT**, because it creates `/etc/systemd/system/autovt@.service -> kmsconvt@.service`.

The `ln -s ... kmsconvt@tty1.service` + `start` flow above therefore affects only tty1. If tty2–tty6 unexpectedly become kmscon, check for a leftover alias (see 6.5 to revert).

#### 6.3 True color support

kmscon supports true color (24-bit). monkey-vim detects this automatically via `has('termguicolors')` and renders GUI colors directly.

If kmscon was installed via package manager (older versions without terminfo) or the terminfo entry is missing, vim may fail with `E558: Terminal entry not found in terminfo`. In that case, add the following to your shell profile:

```bash
# Add to your shell profile (~/.bashrc, ~/.zshrc, etc.)
export TERM=xterm-256color
export COLORTERM=truecolor
```

The `COLORTERM=truecolor` is required so vim still detects true color support when `TERM` is set to `xterm-256color`. Note that using `xterm-256color` instead of kmscon's native terminfo may cause minor display artifacts in vim due to terminal capability mismatches. For the best experience, build from source (10.0.0+) to get the native terminfo entry.

If you run tmux inside kmscon, tmux overrides `$TERM` with `tmux` / `tmux-256color`. This is expected and correct — do **not** change it back. tmux derives its internal `TERM` from the outer terminal and exposes its own accurate capabilities, so vim and other ncurses programs work correctly. Only the **outer** `$TERM` (before entering tmux) matters: keep it as `kmscon` on 10.0.0+ or `xterm-256color` on 9.x.

The Linux framebuffer console (tty1–tty63, `TERM=linux`) only exposes 8/16 colors (`&t_Co < 256`), which triggers sonokai's guard (`&t_Co < 256 -> finish`) and leaves Vim's built-in 8/16-color highlighting, so code stays readable. sonokai itself does not require true color — it renders fine with the `cterm` palette on any 256-color terminal — but it does refuse to load when fewer than 256 colors are available. For the full sonokai scheme on a physical console, replace tty with kmscon (section 6.2) or use any 256-color/true-color terminal.

If you run tmux on a bare tty (not kmscon), tmux defaults to `default-terminal=tmux-256color`, which advertises 256 colors and xterm-style key sequences to every program inside it — even though the underlying console only has 8/16 colors. monkey-vim already detects this (it walks the process tree to see the real tty behind the tmux client) and falls back to Vim's built-in highlighting, so vim itself stays correct regardless. Other programs, however, do not get that protection and may render 256-color escapes the console cannot show. To keep them correct, set tmux's terminal type to match the 8-color console:

```bash
# In ~/.tmux.conf — only for tmux running on a bare Linux tty
set -g default-terminal "tmux"
set -g terminal-overrides ",linux:colors=16"
```

The first line makes tmux advertise a plain 8-color terminal to programs; the second tells tmux the underlying `linux` console has 16 colors (8 base + 8 bright) so it can downconvert sensibly. Do **not** add these lines when tmux runs under kmscon or a normal terminal emulator — there `tmux-256color` is correct.

#### 6.4 Fonts (optional)

kmscon uses the system's built-in font renderer. If you prefer Powerline-style icons, install a system monospace font of your choice.

#### 6.5 Revert to the legacy tty/getty

To hand the virtual consoles back to agetty:

```bash
# Stop the kmscon instance
sudo systemctl stop kmsconvt@tty1.service

# Remove the tty1 wants link created in section 6.2
sudo rm -f /etc/systemd/system/getty.target.wants/kmsconvt@tty1.service

# Restore getty on tty1
sudo systemctl enable getty@tty1.service
sudo systemctl start getty@tty1.service
```

If you previously ran `systemctl enable kmsconvt@.service` (the template), the `autovt@.service` alias now points at kmscon and keeps replacing every VT. Revert it explicitly:

```bash
# Point autovt@.service back at getty (drop the kmscon alias)
sudo systemctl disable kmsconvt@.service
sudo rm -f /etc/systemd/system/autovt@.service

# Re-enable getty (also restores getty@tty1.service)
sudo systemctl enable getty@.service

# Reload so logind picks up the change for newly-activated VTs
sudo systemctl daemon-reload
```

Verify the alias points at getty again:

```bash
readlink -f /etc/systemd/system/autovt@.service /usr/lib/systemd/system/autovt@.service
```

It should resolve to `getty@.service`.

## Plugin list

| Plugin                                                                                | Purpose                                          |
| ------------------------------------------------------------------------------------- | ------------------------------------------------ |
| [yegappan/lsp](https://github.com/yegappan/lsp)                                       | Language Server Protocol client                  |
| [hrsh7th/vim-vsnip](https://github.com/hrsh7th/vim-vsnip)                             | Snippet engine                                   |
| [hrsh7th/vim-vsnip-integ](https://github.com/hrsh7th/vim-vsnip-integ)                 | LSP snippet integration                          |
| [rafamadriz/friendly-snippets](https://github.com/rafamadriz/friendly-snippets)       | Snippet collection                               |
| [junegunn/fzf.vim](https://github.com/junegunn/fzf.vim)                               | Fuzzy file/buffer/tag finder                     |
| [dyng/ctrlsf.vim](https://github.com/dyng/ctrlsf.vim)                                 | Async code search (rg/ag backend)                |
| [sainnhe/sonokai](https://github.com/sainnhe/sonokai)                                 | Colorscheme                                      |
| [mg979/vim-visual-multi](https://github.com/mg979/vim-visual-multi)                   | Multiple cursors                                 |
| [monkoose/vim9-stargate](https://github.com/monkoose/vim9-stargate)                   | Easy motion (replaces vim-sneak)                 |
| [tpope/vim-fugitive](https://github.com/tpope/vim-fugitive)                           | Git wrapper                                      |
| [airblade/vim-gitgutter](https://github.com/airblade/vim-gitgutter)                   | Git diff in sign column                          |
| [ludovicchabant/vim-gutentags](https://github.com/ludovicchabant/vim-gutentags)       | Automatic ctags & gtags (GNU Global) generation  |
| [habamax/vim-dir](https://github.com/habamax/vim-dir)                                 | File manager / directory viewer (replaces netrw) |
| [tpope/vim-surround](https://github.com/tpope/vim-surround)                           | Surround text with parens/quotes/etc             |
| [svermeulen/vim-subversive](https://github.com/svermeulen/vim-subversive)             | Substitute with clipboard                        |
| [andymass/vim-matchup](https://github.com/andymass/vim-matchup)                       | Extended % matching                              |
| [wellle/targets.vim](https://github.com/wellle/targets.vim)                           | Additional text objects                          |
| [michaeljsmith/vim-indent-object](https://github.com/michaeljsmith/vim-indent-object) | Indent-based text objects                        |
| [cohama/lexima.vim](https://github.com/cohama/lexima.vim)                             | Auto-close brackets/parens                       |
| [tpope/vim-repeat](https://github.com/tpope/vim-repeat)                               | Repeat plugin maps with `.`                      |
| [Konfekt/FastFold](https://github.com/Konfekt/FastFold)                               | Faster folding for large files                   |
| [haya14busa/vim-asterisk](https://github.com/haya14busa/vim-asterisk)                 | Improved `*` / `#` search                        |
| [kshenoy/vim-signature](https://github.com/kshenoy/vim-signature)                     | Visual marks                                     |
| [junegunn/gv.vim](https://github.com/junegunn/gv.vim)                                 | Git commit browser                               |
| [romainl/vim-qf](https://github.com/romainl/vim-qf)                                   | Quickfix/Location list helpers                   |

## Keyboard shortcut

```text
The "Leader" key below means comma key.
```

### 1. Normal mode

#### 1.1 Remap

```text
s       Replace a motion/text object with clipboard content (see §1.7)
S       Replace from cursor to end of line with clipboard content (see §1.7)
Y       Copy from the cursor position to the end of the line, same as y$
H       To the first non-blank character of the line, same as ^
L       To the last character of the line, same as $
U       Redo, same as Ctrl-r
;       Enter command line mode, same as :
q       Quit current window (with special handling for diff/fugitive/quickfix)
Shift+q  Quit vim, same as :qa
t       Recording, same as the original q (normal and visual mode)

j       Move down one display line (gj), works on wrapped lines
k       Move up one display line (gk), works on wrapped lines
f       Search 1 char to jump with hints (stargate)
F       Search 2 consecutive chars to jump with hints (stargate)
gs      Select words/regions for multi-cursor editing (vim-visual-multi)
```

The following remaps work in both Insert mode and Command-line mode:

```text
Ctrl+p  Move up        (Up)
Ctrl+n  Move down      (Down)
Ctrl+b  Move left      (Left)
Ctrl+f  Move right     (Right)
Ctrl+a  Jump to start  (Home)
Ctrl+e  Jump to end    (End)
Ctrl+h  Backspace      (BackSpace)
Ctrl+d  Delete forward (Del)
```

#### 1.2 F1 ~ F5

```text
F1      Open CtrlSF search prompt
F2      Toggle CtrlSF search window
F3      Open a terminal at the bottom
F4      Toggle the global terminal at the bottom
F5      Toggle the global terminal on the right
```

#### 1.3 Buffer

```text
Leader+o    Open a new buffer with given file path in current window
[+b         Jump to previous buffer
]+b         Jump to next buffer
```

#### 1.4 Split

```text
Leader+Leader+s    Open a horizontal split with given file path in current window
Leader+Leader+v    Open a vertical split with given file path in current window

Ctrl+h      Jump to the left split
Ctrl+j      Jump to the below split
Ctrl+k      Jump to the above split
Ctrl+l      Jump to the right split
Leader+z    Toggle zoom
```

#### 1.5 Tab

```text
Leader+Leader+t    Open a tab with given file path in current window

[+t         Jump to previous tab
]+t         Jump to next tab
Leader+1~9  Jump to the 1~9 tab
Leader+[    Jump to first tab
Leader+]    Jump to last tab
```

#### 1.6 Search (vim-asterisk)

Pressing `*` or `#` highlights all occurrences of the word under cursor without moving. Press again to jump normally.

```text
*       Highlight current word without moving (press again to jump)
g*      Same as *, partial match
#       Same as *, search backward
g#      Same as g*, search backward
```

#### 1.7 Replace (vim-subversive)

```text
s{textobj}  Replace a text object with clipboard content (e.g. siw to replace current word)
ss          Replace entire current line with clipboard content
S           Replace from cursor to end of line with clipboard content
```

#### 1.8 LSP (Language Server Protocol)

```text
K                   Hover documentation for symbol under cursor
gh                  Show hover in popup

gd                  Go to definition (fallback to ctags if LSP fails)
gc                  Go to declaration
gt                  Go to type definition
gi                  Go to implementation
gr                  Show references

Leader+gd           Peek definition
Leader+gc           Peek declaration
Leader+gt           Peek type definition
Leader+gi           Peek implementation
Leader+gr           Peek references

Leader+rn           Rename symbol
[d                  Previous diagnostic
]d                  Next diagnostic
[D                  First diagnostic
]D                  Last diagnostic
Leader+gh           Show current line diagnostics (popup)
Leader+d            Show/hide current buffer diagnostics (location list)
```

Files are auto-formatted on save via LSP. Completion is enabled by default — LSP-powered suggestions appear automatically as you type. `K` looks up the word under the cursor: `:Man` by default, `:LspHover` in LSP-enabled filetypes, and `:help` in Vim/help files.

#### 1.9 Cscope & Ctags

```text
gs                  Find symbol under cursor (cscope)
gD                  Find global definition (cscope, fallback to ctags on failure)
gR                  Find callers (cscope)
g]                  Jump to the tag under cursor, listing all matches in quickfix
```

Cscope supports `c`, `d`, `e`, `f`, `g`, `i`, `s`, `t` query types, with results in quickfix.
Requires `cscope` and `gtags-cscope` database (auto-generated by gutentags).

#### 1.10 File/Buffer/Tag navigation (fzf.vim)

```text
Ctrl+p      Search files

Leader+b    Search buffers (C-d to delete, Enter to open)
Leader+t    Search buffer tags
Leader+p    Search project tags
Leader+f    Search function in buffer
Leader+e    Search line in buffer
```

#### 1.11 Fold

These are standard Vim built-in keys enhanced by FastFold for performance:

```text
za      When on a closed fold, open it. When on an open fold, close it and set 'foldenable'
zc      Close one fold under the cursor
zo      Open one fold under the cursor
zR      Open all folds
zM      Close all folds
zuz     Manually update all folds (FastFold)
```

#### 1.12 Marks (vim-signature)

```text
m[a-zA-Z]   Toggle mark and display it in the leftmost column
m,          Place the next available mark
m.          If no mark on line, place the next available mark. Otherwise, remove (first) existing mark

dm[a-zA-Z]  Delete mark[a-zA-Z]
m-          Delete all marks in current line
m<Space>    Delete all marks in current buffer

'[a-zA-Z]   Jump to the mark
]` / [`     Jump to next / previous mark
`] / `[     Jump by alphabetical order to next / previous mark
m/          View all marks in Location List

m[0-9]      Toggle the corresponding marker !@#$%^&*()

m<S-[0-9]>  Remove all markers of the same type
m<BS>       Remove all markers

]-          Jump to next line having a marker of the same type
[-          Jump to prev line having a marker of the same type
]=          Jump to next line having a marker of any type
[=          Jump to prev line having a marker of any type
m?          Open location list and display markers from current buffer
```

`:SignatureToggle` Show/hide marks without deleting them
`:SignatureRefresh` Re-sync marks and signs if they go out of sync

#### 1.13 vim-dir (File manager / directory viewer, replaces netrw)

```text
-           Open file directory in current window
~           Open project root or home directory in current window

Inside the directory listing:
<CR>/o      Enter directory or open file
O           Open with OS default application
s           Open in horizontal split
S           Open in vertical split
t           Open in new tab
-/<BS>/u    Go up one directory
i           Preview file (first 100 lines)
x/X         Toggle selection / select all
D or dd     Delete files/directories
R or rr     Rename files/directories
C/cc        Create directory / create file
p/P         Copy/move selected into current directory
.           Toggle hidden files
:DirFilter  Filter entries by regex (! to hide matches)
```

#### 1.14 Code search (ctrlsf)

```text
Leader+a        Search current word in current directory
```

#### 1.15 Surround (vim-surround)

```text
ys+textobj+surroundA        Add surround A for the region of textobj
yss+surroundA               Add surround A for current line
ds+surroundA                Delete surround A
cs+surroundA+surroundB      Change surround A to B
```

#### 1.16 Terminal

```text
F3      Open a terminal buffer
F4      Toggle the global terminal at the bottom
F5      Toggle the global terminal on the right
```

F3 opens a new terminal at the bottom. F4 and F5 toggle the single global terminal — F4 shows it at the bottom (20 rows), F5 on the right (half the width). While visible, either key hides it; while hidden, each key reopens it in its own position. It is shared across all tabs: hiding does not kill the job, and the same terminal (history included) reopens in whatever tab you are in.

Use `<Ctrl-\><Ctrl-n>` to switch from terminal mode to normal mode. In normal mode, `<ScrollWheelUp>` and `<ScrollWheelDown>` scroll the terminal buffer.

#### 1.17 Others

```text
Leader+ws       Save session
Leader+rs       Remove session (asks for confirmation; no-op when no session exists)
```

Sessions are saved to `~/.cache/vim/sessions/`. On Vim startup, a session is automatically restored from this directory.

Viminfo is per-project: command/search history, registers, the jumplist and file marks are stored in `~/.cache/vim/viminfo/<project-root-flattened>.viminfo` (project root detected by walking up from the startup directory for `.git`/`.root`/`.hg`/... markers, falling back to `~`), so histories do not leak between projects.

```text
'.              Jump to last changes
''              To the position before the latest jump, or where the last "m'" or "m" + backtick command was given
Ctrl+o          Go to [count] Older cursor position in jump list
Ctrl+i          Go to [count] newer cursor position in jump list
Ctrl+^          Edit the alternate file. Mostly the alternate file is the previously edited file
cod             Toggle diff
cop             Toggle paste (auto-disabled on leaving insert mode)
col             Toggle list
con             Clear search highlight
Leader+cr       Change project root (manual only, no auto-chdir on file open)
Leader+space        Strip trailing whitespace
Leader+Leader+space  Strip trailing whitespace + \\r (DOS newlines)
Leader+q            Toggle quickfix
Leader+l            Toggle location list
```

In quickfix/location windows (ack-style mappings):

- `o`/`Enter` — Open entry (file + line)
- `go` — Open in horizontal split
- `gO` — Open and focus new window
- `t` — Open in new tab
- `T` — Open in new tab (keep quickfix focused)
- `q` — Close quickfix window

Quickfix windows auto-resize to fit content (max 10 lines), auto-close when empty, and are placed at the bottom.

Note: `gdefault` is set, so `:s` performs global substitution (all matches per line) by default. The jumplist is persisted per project via the per-project viminfo. `jumpoptions+=stack` makes the jumplist behave like the tagstack.

#### 1.18 Auto-insert file headers

New `.sh` and `.py` files get a shebang line automatically inserted:

- `.sh` → `#!/usr/bin/env bash`
- `.py` → `#!/usr/bin/env python3`

#### 1.19 Match-up (extended % matching)

```text
%       Go forward to next matching word (cycles back from close to open)
g%      Go backward to previous matching word
[%      Go to previous outer open word (start of surrounding block)
]%      Go to next surrounding close word (end of surrounding block)
z%      Go inside nearest inner contained block
i%      Inside of any block (text object)
a%      Around any block (text object)
```

#### 1.20 Lexima (auto-close pairs)

Lexima automatically closes pairs: `()`, `[]`, `{}`, `""`, `''` and backtick pairs. Backspace inside an empty pair deletes both characters. Enter inside `{}` auto-indents and creates a closing brace. In vim files, `"` is not auto-paired (since `"` is the comment leader).

### 2. Insert mode

#### 2.1 Snippets (vim-vsnip)

```text
Ctrl+l      Expand snippet
Tab         Jump to next placeholder
Shift+Tab   Jump to previous placeholder
```

#### 2.2 FZF Completion

```text
Ctrl+x Ctrl+p   Fuzzy file path completion (fzf)
Ctrl+x Ctrl+l   Fuzzy line completion (fzf)
Ctrl+x Ctrl+b   Fuzzy buffer line completion (fzf)
Ctrl+x Ctrl+f   Built-in filename completion
Ctrl+x Ctrl+n   Built-in keyword completion
Ctrl+x Ctrl+o   Built-in omni completion
Ctrl+x Ctrl+]   Tag completion (fallback when LSP is slow/unavailable)
```

### 3. Visual mode

#### 3.1 Remap

```text
s       Replace selected text with clipboard content
;       Enter command line mode, same as :
<       Decrease indent, keep selection
>       Increase indent, keep selection
```

#### 3.2 Search

```text
*       Search selected text forward (standard vim behavior, enhanced by vim-asterisk)
#       Search selected text backward (standard vim behavior, enhanced by vim-asterisk)
```

#### 3.3 Replace

```text
# '\r' standard for newline

s{textobj}  Replace a text object with clipboard content (e.g. siw)
ss          Replace entire current line with clipboard content
S           Replace from cursor to end of line with clipboard content
```

#### 3.4 Easy motion (vim9-stargate)

```text
f       Search 1 character to jump with hints (stargate)
F       Search 2 consecutive characters to jump with hints (stargate)
```

#### 3.5 Code search (ctrlsf)

```text
Leader+a        Search selected text in current directory
```

#### 3.6 Surround (vim-surround)

```text
S+surroundA     Add surround A for selected text (vim-surround built-in)
```

### 4. Command line mode

```text
Ctrl+p  Previous command
Ctrl+n  Next command
Ctrl+a  Jump to the begin of the command line
Ctrl+e  Jump to the end of the command line
```

## Use git in vim

### 1. git for vim: [vim-fugitive](https://github.com/tpope/vim-fugitive)

#### Core

```vim
" Run an arbitrary git command. Similar to :!git [args] but chdir to the repository tree first.
:Git [args]

" Short alias for :Git
:G [args]
```

#### Common examples

```vim
:Git status
:Git diff
:Git commit
:Git log
:Git blame
:Git pull
:Git push
```

#### Staging / Writing / Blame

```vim
" Stage file (git add)
:Gwrite
" Stage and quit
:Gwq

" Delete file from git and buffer
:GDelete
" Delete from git, keep buffer
:GRemove
" Rename / move file
:GMove {dest}

" Blame current file in a scroll-bound split
:Git blame
```

#### Diffs

```vim
" Diff against index (staging area)
:Gdiffsplit
" Diff against HEAD (last commit)
:Gdiffsplit HEAD
" Always vertical
:Gvdiffsplit
```

#### Log and search

```vim
" git-log into quickfix list
:Gclog
" git-log into location list
:Gllog
" git-grep into quickfix list
:Ggrep [args]

" Browse file/commit in GitHub
:GBrowse
" Copy URL to clipboard
:GBrowse!
```

#### Git status buffer keymaps

In the `:Git` status buffer:

- `s` — Stage file
- `u` — Unstage file
- `-` — Stage/unstage toggle
- `X` — Discard changes
- `=` — Toggle inline diff
- `cc` — Commit
- `ca` — Amend last commit
- `cf` — Fixup commit
- `cs` — Squash commit
- `crc` — Revert commit
- `coo` — Checkout file
- `dd` — `:Gdiffsplit`
- `dv` — `:Gvdiffsplit`
- `gq` — Close status window

More help: `:h fugitive.txt` or <https://github.com/tpope/vim-fugitive#screencasts>

### 2. Git commit browser: [gv.vim](https://github.com/junegunn/gv.vim)

```vim
" Open git commit browser
:GV
" List commits affecting current file only
:GV!
" Fill location list with revisions of current file
:GV?
```

#### Keymaps

```text
Leader+gg       Open git status
Leader+gl       Git commit browser for current file (GV!)
Leader+gL       Open git commit browser (GV)
Leader+gd       Vertical diff against index
Leader+gD       Diff entire project against index
Leader+gb       Git blame
```

> `Leader+gb` / `Leader+gl` / `Leader+gL` also work in Visual mode to
> blame or browse commits for the selected lines.

### 3. Git diff gutter: [vim-gitgutter](https://github.com/airblade/vim-gitgutter)

#### Keymaps

```text
[h / ]h         Jump to previous/next hunk
Leader+hp       Preview current hunk
Leader+hs       Stage current hunk
Leader+hr       Undo current hunk
Leader+hS       Stage entire file
Leader+hR       Discard all changes in file
Leader+hq       Load hunks into quickfix (current file)
Leader+hQ       Load hunks into quickfix (all files)
```

## Useful Vim commands

### 1. SudoWrite

```vim
" Write the current file with root privileges (prompts for sudo password)
:SudoWrite
```

### 2. CtrlSF

```vim
" Search recursively in current directory for the pattern
" Jump to the first result unless ! is given.
:CtrlSF[!] [PATTERN] [path]

" Reopen CtrlSF window
:CtrlSFOpen

" Close CtrlSF window
:CtrlSFClose
```

### 3. Gutentags

```vim
" Generate tags for current file
:GutentagsUpdate

" Generate tags for current project
:GutentagsUpdate!
```

If GNU Global (`gtags`/`global`) and Pygments (`pygmentize`) are installed,
gutentags also generates the `GTAGS`/`GRTAGS`/`GPATH` databases in
`~/.cache/vim/tags/<project>/`. GNU Global provides native parsers for C/C++/Java,
and falls back to Pygments for all other languages (Python, Go, Rust,
JavaScript, etc.). The gtags database is queried with the `:cs` commands, or
directly with the `global` CLI.

### 4. fzf.vim

```vim
" Search files
:Files [QUERY]

" Search git-tracked files
:GFiles [QUERY]          " or :GitFiles
:GFiles?                 " show git status

" Search buffers (C-d to delete, Enter to open)
:Buffers [QUERY]

" Search lines in loaded buffers
:Lines [QUERY]

" Search lines in current buffer
:BLines [QUERY]

" Search tags in the project
:Tags [QUERY]

" Search buffer tags
:BTags [QUERY]

" Interactive grep (ripgrep)
:Rg [QUERY]              " or :RG for full-screen results

" Search with ag (Silver Searcher)
:Ag [QUERY]

" Search file history
:History [QUERY]

" Search command history
:History:

" Search search history
:History/

" Search marks
:Marks

" Search buffer-local marks
:BMarks

" Search jumps
:Jumps

" Search changes
:Changes

" Search help tags
:Helptags [QUERY]

" Search windows
:Windows

" Search git commits (current file)
:Commits [QUERY]         " :BCommits for buffer commits

" Search commands
:Commands

" Search key mappings
:Maps

" Search filetypes
:Filetypes

" Search snippets (UltiSnips)
:Snippets

" Search colorschemes
:Colors

" Search files via locate
:Locate [QUERY]
```

### 5. vim-qf (Quickfix helpers)

```vim
" Keep only matching entries in qf/loc list
:Keep {pattern}

" Remove matching entries
:Reject {pattern}

" Save current qf/loc list by name
:SaveList {name}

" Load named list
:LoadList {name}

" Execute command on every file in list
:Dofile {cmd}

" Execute command on every line in list
:Doline {cmd}
```

### 6. Sessions (native :mksession)

```vim
" Save session for the current project to ~/.cache/vim/sessions/
Leader+ws

" Delete the current session file (asks for confirmation)
Leader+rs
```

The session is automatically re-written when Vim exits (while a session is
tracked) and restored on startup from `~/.cache/vim/sessions/`.

### 7. LSP commands (yegappan/lsp)

```vim
" Symbol search across entire workspace
:LspSymbolSearch [query]

" Show outline of current file
:LspOutline

" Show symbols in popup
:LspDocumentSymbol

" Switch between source and header
:LspSwitchSourceHeader

" Show/server status
:LspShowAllServers

" Workspace management
:LspWorkspaceAddFolder {folder}
:LspWorkspaceRemoveFolder {folder}
:LspWorkspaceListFolders
```

## Precautions

- **Indentation convention** — monkey-vim applies indent settings per filetype:

| Filetype                                          | Style                    | Width |
| ------------------------------------------------- | ------------------------ | ----- |
| `c`, `cpp`, `go`, `sh`, `vim`, `sql`              | Hard tab (`noexpandtab`) | 4     |
| `zig`, `rust`, `python`, `markdown`               | Spaces (`expandtab`)     | 4     |
| `javascript`, `typescript`, `lua`, `yaml`, `json` | Spaces (`expandtab`)     | 2     |

The global default is 4-width hard tabs. To customize, override the `FileType` autocmds in your own vimrc after sourcing monkey-vim's.

- Vim clipboard integration

monkey-vim sets `clipboard=unnamed,unnamedplus` so vim's yank/delete automatically syncs to the system clipboard. Copied text persists in the system clipboard after vim exits (the system clipboard is owned by the display server / Wayland compositor / terminal, not by vim).

Depending on the environment, yanks reach the system clipboard through different routes (evaluated in this order at startup):

| Environment (checked in this order)                                                                                  | Route                                                                                                                                |
| -------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| SSH and OSC 52 usable — no tmux, or tmux with `set-clipboard on`                                                     | [OSC 52](https://vimhelp.org/term.txt.html#xterm-clipboard) escape sequence → local clipboard                                        |
| A display server is available (Wayland/X11, macOS/WSLg, or Wayland/X11 detected over SSH) and not a physical console | GUI clipboard                                                                                                                        |
| No display server and inside tmux — e.g. a non-SSH kmscon/tty, or SSH with `set-clipboard` off                       | tmux buffer (`tmux load-buffer -w`)                                                                                                  |
| Older Vim without the provider feature                                                                               | Provider routes skipped — GUI clipboard only with a display server; with none, no route is available and the clipboard does not sync |

Notes: the OSC 52 route requires a terminal with OSC 52 support and Vim ≥ 9.1.1984 (the one-click installer builds a current Vim). Inside tmux, `set-clipboard on` is required so paste queries don't block.

If you use a standalone clipboard manager (optional):

| Tool                                              | Platform  | Purpose                                                     |
| ------------------------------------------------- | --------- | ----------------------------------------------------------- |
| [parcellite](https://parcellite.sourceforge.net/) | X11       | Lightweight clipboard manager with persistent history       |
| [cliphist](https://github.com/sentriz/cliphist)   | Wayland   | Clipboard history for wlroots-based compositors             |
| Built-in                                          | macOS/WSL | System clipboard persists by default — no extra tool needed |

## Extra setup

### Build vim from source

Build Vim from source for the latest version with full features: GTK3 GUI, Wayland/X11 support, and Lua/Python3/Perl/Ruby integration. Pick the display server you use: **Wayland** (listed first), **X11 & Wayland**, or **kmscon / text console**.

> Note: Vim's Linux GUI is GTK-based — there is no Qt version, so the GTK3 packages below are required even on KDE (or any other Qt-based desktop). GTK3 apps run fine on any desktop environment.

#### 1. Install dependencies

> The `gpm` packages enable mouse support on the Linux text console (TTY), not on the desktop. Harmless to include.
>
> Optional CLI tools: `wl-clipboard` (Wayland, provides `wl-copy`/`wl-paste`), `xclip` or `xsel` (X11). Vim has built-in clipboard support via `--with-wayland` / `--with-x`, so these are only needed for command-line clipboard access outside Vim.

##### Ubuntu/Debian

Wayland:

```bash
sudo apt-get install libgtk-3-dev \
    libwayland-dev \
    libcairo2-dev \
    libgpm-dev \
    libncurses-dev \
    python3-dev \
    lua5.4 \
    liblua5.4-dev \
    perl \
    libperl-dev \
    ruby \
    ruby-dev
```

X11 & Wayland:

```bash
sudo apt-get install libgtk-3-dev \
    libx11-dev \
    libxt-dev \
    libxpm-dev \
    libwayland-dev \
    libcairo2-dev \
    libgpm-dev \
    libncurses-dev \
    python3-dev \
    lua5.4 \
    liblua5.4-dev \
    perl \
    libperl-dev \
    ruby \
    ruby-dev
```

##### OpenSUSE

Wayland:

```bash
sudo zypper install gtk3-devel \
    wayland-devel \
    cairo-devel \
    gpm-devel \
    ncurses-devel \
    python-devel \
    python3-devel \
    ruby-devel \
    lua-devel
```

X11 & Wayland:

```bash
sudo zypper install gtk3-devel \
    wayland-devel \
    xorg-x11-devel \
    libXpm-devel \
    libXt-devel \
    cairo-devel \
    gpm-devel \
    ncurses-devel \
    python-devel \
    python3-devel \
    ruby-devel \
    lua-devel
```

##### CentOS

> Enable EPEL first: `sudo dnf install epel-release`. The `gtk3-devel` package requires CentOS 8+ / EPEL 8+; it is not available on CentOS 7. `lua-devel` requires CRB (CodeReady Builder) repository: `sudo dnf config-manager --set-enabled crb` (CentOS 9) or `sudo dnf config-manager --set-enabled powertools` (CentOS 8).

Wayland:

```bash
sudo dnf install gtk3-devel \
    wayland-devel \
    cairo-devel \
    gpm-devel \
    ncurses-devel \
    python-devel \
    python3-devel \
    ruby-devel \
    lua-devel \
    perl \
    perl-devel \
    perl-ExtUtils-ParseXS \
    perl-ExtUtils-CBuilder \
    perl-ExtUtils-Embed
```

X11 & Wayland:

```bash
sudo dnf install gtk3-devel \
    wayland-devel \
    libX11-devel \
    libXpm-devel \
    libXt-devel \
    cairo-devel \
    gpm-devel \
    ncurses-devel \
    python-devel \
    python3-devel \
    ruby-devel \
    lua-devel \
    perl \
    perl-devel \
    perl-ExtUtils-ParseXS \
    perl-ExtUtils-CBuilder \
    perl-ExtUtils-Embed
```

##### Arch

Wayland:

```bash
sudo pacman -S gtk3 \
    wayland \
    gpm \
    ncurses \
    lua \
    perl \
    python \
    ruby
```

X11 & Wayland:

```bash
sudo pacman -S gtk3 \
    wayland \
    libx11 \
    libxt \
    libxpm \
    gpm \
    ncurses \
    lua \
    perl \
    python \
    ruby
```

**Mac** (terminal build, macOS system clipboard via Cocoa)

```bash
brew install python3 \
    ruby \
    lua
```

> Terminal Vim on macOS gets the system clipboard from the Darwin/Cocoa (AppKit) feature, which is enabled by default — do **not** pass `--disable-darwin`. Since no GTK/Motif/Athena dev libraries are installed, build with `--enable-gui=no` (see **mac** under "Compile and install" below), not `--enable-gui=auto`.

#### 2. Compile and install

##### Wayland

```bash
./configure --with-features=huge \
    --enable-gui=gtk3 \
    --enable-gpm \
    --with-wayland \
    --enable-python3interp \
    --enable-luainterp \
    --enable-perlinterp \
    --enable-rubyinterp \
    --enable-multibyte \
    --enable-terminal \
    --enable-fontset \
    --enable-cscope \
    --enable-fail-if-missing
make
sudo make install
```

> The GTK3 GUI auto-detects the Wayland backend at runtime; you can force it with `export GDK_BACKEND=wayland`. `--with-wayland` enables native Wayland support (`+wayland`, `+wayland_clipboard`) for terminal Vim, so clipboard access works even without the GUI.

##### X11 & Wayland

```bash
./configure --with-features=huge \
    --enable-gui=gtk3 \
    --enable-gpm \
    --with-x \
    --with-wayland \
    --enable-python3interp \
    --enable-luainterp \
    --enable-perlinterp \
    --enable-rubyinterp \
    --enable-multibyte \
    --enable-terminal \
    --enable-fontset \
    --enable-cscope \
    --enable-fail-if-missing
make
sudo make install
```

> `--with-x` adds X11 support (clipboard, drag & drop); `--with-wayland` enables native Wayland support (`+wayland`, `+wayland_clipboard`). A single GTK3 build runs on both Wayland and X11 by auto-detecting the display server at runtime. Use this if you need both — e.g., WSLg (no Wayland clipboard), where clipboard goes through XWayland but display is Wayland.
>
> **GTK3 vs GTK4.** On a regular Linux desktop you may build with GTK4 instead: install `libgtk-4-dev` (Debian/Ubuntu), `gtk4-devel` (openSUSE/CentOS) or `gtk4` (Arch), and pass `--enable-gui=gtk4`. Do **not** use GTK4 under WSL (WSLg). A GTK4 build drops X11 support entirely (`--enable-gui=gtk4` forces `--without-x`), so it has no `+xterm_clipboard`; the only remaining clipboard feature is `+wayland_clipboard`, which speaks the Wayland `data-control` protocol (`zwlr-data-control-unstable-v1` / `ext-data-control-v1`). WSLg's compositor does not implement that protocol — its clipboard is relayed to Windows over RDP and exposed to Linux apps through XWayland — so a GTK4 build under WSLg ends up with no working system clipboard. On WSL, keep GTK3 with `--with-x` (the "X11 & Wayland" build above), which reaches the clipboard through XWayland.

##### mac (terminal-only; system clipboard via Cocoa)

```bash
./configure --with-features=huge \
    --enable-gui=no \
    --disable-gpm \
    --enable-python3interp \
    --enable-luainterp \
    --enable-perlinterp \
    --enable-rubyinterp \
    --enable-multibyte \
    --enable-terminal \
    --enable-fontset \
    --enable-cscope \
    --enable-fail-if-missing
make
sudo make install
```

> On macOS the `"+`/`"*` registers come from the Darwin/Cocoa (AppKit) feature, enabled by default — keep it (no `--disable-darwin`), and `--enable-gui=no` just makes the build terminal-only. `--disable-gpm` is required: gpm (the Linux console-mouse library) doesn't exist on macOS and `--enable-fail-if-missing` would abort configure.

**kmscon / text console** (no GUI)

```bash
./configure --with-features=huge \
    --enable-gui=no \
    --enable-gpm \
    --with-osc52 \
    --enable-python3interp \
    --enable-luainterp \
    --enable-perlinterp \
    --enable-rubyinterp \
    --enable-multibyte \
    --enable-terminal \
    --enable-fontset \
    --enable-cscope \
    --enable-fail-if-missing
make
sudo make install
```

> On a console-only machine, build without GUI libraries — drop `--with-wayland` / `--with-x` and the `libgtk-3-dev` / Wayland / X11 packages. `--enable-gpm` keeps console mouse support, and `--enable-terminal` covers terminal mode.
>
> Without `--with-wayland` or `--with-x`, Vim has no system clipboard integration. The `"*` and `"+` registers are unavailable; copy/paste is limited to internal Vim registers (`""`, `"0`–`"9`, etc.).
>
> `--with-osc52` adds the OSC 52 clipboard provider (`+clipboard_provider`): yanks are sent to the **terminal emulator**, which writes the system clipboard. It thus works over ssh (e.g., into a headless box from Windows Terminal / iTerm2) and in desktop terminal emulators even without any GUI/X11 support compiled in; on a raw tty/kmscon console it is a no-op, since nothing parses the escape sequence there.

### Use vim to view man doc in shell

Put this in your bashrc:

```bash
export MANPAGER="env MAN_PN=1 vim -R +MANPAGER -"
```
