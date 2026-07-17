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
| Server TTY | Bare Linux console (tty1–tty63), 256-color fallback |
| kmscon | Kernel Mode Setting console — modern TTY replacement with true color and Unicode support |

Window/split management is delegated to tmux or your terminal emulator's native tabs.

## Screenshot

![vim](pictures/xterm_vim.png "vim")

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
| [ripgrep (rg)](https://github.com/BurntSushi/ripgrep) | ctrlsf code search + LeaderF Rg backend | Yes |
| universal-ctags | gutentags tag generation | Yes |
| cmake | Build LeaderF C extension | Yes (compile-time only) |

```bash
# Ubuntu/Debian
sudo apt-get install curl git ripgrep universal-ctags cmake

# Arch Linux
sudo pacman -S curl git ripgrep ctags cmake

# macOS
brew install curl git ripgrep universal-ctags cmake
```
#### 2.2 LSP servers

Language Server Protocol support is provided by [yegappan/lsp](https://github.com/yegappan/lsp). Install the servers for languages you use:

| Language | LSP Server | Install |
|---|---|---|
| C/C++ | clangd | `sudo apt-get install clangd` or `brew install llvm` |
| Go | gopls | `go install golang.org/x/tools/gopls@latest` |
| Python | python-lsp-server | `pip install python-lsp-server` |
| Rust | rust-analyzer | `rustup component add rust-analyzer` |
| Lua | lua-language-server | `sudo apt-get install lua-language-server` or `brew install lua-language-server` |
| Shell | bash-language-server | `npm install -g bash-language-server` |
| Vim | vim-language-server | `npm install -g vim-language-server` |
| JavaScript | typescript-language-server | `npm install -g typescript-language-server typescript` |
| TypeScript | typescript-language-server | `npm install -g typescript-language-server typescript` |
| JSON | vscode-json-language-server | `npm install -g vscode-langservers-extracted` |
| YAML | yaml-language-server | `npm install -g yaml-language-server` |
| Markdown | marksman | `sudo apt-get install marksman` or `brew install marksman` |

#### 2.3 C/C++

```bash
# Ubuntu
sudo apt-get install gcc g++ clangd clang-format

# macOS
brew install gcc llvm clang-format
```

#### 2.4 Go

```bash
# Install the latest version of Go, then:
go install golang.org/x/tools/gopls@latest
```

#### 2.5 Python

```bash
pip install python-lsp-server
# Optional: formatters/linters
pip install autopep8 flake8 pylint
```

#### 2.6 JavaScript / TypeScript

```bash
# Install LSP server
npm install -g typescript-language-server typescript
```

#### 2.7 Rust

```bash
# Install rust-analyzer via rustup
rustup component add rust-analyzer
```

#### 2.8 YAML

```bash
# Install LSP server
npm install -g yaml-language-server
```

#### 2.9 Markdown

Preview Markdown in browser via WSL/glow:
```bash
# Option 1: glow (terminal Markdown renderer)
# https://github.com/charmbracelet/glow
brew install glow  # or: go install github.com/charmbracelet/glow@latest

# Option 2: Open in Windows browser (WSL only)
# :!explorer.exe %
```

#### 2.10 Fonts (optional)

Vim uses common Unicode characters (⎇, │, 🔒, ▸, ·, ¬) and works without extra fonts. A [Nerd Font](https://github.com/ryanoasis/nerd-fonts) (e.g. Hack Nerd Font) is optional if you prefer the Powerline-style look.

- [Hack Nerd Font](https://github.com/ryanoasis/nerd-fonts/tree/master/patched-fonts/Hack)

### 3. Health check

Verify that all required dependencies and optional LSP servers are available:

```bash
./checkhealth.sh
```

Pass `--install` to automatically install missing required dependencies (supports apt/pacman/brew):

```bash
./checkhealth.sh --install
```

### 4. Install monkey-vim

- Linux, Mac, WSL, and kmscon

```bash
cd monkey-vim
ln -s $(pwd)/.vimrc ~/.vimrc
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

# Arch Linux
sudo pacman -S kmscon

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
ExecStart=/usr/bin/kmscon "--vt=%I" --seats=seat0 --no-switchvt \
    --login -- /sbin/agetty -o '-p -- \\u' - --noclear %I kmscon
```

The last argument `kmscon` tells agetty to set `TERM=kmscon`, which matches the terminfo entry installed during build.

```bash
# Start kmscon on tty1
sudo systemctl start kmsconvt@tty1.service
```

After reboot, press `Ctrl+Alt+F1` to switch to the kmscon-enhanced tty1. You can repeat this for tty2–tty6 as needed.

#### 6.3 True color support

kmscon supports true color (24-bit). monkey-vim detects this automatically via `has('termguicolors')` and renders GUI colors directly.

If kmscon was installed via package manager (older versions without terminfo) or the terminfo entry is missing, vim may fail with `E558: Terminal entry not found in terminfo`. In that case, add the following to your shell profile:

```bash
# Add to your shell profile (~/.bashrc, ~/.zshrc, etc.)
export TERM=xterm-256color
export COLORTERM=truecolor
```

The `COLORTERM=truecolor` is required so vim still detects true color support when `TERM` is set to `xterm-256color`. Note that using `xterm-256color` instead of kmscon's native terminfo may cause minor display artifacts in vim due to terminal capability mismatches. For the best experience, build from source to get the native terminfo entry.

If you fall back to a traditional Linux tty (tty1–tty63), monkey-vim degrades to 256-color mode with sonokai's dark palette for accurate color approximation.

#### 6.4 Fonts (optional)

kmscon uses the system's built-in font renderer. If you prefer Powerline-style icons, install a Nerd Font:

```bash
# Download and install Hack Nerd Font system-wide
wget https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Hack.zip
sudo unzip -o Hack.zip -d /usr/share/fonts/truetype/hack
sudo fc-cache -fv
```

## Plugin list

| Plugin | Purpose |
|---|---|
| [yegappan/lsp](https://github.com/yegappan/lsp) | Language Server Protocol client |
| [hrsh7th/vim-vsnip](https://github.com/hrsh7th/vim-vsnip) | Snippet engine |
| [hrsh7th/vim-vsnip-integ](https://github.com/hrsh7th/vim-vsnip-integ) | LSP snippet integration |
| [rafamadriz/friendly-snippets](https://github.com/rafamadriz/friendly-snippets) | Snippet collection |
| [Yggdroot/LeaderF](https://github.com/Yggdroot/LeaderF) | Fuzzy file/buffer/tag finder |
| [dyng/ctrlsf.vim](https://github.com/dyng/ctrlsf.vim) | Async code search (rg/ag backend) |
| [skywind3000/asyncrun.vim](https://github.com/skywind3000/asyncrun.vim) | Async command runner |
| [itchyny/lightline.vim](https://github.com/itchyny/lightline.vim) | Status line |
| [sainnhe/sonokai](https://github.com/sainnhe/sonokai) | Colorscheme |
| [mg979/vim-visual-multi](https://github.com/mg979/vim-visual-multi) | Multiple cursors |
| [monkoose/vim9-stargate](https://github.com/monkoose/vim9-stargate) | Easy motion (replaces vim-sneak) |
| [tpope/vim-fugitive](https://github.com/tpope/vim-fugitive) | Git wrapper |
| [airblade/vim-gitgutter](https://github.com/airblade/vim-gitgutter) | Git diff in sign column |
| [ludovicchabant/vim-gutentags](https://github.com/ludovicchabant/vim-gutentags) | Automatic ctags generation |
| [justinmk/vim-dirvish](https://github.com/justinmk/vim-dirvish) | Directory viewer (replaces netrw) |
| [tpope/vim-surround](https://github.com/tpope/vim-surround) | Surround text with parens/quotes/etc |
| [svermeulen/vim-subversive](https://github.com/svermeulen/vim-subversive) | Substitute with clipboard |
| [andymass/vim-matchup](https://github.com/andymass/vim-matchup) | Extended % matching |
| [wellle/targets.vim](https://github.com/wellle/targets.vim) | Additional text objects |
| [michaeljsmith/vim-indent-object](https://github.com/michaeljsmith/vim-indent-object) | Indent-based text objects |
| [cohama/lexima.vim](https://github.com/cohama/lexima.vim) | Auto-close brackets/parens |
| [tpope/vim-repeat](https://github.com/tpope/vim-repeat) | Repeat plugin maps with `.` |
| [tpope/vim-eunuch](https://github.com/tpope/vim-eunuch) | UNIX shell helpers (:W for sudo write) |
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
F3      Open async Make prompt
F4      Open AsyncRun prompt
```

#### 1.3 Buffer

```
Leader+o    Open a new buffer with given file path in current window
[+b         Jump to previous buffer
]+b         Jump to next buffer
```

#### 1.4 Split

```
Leader+s    Open a horizontal split with given file path in current window
Leader+v    Open a vertical split with given file path in current window

Ctrl+h      Jump to the left split
Ctrl+j      Jump to the below split
Ctrl+k      Jump to the above split
Ctrl+l      Jump to the right split
Leader+z    Toggle zoom
```

#### 1.5 Tab

```
Leader+t    Open a tab with given file path in current window

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

gd                  Go to definition
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
Leader+gh           Show current line diagnostics
```

Files are auto-formatted on save via LSP. Completion is enabled by default — LSP-powered suggestions appear automatically as you type. `K` uses `:LspHover` as the keyword program for most filetypes.

#### 1.9 File/Buffer/Tag navigation (LeaderF)

```
Ctrl+p      Search files

Leader+b    Search buffers
Leader+y    Search buffer tags
Leader+f    Search function in buffer
Leader+e    Search line in buffer
```

#### 1.10 Fold

These are standard Vim built-in keys enhanced by FastFold for performance:

```
za      When on a closed fold, open it. When on an open fold, close it and set 'foldenable'
zc      Close one fold under the cursor
zo      Open one fold under the cursor
zR      Open all folds
zM      Close all folds
zuz     Manually update all folds (FastFold)
```

#### 1.11 Marks (vim-signature)

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

#### 1.12 Dirvish (Directory viewer, replaces netrw)

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

#### 1.13 Code search (ctrlsf)

```
Leader+a        Search current word in current directory
```

#### 1.14 Surround (vim-surround)

```
ys+textobj+surroundA        Add surround A for the region of textobj
yss+surroundA               Add surround A for current line
ds+surroundA                Delete surround A
cs+surroundA+surroundB      Change surround A to B
```

#### 1.15 Async run

```
F3      Async make (replaces built-in :make with asyncrun)
F4      Async run arbitrary command
```

The `:Make` command runs `make` asynchronously — it doesn't block Vim. The quickfix window opens automatically on completion.

#### 1.16 Others

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

#### 1.17 Auto-insert file headers

New `.sh` and `.py` files get a shebang line automatically inserted:
- `.sh` → `#!/usr/bin/env bash`
- `.py` → `#!/usr/bin/env python3`

#### 1.18 Match-up (extended % matching)

```
%       Go forward to next matching word (cycles back from close to open)
g%      Go backward to previous matching word
[%      Go to previous outer open word (start of surrounding block)
]%      Go to next surrounding close word (end of surrounding block)
z%      Go inside nearest inner contained block
i%      Inside of any block (text object)
a%      Around any block (text object)
```

#### 1.19 Lexima (auto-close pairs)

Lexima automatically closes pairs: `()`, `[]`, `{}`, `""`, `''`, ` ``` `. Backspace inside an empty pair deletes both characters. Enter inside `{}` auto-indents and creates a closing brace. In vim files, `"` is not auto-paired (since `"` is the comment leader).

### 2. Insert mode

#### 2.1 Snippets (vim-vsnip)

```
Ctrl+l      Expand snippet
Tab         Jump to next placeholder
Shift+Tab   Jump to previous placeholder
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

## Useful command

### 1. W (vim-eunuch)

```vim
" Save file with root permission
:W
```

### 2. CtrlSF

```vim
" Search recursively in current directory for the pattern
" Jump to the first result unless ! is given.
:CtrlSF[!] [PATTERN]
```

### 3. GutentagsUpdate

```vim
" Generate tags for current file
:GutentagsUpdate

" Generate tags for current project
:GutentagsUpdate!
```

### 4. LeaderF

```vim
" Search files
:LeaderfFile [QUERY]

" Search buffers
:LeaderfBuffer [QUERY]

" Search tags in the project
:LeaderfTag [QUERY]

" Search buffer tags
:LeaderfBufTag [QUERY]

" Search functions
:LeaderfFunction [QUERY]

" Search marks
:LeaderfMarks [QUERY]

" Search lines in buffer
:LeaderfLine [QUERY]

" Search MRU files
:LeaderfMru [QUERY]

" Interactive ripgrep search
:LeaderfRgInteractive [QUERY]

" Search command history
:LeaderfHistoryCmd

" Search help tags
:LeaderfHelp [QUERY]
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

### 3. Git diff gutter: [vim-gitgutter](https://github.com/airblade/vim-gitgutter)

```vim
" Jump to next/previous hunk
]c / [c

" Preview / stage / undo current hunk
:GitGutterPreviewHunk
:GitGutterStageHunk
:GitGutterUndoHunk

" Fold all unchanged lines
:GitGutterFold

" Load all hunks into quickfix
:GitGutterQuickFix
```

## Useful Vim commands

### 1. vim-eunuch (UNIX shell helpers)

```vim
" Write all modified buffers in all windows
:W (:wall)

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
"Mkdir on its own creates the current file's parent dir

" Find files (results in quickfix)
:Cfind {args}
```

### 2. asyncrun.vim

```vim
" Run command asynchronously (doesn't block Vim)
:AsyncRun {cmd}

" Options:
" -program=make    — set program name for output formatting
" -cwd=<root>      — run from project root
" -save=2          — auto-save all modified files
" -silent          — suppress quickfix popup
" -mode=term       — run in terminal window

" Stop running job
:AsyncStop

" Make (custom command from monkey-vim)
:Make [args]
```

### 3. CtrlSF

```vim
" Search recursively in current directory for the pattern
" Jump to the first result unless ! is given.
:CtrlSF[!] [PATTERN] [path]

" Reopen CtrlSF window
:CtrlSFOpen

" Close CtrlSF window
:CtrlSFClose
```

### 4. Gutentags

```vim
" Generate tags for current file
:GutentagsUpdate

" Generate tags for current project
:GutentagsUpdate!
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

## Recommended settings

- [Build vim from source](https://github.com/QMonkey/monkey-vim/wiki/Build-Vim-from-source)

- Use vim to view man doc in shell, put this in your bashrc:

```bash
export MANPAGER="env MAN_PN=1 vim -R +MANPAGER -"
```
