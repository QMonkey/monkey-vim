# monkey-vim

Read this in other languages: [简体中文](README.zh-CN.md)

## Introduction

The project monkey-vim, aims to make a powerful and fast terminal-native IDE.

**Positioning:** monkey-vim targets pure terminal environments — no GUI, no gvim, no built-in terminal multiplexing. Use it in:

| Environment | Description |
|---|---|
| Linux Terminal | xterm, kitty, alacritty, wezterm, gnome-terminal, etc. |
| macOS Terminal | Terminal.app, iTerm2, kitty, etc. |
| WSL | Windows Subsystem for Linux (WSL2 recommended) |
| Server TTY | Bare Linux console (tty1–tty63), Vim default 8/16-color highlighting (sonokai needs ≥256 colors) |
| kmscon | Kernel Mode Setting console — modern TTY replacement with true color and Unicode support |

Window/split management is delegated to tmux or your terminal emulator's native tabs.

## Screenshot

![vim](pictures/vim.png "vim")

## Requirements

- vim 9.0+
- A terminal environment (no GUI / gvim support)

## Installation

### 1. Git clone

```bash
git clone https://github.com/QMonkey/monkey-vim.git
```

### 2. Install dependencies

#### 2.1 Common tools

| Tool | Purpose | Required |
|---|---|---|
| curl | Plugin manager bootstrap | Yes |
| git | Plugin manager, vim-fugitive | Yes |
| [ripgrep](https://github.com/BurntSushi/ripgrep) (rg) | ctrlsf code search + fzf.vim file search | Yes |
| universal-ctags | gutentags tag generation | Yes |
| [GNU Global](https://www.gnu.org/software/global/) (`global`) | gutentags gtags (GTAGS) generation & navigation | Recommended |
| [Pygments](https://pygments.org/) (`pygmentize`) | gtags parser for non-C/C++ languages (Python, Go, Rust, JS, etc.) | Recommended |
| [fzf](https://github.com/junegunn/fzf) | Fuzzy finder (fzf.vim) | Yes |
| [bat](https://github.com/sharkdp/bat) | Syntax-highlighted file preview in fzf | Recommended |
| [delta](https://github.com/dandavison/delta) | Enhanced git diff preview (fugitive, fzf) | Recommended |
| [Homebrew](https://brew.sh/) | Fallback package manager for tools not in system repos (lua-language-server, marksman, fzf) | Required |

```bash
# Install Homebrew (all Linux distros — required for tools not in system repos)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

# Ubuntu/Debian
sudo apt-get install curl git ripgrep universal-ctags global python3-pygments nodejs npm gcc
brew install fzf bat git-delta

# OpenSUSE
sudo zypper install curl git ripgrep universal-ctags global python3-Pygments fzf bat git-delta nodejs npm gcc

# CentOS (enable EPEL for ripgrep/ctags/global/pygments/fzf/bat/delta)
sudo dnf install epel-release
sudo dnf install curl git ripgrep universal-ctags global global-ctags python3-pygments fzf bat git-delta nodejs npm gcc

# Arch Linux
sudo pacman -S curl git ripgrep ctags global python-pygments fzf bat git-delta nodejs npm gcc

# macOS
brew install curl git ripgrep universal-ctags global pygments fzf bat git-delta node
```

#### 2.2 LSP servers

Language Server Protocol support is provided by [yegappan/lsp](https://github.com/yegappan/lsp). Install the servers for languages you use:

| Language | LSP Server | Install |
|---|---|---|
| C/C++ | clangd | `sudo apt-get install clangd`, `sudo zypper install clang`, `sudo dnf install clang-tools-extra`, `sudo pacman -S clang`, or `brew install llvm` |
| Go | gopls | `go install golang.org/x/tools/gopls@latest` |
| Python | python-lsp-server | `pip3 install python-lsp-server` |
| Rust | rust-analyzer | `rustup component add rust-analyzer` |
| Lua | lua-language-server | `brew install lua-language-server` or `sudo pacman -S lua-language-server` |
| Shell | bash-language-server | `npm install -g bash-language-server` |
| Vim | vim-language-server | `npm install -g vim-language-server` |
| JavaScript | typescript-language-server | `npm install -g typescript-language-server typescript` |
| TypeScript | typescript-language-server | `npm install -g typescript-language-server typescript` |
| JSON | vscode-json-language-server | `npm install -g vscode-langservers-extracted` |
| YAML | yaml-language-server | `npm install -g yaml-language-server` |
| Markdown | marksman | `brew install marksman` or `sudo pacman -S marksman` |

Some LSP servers offload formatting/linting to **external tools** that must be installed separately. Without them the feature silently degrades (falls back to built-in diagnostics or skips the tool):

| Language | Tool | Role | Install |
|---|---|---|---|
| C/C++ | clang-tidy | linter (via `clangd --clang-tidy`) | `sudo apt-get install clang-tidy`, `sudo zypper install clang`, `sudo dnf install clang-tools-extra`, `sudo pacman -S clang`, or `brew install llvm` |
| Go | staticcheck | linter (via `gopls` `staticcheck`) | `go install honnef.co/go/tools/cmd/staticcheck@latest` |
| Shell | shfmt | formatter (via `bash-language-server`) | `go install mvdan.cc/sh/v3/cmd/shfmt@latest` |
| Python | black | formatter (via `pylsp` black plugin) | `pip3 install black` |

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

#### 2.7 Rust

```bash
# Install rustup (includes rustc & cargo), then:
rustup component add rust-analyzer
```

#### 2.8 YAML

```bash
# Install LSP server
npm install -g yaml-language-server
```

#### 2.9 Shell

```bash
# Install LSP server, then the shfmt formatter it depends on
npm install -g bash-language-server
go install mvdan.cc/sh/v3/cmd/shfmt@latest
```

#### 2.10 Markdown

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

#### 2.11 Fonts (optional)

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

**`start` vs `enable` — a common pitfall.**

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

| Plugin | Purpose |
|---|---|
| [yegappan/lsp](https://github.com/yegappan/lsp) | Language Server Protocol client |
| [hrsh7th/vim-vsnip](https://github.com/hrsh7th/vim-vsnip) | Snippet engine |
| [hrsh7th/vim-vsnip-integ](https://github.com/hrsh7th/vim-vsnip-integ) | LSP snippet integration |
| [rafamadriz/friendly-snippets](https://github.com/rafamadriz/friendly-snippets) | Snippet collection |
| [junegunn/fzf.vim](https://github.com/junegunn/fzf.vim) | Fuzzy file/buffer/tag finder |
| [dyng/ctrlsf.vim](https://github.com/dyng/ctrlsf.vim) | Async code search (rg/ag backend) |
| [itchyny/lightline.vim](https://github.com/itchyny/lightline.vim) | Status line |
| [sainnhe/sonokai](https://github.com/sainnhe/sonokai) | Colorscheme |
| [mg979/vim-visual-multi](https://github.com/mg979/vim-visual-multi) | Multiple cursors |
| [monkoose/vim9-stargate](https://github.com/monkoose/vim9-stargate) | Easy motion (replaces vim-sneak) |
| [tpope/vim-fugitive](https://github.com/tpope/vim-fugitive) | Git wrapper |
| [airblade/vim-gitgutter](https://github.com/airblade/vim-gitgutter) | Git diff in sign column |
| [ludovicchabant/vim-gutentags](https://github.com/ludovicchabant/vim-gutentags) | Automatic ctags & gtags (GNU Global) generation |
| [justinmk/vim-dirvish](https://github.com/justinmk/vim-dirvish) | Directory viewer (replaces netrw) |
| [tpope/vim-surround](https://github.com/tpope/vim-surround) | Surround text with parens/quotes/etc |
| [svermeulen/vim-subversive](https://github.com/svermeulen/vim-subversive) | Substitute with clipboard |
| [andymass/vim-matchup](https://github.com/andymass/vim-matchup) | Extended % matching |
| [wellle/targets.vim](https://github.com/wellle/targets.vim) | Additional text objects |
| [michaeljsmith/vim-indent-object](https://github.com/michaeljsmith/vim-indent-object) | Indent-based text objects |
| [cohama/lexima.vim](https://github.com/cohama/lexima.vim) | Auto-close brackets/parens |
| [tpope/vim-repeat](https://github.com/tpope/vim-repeat) | Repeat plugin maps with `.` |
| [tpope/vim-eunuch](https://github.com/tpope/vim-eunuch) | UNIX shell helpers (:SudoWrite, :W, :Delete, etc.) |
| [tpope/vim-obsession](https://github.com/tpope/vim-obsession) | Session management |
| [Konfekt/FastFold](https://github.com/Konfekt/FastFold) | Faster folding for large files |
| [haya14busa/vim-asterisk](https://github.com/haya14busa/vim-asterisk) | Improved `*` / `#` search |
| [kshenoy/vim-signature](https://github.com/kshenoy/vim-signature) | Visual marks |
| [airblade/vim-rooter](https://github.com/airblade/vim-rooter) | Auto-change working directory |
| [junegunn/gv.vim](https://github.com/junegunn/gv.vim) | Git commit browser |
| [romainl/vim-qf](https://github.com/romainl/vim-qf) | Quickfix/Location list helpers |

## Keyboard shortcut

```
The "Leader" key below means comma key.
```

### 1. Normal mode

#### 1.1 Remap

```
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

```
Ctrl+p  Move up        (Up)
Ctrl+n  Move down      (Down)
Ctrl+b  Move left      (Left)
Ctrl+f  Move right     (Right)
Ctrl+a  Jump to start  (Home)
Ctrl+e  Jump to end    (End)
Ctrl+h  Backspace      (BackSpace)
Ctrl+d  Delete forward (Del)
```

#### 1.2 F1 ~ F4

```
F1      Open CtrlSF search prompt
F2      Toggle CtrlSF search window
F3      Open a terminal at the bottom
F4      Toggle terminal buffer (open/hide)
```

#### 1.3 Buffer

```
Leader+o    Open a new buffer with given file path in current window
[+b         Jump to previous buffer
]+b         Jump to next buffer
```

#### 1.4 Split

```
Leader+Leader+s    Open a horizontal split with given file path in current window
Leader+Leader+v    Open a vertical split with given file path in current window

Ctrl+h      Jump to the left split
Ctrl+j      Jump to the below split
Ctrl+k      Jump to the above split
Ctrl+l      Jump to the right split
Leader+z    Toggle zoom
```

#### 1.5 Tab

```
Leader+Leader+t    Open a tab with given file path in current window

[+t         Jump to previous tab
]+t         Jump to next tab
Leader+1~9  Jump to the 1~9 tab
Leader+[    Jump to first tab
Leader+]    Jump to last tab
```

#### 1.6 Search (vim-asterisk)

Pressing `*` or `#` highlights all occurrences of the word under cursor without moving. Press again to jump normally.

```
*       Highlight current word without moving (press again to jump)
g*      Same as *, partial match
#       Same as *, search backward
g#      Same as g*, search backward
```

#### 1.7 Replace (vim-subversive)

```
s{textobj}  Replace a text object with clipboard content (e.g. siw to replace current word)
ss          Replace entire current line with clipboard content
S           Replace from cursor to end of line with clipboard content
```

#### 1.8 LSP (Language Server Protocol)

```
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

Files are auto-formatted on save via LSP. Completion is enabled by default — LSP-powered suggestions appear automatically as you type. `K` uses `:LspHover` as the keyword program for most filetypes.

#### 1.9 Cscope

```
gs                  Find symbol under cursor (cscope)
gD                  Find global definition (cscope, fallback to ctags on failure)
gR                  Find callers (cscope)
```

Cscope supports `c`, `d`, `e`, `f`, `g`, `i`, `s`, `t` query types, with results in quickfix.
Requires `cscope` and `gtags-cscope` database (auto-generated by gutentags).

#### 1.10 File/Buffer/Tag navigation (fzf.vim)

```
Ctrl+p      Search files

Leader+b    Search buffers (C-d to delete, Enter to open)
Leader+t    Search buffer tags
Leader+p    Search project tags
Leader+f    Search function in buffer
Leader+e    Search line in buffer
```

#### 1.11 Fold

These are standard Vim built-in keys enhanced by FastFold for performance:

```
za      When on a closed fold, open it. When on an open fold, close it and set 'foldenable'
zc      Close one fold under the cursor
zo      Open one fold under the cursor
zR      Open all folds
zM      Close all folds
zuz     Manually update all folds (FastFold)
```

#### 1.12 Marks (vim-signature)

```
m[a-zA-Z]   Toggle mark and display it in the leftmost column
m,          Place the next available mark
m.          If no mark on line, place the next available mark. Otherwise, remove (first) existing mark

dm[a-zA-Z]  Delete mark[a-zA-Z]
m-          Delete all marks in current line
m<Space>    Delete all marks in current buffer

'[a-zA-Z]   Jump to the mark
]`          Jump to next mark
[`          Jump to prev mark
`]          Jump by alphabetical order to next mark
`[          Jump by alphabetical order to prev mark
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

`:SignatureToggle`  Show/hide marks without deleting them
`:SignatureRefresh`  Re-sync marks and signs if they go out of sync

#### 1.13 Dirvish (Directory viewer, replaces netrw)

```
-           Open file directory in current window
~           Open project root or home directory in current window

<CR>        Enter directory or open file
o           Open in current window (edit)
a           Open in horizontal split
i           Open in vertical split
t           Open in new tab
-           Go up one directory
A/I/O       Disabled (use a/i/o instead)
x           Add files to arglist
R           Reload directory view
:Shdo       Generate shell script from lines (e.g., :%Shdo)
```

#### 1.14 Code search (ctrlsf)

```
Leader+a        Search current word in current directory
```

#### 1.15 Surround (vim-surround)

```
ys+textobj+surroundA        Add surround A for the region of textobj
yss+surroundA               Add surround A for current line
ds+surroundA                Delete surround A
cs+surroundA+surroundB      Change surround A to B
```

#### 1.16 Terminal

```
F3      Open a terminal buffer
F4      Toggle terminal buffer (open/hide)
```

F3 opens a new terminal at the bottom. F4 toggles the terminal — hides it without killing the job, reopens the same terminal on demand.

Use `<Ctrl-\><Ctrl-n>` to switch from terminal mode to normal mode. In normal mode, `<ScrollWheelUp>` and `<ScrollWheelDown>` scroll the terminal buffer.

#### 1.17 Others

```
Leader+ws       Save session
Leader+rs       Remove session
```

Sessions are saved to `~/.cache/sessions/`. On Vim startup, a session is automatically restored from this directory.

```
'.              Jump to last changes
''              To the position before the latest jump, or where the last "m'" or "m`" command was given
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

Note: `gdefault` is set, so `:s` performs global substitution (all matches per line) by default. The jumplist is cleared on each Vim startup (`clearjumps`) to avoid cross-project contamination. `jumpoptions+=stack` makes the jumplist behave like the tagstack.

#### 1.18 Auto-insert file headers

New `.sh` and `.py` files get a shebang line automatically inserted:
- `.sh` → `#!/usr/bin/env bash`
- `.py` → `#!/usr/bin/env python3`

#### 1.19 Match-up (extended % matching)

```
%       Go forward to next matching word (cycles back from close to open)
g%      Go backward to previous matching word
[%      Go to previous outer open word (start of surrounding block)
]%      Go to next surrounding close word (end of surrounding block)
z%      Go inside nearest inner contained block
i%      Inside of any block (text object)
a%      Around any block (text object)
```

#### 1.20 Lexima (auto-close pairs)

Lexima automatically closes pairs: `()`, `[]`, `{}`, `""`, `''`, ```` ``` ````. Backspace inside an empty pair deletes both characters. Enter inside `{}` auto-indents and creates a closing brace. In vim files, `"` is not auto-paired (since `"` is the comment leader).

### 2. Insert mode

#### 2.1 Snippets (vim-vsnip)

```
Ctrl+l      Expand snippet
Tab         Jump to next placeholder
Shift+Tab   Jump to previous placeholder
```

#### 2.2 FZF Completion

```
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

```
s       Replace selected text with clipboard content
;       Enter command line mode, same as :
<       Decrease indent, keep selection
>       Increase indent, keep selection
```

#### 3.2 Search

```
*       Search selected text forward (standard vim behavior, enhanced by vim-asterisk)
#       Search selected text backward (standard vim behavior, enhanced by vim-asterisk)
```

#### 3.3 Replace

```
# '\r' standard for newline

s{textobj}  Replace a text object with clipboard content (e.g. siw)
ss          Replace entire current line with clipboard content
S           Replace from cursor to end of line with clipboard content
```

#### 3.4 Easy motion (vim9-stargate)

```
f       Search 1 character to jump with hints (stargate)
F       Search 2 consecutive characters to jump with hints (stargate)
```

#### 3.5 Code search (ctrlsf)

```
Leader+a        Search selected text in current directory
```

#### 3.6 Surround (vim-surround)

```
S+surroundA     Add surround A for selected text (vim-surround built-in)
```

### 4. Command line mode

```
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

More help: `:h fugitive.txt` or https://github.com/tpope/vim-fugitive#screencasts

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

```
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

```
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

### 1. vim-eunuch (UNIX shell helpers)

```vim
" Like :wall, but writes all windows rather than all buffers
:W

" Write all modified buffers
:wall

" Write file with sudo privileges
:SudoWrite

" Edit file with sudo
:SudoEdit {file}

" Delete file from disk and buffer
:Delete
" Delete file from disk, keep buffer
:Remove

" Rename / move file
:Rename {dest}

" Copy file
:Copy {dest}

" Change permissions
:Chmod {mode}

" Create directory (incl. parents)
:Mkdir {dir}
" Mkdir on its own creates the current file's parent dir

" Find files (results in quickfix)
:Cfind {args}
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
`~/.cache/tags/<project>/`. GNU Global provides native parsers for C/C++/Java,
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

### 6. vim-obsession (Session management)

```vim
" Start/update session in ~/.cache/sessions/
:Obsession {file}

" Toggle pause/resume session tracking
:Obsession

" Stop and delete session file
:Obsession!
```

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

| Filetype | Style | Width |
|---|---|---|
| `c`, `cpp`, `go`, `sh`, `vim`, `sql` | Hard tab (`noexpandtab`) | 4 |
| `rust`, `python`, `markdown` | Spaces (`expandtab`) | 4 |
| `javascript`, `typescript`, `lua`, `yaml`, `json` | Spaces (`expandtab`) | 2 |

The global default is 4-width hard tabs. To customize, override the `FileType` autocmds in your own vimrc after sourcing monkey-vim's.

- Vim clipboard integration

monkey-vim sets `clipboard=unnamed,unnamedplus` so vim's yank/delete automatically syncs to the system clipboard. Copied text persists in the system clipboard after vim exits (the system clipboard is owned by the display server / Wayland compositor / terminal, not by vim).

If you use a standalone clipboard manager (optional):

| Tool | Platform | Purpose |
|---|---|---|
| [parcellite](https://parcellite.sourceforge.net/) | X11 | Lightweight clipboard manager with persistent history |
| [cliphist](https://github.com/sentriz/cliphist) | Wayland | Clipboard history for wlroots-based compositors |
| Built-in | macOS/WSL | System clipboard persists by default — no extra tool needed |

## Extra setup

### Build vim from source

Build Vim from source for the latest version with full features: GTK3 GUI, Wayland/X11 support, and Lua/Python3/Perl/Ruby integration. Pick the display server you use: **Wayland** (listed first), **X11 & Wayland**, or **kmscon / text console**.

> Note: Vim's Linux GUI is GTK-based — there is no Qt version, so the GTK3 packages below are required even on KDE (or any other Qt-based desktop). GTK3 apps run fine on any desktop environment.

#### 1. Install dependencies

> The `gpm` packages enable mouse support on the Linux text console (TTY), not on the desktop. Harmless to include.
>
> Optional CLI tools: `wl-clipboard` (Wayland, provides `wl-copy`/`wl-paste`), `xclip` or `xsel` (X11). Vim has built-in clipboard support via `--with-wayland` / `--with-x`, so these are only needed for command-line clipboard access outside Vim.

**Ubuntu/Debian**

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

**OpenSUSE**

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

**CentOS**

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

**Arch**

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

**Mac** (native GUI, no Wayland/X11 needed)

```bash
brew install python \
	python3 \
	ruby \
	lua \
	cairo
```

#### 2. Compile and install

**Wayland**

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

**X11 & Wayland**

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

**kmscon / text console** (no GUI)

```bash
./configure --with-features=huge \
	--enable-gui=no \
	--enable-gpm \
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

### Use vim to view man doc in shell

Put this in your bashrc:

```bash
export MANPAGER="env MAN_PN=1 vim -R +MANPAGER -"
```
