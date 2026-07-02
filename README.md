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

- **xterm vim**

![xterm vim](pictures/xterm_vim.png "xterm vim")

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
| [fd](https://github.com/sharkdp/fd) | LeaderF file search backend | Yes |
| [ripgrep (rg)](https://github.com/BurntSushi/ripgrep) | ctrlsf code search backend | Yes |
| universal-ctags | gutentags tag generation | Yes |
| cmake | Build LeaderF C extension | Yes (compile-time only) |

```bash
# Ubuntu/Debian
sudo apt-get install curl git fd-find ripgrep universal-ctags cmake

# Arch Linux
sudo pacman -S curl git fd ripgrep ctags cmake

# macOS
brew install curl git fd ripgrep universal-ctags cmake
```

#### 2.2 Fonts

[Nerd Font](https://github.com/ryanoasis/nerd-fonts) (e.g. Hack Nerd Font) is recommended for Powerline icons in the status line.

- [Hack Nerd Font](https://github.com/ryanoasis/nerd-fonts/tree/master/patched-fonts/Hack)

#### 2.3 LSP servers

Language Server Protocol support is provided by [yegappan/lsp](https://github.com/yegappan/lsp). Install the servers for languages you use:

| Language | LSP Server | Install |
|---|---|---|
| C/C++ | clangd | `sudo apt-get install clangd` or `brew install llvm` |
| Go | gopls | `go install golang.org/x/tools/gopls@latest` |
| Python | python-lsp-server | `pip install python-lsp-server` |
| Rust | rust-analyzer | `rustup component add rust-analyzer` or `brew install rust-analyzer` |
| Lua | lua-language-server | `sudo apt-get install lua-language-server` or `brew install lua-language-server` |
| Shell | bash-language-server | `npm install -g bash-language-server` |
| Vim | vim-language-server | `npm install -g vim-language-server` |
| JavaScript | typescript-language-server | `npm install -g typescript-language-server typescript` |
| TypeScript | typescript-language-server | `npm install -g typescript-language-server typescript` |
| JSON | vscode-json-language-server | `npm install -g vscode-langservers-extracted` |
| YAML | yaml-language-server | `npm install -g yaml-language-server` |
| Markdown | marksman | `sudo apt-get install marksman` or `brew install marksman` |

#### 2.4 C/C++

```bash
# Ubuntu
sudo apt-get install gcc g++ clangd clang-format

# macOS
brew install gcc llvm clang-format
```

#### 2.5 Go

```bash
# Install the latest version of Go, then:
go install golang.org/x/tools/gopls@latest
```

#### 2.6 Python

```bash
pip install python-lsp-server
# Optional: formatters/linters
pip install autopep8 flake8 pylint
```

#### 2.7 JavaScript / TypeScript

```bash
# Install LSP server
npm install -g typescript-language-server typescript
```

#### 2.8 Rust

```bash
# Install rust-analyzer via rustup
rustup component add rust-analyzer
# Or via brew
brew install rust-analyzer
```

#### 2.9 YAML

```bash
# Install LSP server
npm install -g yaml-language-server
```

#### 2.10 Markdown

Preview Markdown in browser via WSL/glow:
```bash
# Option 1: glow (terminal Markdown renderer)
# https://github.com/charmbracelet/glow
brew install glow  # or: go install github.com/charmbracelet/glow@latest

# Option 2: Open in Windows browser (WSL only)
# :!explorer.exe %
```

### 3. Install monkey-vim

- Linux, Mac, WSL, and kmscon

```bash
cd monkey-vim
ln -s $(pwd)/.vimrc ~/.vimrc
vim
```

### 4. kmscon setup (optional)

[kmscon](https://github.com/dvdhrm/kmscon) is a Linux KMS/DRM-based system console that replaces the legacy tty with full Unicode support, multi-seat capability, and true color rendering. It is an excellent companion for monkey-vim on headless servers.

#### 4.1 Install kmscon

```bash
# Ubuntu/Debian
sudo apt-get install kmscon

# Arch Linux
sudo pacman -S kmscon

# Build from source
git clone https://github.com/dvdhrm/kmscon.git
cd kmscon
./autogen.sh
./configure --prefix=/usr
make
sudo make install
```

#### 4.2 Replace tty with kmscon (permanent)

To make kmscon the default system console instead of the legacy tty/getty, replace agetty with kmscon on the desired tty:

```bash
# Stop the existing getty on tty1
sudo systemctl stop getty@tty1.service
sudo systemctl disable getty@tty1.service

# Create a kmscon service for tty1
sudo mkdir -p /etc/systemd/system/getty.target.wants
sudo ln -s /usr/lib/systemd/system/kmsconvt@.service \
    /etc/systemd/system/getty.target.wants/kmsconvt@tty1.service

# Start kmscon on tty1
sudo systemctl start kmsconvt@tty1.service
```

After reboot, press `Ctrl+Alt+F1` to switch to the kmscon-enhanced tty1. You can repeat this for tty2–tty6 as needed.

To preserve the ability to run a text-based autologin (e.g. for a headless coding server):

```bash
# Override the kmscon service to enable autologin
sudo systemctl edit kmsconvt@tty1.service

# Add the following lines:
[Service]
ExecStart=
ExecStart=/usr/bin/kmscon "--vt=%I" --seats=seat0 --no-switchvt \
    --login -- /usr/bin/agetty --autologin your-username --noclear %I
```

Then `Ctrl+Alt+F1` will drop you directly into a kmscon session with vim-ready true color and Unicode.

#### 4.3 Run vim inside kmscon

Manually, for a one-off session:

```bash
# Start kmscon on a spare tty and run vim directly
sudo kmscon --login -- /usr/bin/vim

# Or switch to an existing kmscon session and launch vim
sudo kmscon --switch
```

#### 4.4 Color support

kmscon supports true color (24-bit). monkey-vim detects this automatically via `has('termguicolors')` and renders GUI colors directly.

If you fall back to a traditional Linux tty (tty1–tty63), monkey-vim degrades to 256-color mode with molokai's `rehash256` palette for accurate color approximation.

#### 4.5 Fonts

kmscon uses the system's built-in font renderer. For Powerline icons in the status line, ensure a Nerd Font is available:

```bash
# Download and install Hack Nerd Font system-wide
wget https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Hack.zip
sudo unzip -o Hack.zip -d /usr/share/fonts/truetype/hack
sudo fc-cache -fv
```

## Update project

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

## Plugin list

| Plugin | Purpose |
|---|---|
| [yegappan/lsp](https://github.com/yegappan/lsp) | Language Server Protocol client |
| [hrsh7th/vim-vsnip](https://github.com/hrsh7th/vim-vsnip) | Snippet engine |
| [Yggdroot/LeaderF](https://github.com/Yggdroot/LeaderF) | Fuzzy file/buffer/tag finder |
| [dyng/ctrlsf.vim](https://github.com/dyng/ctrlsf.vim) | Async code search (rg/ag backend) |
| [skywind3000/asyncrun.vim](https://github.com/skywind3000/asyncrun.vim) | Async command runner |
| [itchyny/lightline.vim](https://github.com/itchyny/lightline.vim) | Status line |
| [tomasr/molokai](https://github.com/tomasr/molokai) | Colorscheme |
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
| [dominikduda/vim_current_word](https://github.com/dominikduda/vim_current_word) | Highlight current word |
| [kshenoy/vim-signature](https://github.com/kshenoy/vim-signature) | Visual marks |
| [airblade/vim-rooter](https://github.com/airblade/vim-rooter) | Auto-change working directory |
| [romainl/vim-qf](https://github.com/romainl/vim-qf) | Quickfix/Location list helpers |

## Keyboard shortcut

```
The "Leader" key below means comma key.
```

### 1. Normal mode

#### 1.1 Remap

```
s       Replace a motion/text object with clipboard content (e.g. siw)
S       Replace from cursor to end of line with clipboard content
Y       Copy from the cursor position to the end of the line, same as y$
H       To the first non-blank character of the line, same as ^
L       To the last character of the line, same as $
U       Redo, same as Ctrl-r
;       Enter command line mode, same as :
q       Quit current window, same as :q
Q       Quit vim, same as :qa
t       Recording, same as the original q

j       Move down one display line (gj), works on wrapped lines
k       Move up one display line (gk), works on wrapped lines
f       Search 1 char to jump (stargate)
F       Search 2 consecutive chars to jump (stargate)
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

#### 1.9 File/Buffer/Tag navigation (LeaderF)

```
Ctrl+p      Search files
Ctrl+m      Search buffers
Ctrl+t      Search buffer tags
Ctrl+y      Search function in buffer
Ctrl+e      Search line in buffer
```

#### 1.10 Fold

These are standard Vim built-in keys enhanced by FastFold for performance:

```
za      When on a closed fold, open it. When on an open fold, close it and set 'foldenable'
zc      Close one fold under the cursor
zo      Open one fold under the cursor
zR      Open all folds
zM      Close all folds
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
F3      Async make
F4      Async run arbitrary command
```

#### 1.16 Others

```
Leader+bs       Save session
Leader+rs       Remove session

'.              Jump to last changes
''              To the position before the latest jump, or where the last "m'" or "m`" command was given
Ctrl+o          Go to [count] Older cursor position in jump list
Ctrl+i          Go to [count] newer cursor position in jump list
Ctrl+^          Edit the alternate file. Mostly the alternate file is the previously edited file
cod             Toggle diff
cop             Toggle paste
col             Toggle list
Leader+cr       Change project root
Leader+/        No highlight search
Leader+space        Strip trailing whitespace
Leader+Leader+space  Strip trailing whitespace + \\r (DOS newlines)
Leader+q            Toggle quickfix
Leader+l            Toggle location list
```

### 2. Insert mode

#### 2.1 Remap

```
t       Recording, same as the original q
```

#### 2.2 Snippets (vim-vsnip)

```
Ctrl+j      Expand snippet or jump to next placeholder
Ctrl+l      Expand snippet or jump forward
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
f       Search 1 character to jump to specific word
F       Search 2 consecutive characters to jump (reverse direction)
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
Ctrl+j  Next command
Ctrl+k  Previous command
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
```

## Use git in vim

### 1. git for vim: [vim-fugitive](https://github.com/tpope/vim-fugitive)

```vim
" Run an arbitrary git command. Similar to :!git [args] but chdir to the repository tree first.
" Recommended over :Gstatus, :Gcommit, :Gdiff, etc.
:Git [args]

" Common examples:
:Git status
:Git diff
:Git commit
:Git log
:Git blame
:Git pull
:Git push
:Git checkout %

" More help, please refer the video
https://github.com/tpope/vim-fugitive#screencasts

" or the official doc
:h fugitive.txt
```

### 2. Git commit browser: [gv.vim](https://github.com/junegunn/gv.vim)

```vim
" Open git commit browser
:GV
```

## Precautions

- monkey-vim defaults to 8-width tab indentation using hard tabs. If you prefer 4-width spaces, change:

```vim
set tabstop=8
set softtabstop=8
set shiftwidth=8
set noexpandtab
```

to

```vim
set tabstop=4
set softtabstop=4
set shiftwidth=4
set expandtab
```

## Recommended settings

- [Build vim from source](https://github.com/QMonkey/monkey-vim/wiki/Build-Vim-from-source)

- Use vim to view man doc in shell, put this in your bashrc:

```bash
export MANPAGER="env MAN_PN=1 vim -R +MANPAGER -"
```

## FAQ

- Vim clipboard integration

monkey-vim sets `clipboard=unnamed,unnamedplus` so vim's yank/delete automatically syncs to the system clipboard. Copied text persists in the system clipboard after vim exits (the system clipboard is owned by the display server / Wayland compositor / terminal, not by vim).

If you use a standalone clipboard manager (optional):

| Tool | Platform | Purpose |
|---|---|---|
| [parcellite](https://parcellite.sourceforge.net/) | X11 | Lightweight clipboard manager with persistent history |
| [cliphist](https://github.com/sentriz/cliphist) | Wayland | Clipboard history for wlroots-based compositors |
| Built-in | macOS/WSL | System clipboard persists by default — no extra tool needed |

- [FAQ](https://github.com/QMonkey/monkey-vim/wiki/FAQ)

## Configuration

If you have any problem or suggestion with monkey-vim, welcome to give me an [issue](https://github.com/QMonkey/monkey-vim/issues)
