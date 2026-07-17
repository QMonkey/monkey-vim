# monkey-vim

其他语言版本：[English](README.md)

## 简介

monkey-vim项目，旨在打造一个强大、快速的纯终端原生IDE。

**定位：** monkey-vim 面向纯终端环境 —— 不支持 GUI、gvim，不内建终端复用。适用环境：

| 环境 | 说明 |
|---|---|
| Linux 终端 | xterm, kitty, alacritty, wezterm, gnome-terminal 等 |
| macOS 终端 | Terminal.app, iTerm2, kitty 等 |
| WSL | Windows Subsystem for Linux（推荐 WSL2） |
| 服务器 TTY | 原生 Linux 控制台（tty1–tty63），256 色降级 |
| kmscon | Kernel Mode Setting 控制台 —— 支持真彩色和 Unicode 的现代 TTY 替代方案 |

窗口/分屏管理交给 tmux 或终端模拟器的原生标签页。

## 截图

![vim](pictures/xterm_vim.png "vim")

## 要求

- vim 9.0+
- 终端环境（不支持 GUI / gvim）

## 安装步骤

### 1. clone到本地

```bash
git clone https://github.com/QMonkey/monkey-vim.git
```

### 2. 安装依赖

#### 2.1 通用工具

| 工具 | 用途 | 是否必须 |
|---|---|---|
| curl | 插件管理器引导 | 是 |
| git | 插件管理器、vim-fugitive | 是 |
| [ripgrep (rg)](https://github.com/BurntSushi/ripgrep) | ctrlsf 代码搜索 + LeaderF Rg 后端 | 是 |
| universal-ctags | gutentags 标签生成 | 是 |
| cmake | 编译 LeaderF C 扩展 | 是（仅编译时） |

```bash
# Ubuntu/Debian
sudo apt-get install curl git ripgrep universal-ctags cmake

# Arch Linux
sudo pacman -S curl git ripgrep ctags cmake

# macOS
brew install curl git ripgrep universal-ctags cmake
```
#### 2.2 LSP 服务器

Language Server Protocol 支持由 [yegappan/lsp](https://github.com/yegappan/lsp) 插件提供。请根据需要安装对应语言的服务器：

| 语言 | LSP 服务器 | 安装方式 |
|---|---|---|
| C/C++ | clangd | `sudo apt-get install clangd` 或 `brew install llvm` |
| Go | gopls | `go install golang.org/x/tools/gopls@latest` |
| Python | python-lsp-server | `pip install python-lsp-server` |
| Rust | rust-analyzer | `rustup component add rust-analyzer` |
| Lua | lua-language-server | `sudo apt-get install lua-language-server` 或 `brew install lua-language-server` |
| Shell | bash-language-server | `npm install -g bash-language-server` |
| Vim | vim-language-server | `npm install -g vim-language-server` |
| JavaScript | typescript-language-server | `npm install -g typescript-language-server typescript` |
| TypeScript | typescript-language-server | `npm install -g typescript-language-server typescript` |
| JSON | vscode-json-language-server | `npm install -g vscode-langservers-extracted` |
| YAML | yaml-language-server | `npm install -g yaml-language-server` |
| Markdown | marksman | `sudo apt-get install marksman` 或 `brew install marksman` |

#### 2.3 C/C++

```bash
# Ubuntu
sudo apt-get install gcc g++ clangd clang-format

# macOS
brew install gcc llvm clang-format
```

#### 2.4 Go

```bash
# 请安装最新版本的 go，然后：
go install golang.org/x/tools/gopls@latest
```

#### 2.5 Python

```bash
pip install python-lsp-server
# 可选：代码格式化与检查工具
pip install autopep8 flake8 pylint
```

#### 2.6 JavaScript / TypeScript

```bash
# 安装 LSP 服务器
npm install -g typescript-language-server typescript
```

#### 2.7 Rust

```bash
# 通过 rustup 安装 rust-analyzer
rustup component add rust-analyzer
```

#### 2.8 YAML

```bash
# 安装 LSP 服务器
npm install -g yaml-language-server
```

#### 2.9 Markdown

终端/WSL 下预览 Markdown：
```bash
# 方案一：glow（终端 Markdown 渲染器）
# https://github.com/charmbracelet/glow
brew install glow  # 或：go install github.com/charmbracelet/glow@latest

# 方案二：在 Windows 浏览器中打开（仅 WSL）
# :!explorer.exe %
```

#### 2.10 字体（可选）

Vim 使用的 Unicode 字符（⎇, │, 🔒, ▸, ·, ¬）无需额外字体即可正常显示。如需 Powerline 风格外观，可选择性安装 [Nerd Font](https://github.com/ryanoasis/nerd-fonts)（如 Hack Nerd Font）。

- [Hack Nerd Font](https://github.com/ryanoasis/nerd-fonts/tree/master/patched-fonts/Hack)

### 3. 健康检查

验证所有必需依赖和可选 LSP server 是否就绪：

```bash
./checkhealth.sh
```

加 `--install` 可自动安装缺失的必需依赖（支持 apt/pacman/brew）：

```bash
./checkhealth.sh --install
```

### 4. 安装

- Linux、Mac、WSL 和 kmscon

```bash
cd monkey-vim
ln -s $(pwd)/.vimrc ~/.vimrc
vim
```

### 5. 更新

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

### 6. kmscon 安装与使用（可选）

[kmscon](https://github.com/kmscon/kmscon) 是基于 Linux KMS/DRM 的系统级终端，替代传统的 Linux tty，提供完整的 Unicode 支持、multi-seat 能力和真彩色渲染。它是 monkey-vim 在无头服务器上的绝佳搭档。

#### 6.1 安装 kmscon

```bash
# Ubuntu/Debian（旧版，不含 terminfo）
sudo apt-get install kmscon

# Arch Linux
sudo pacman -S kmscon

# 从源码编译（需要 meson、ninja 和 ncurses 提供的 tic）
git clone https://github.com/kmscon/kmscon.git
cd kmscon
meson setup builddir/
meson install -C builddir/
```

从源码编译时会自动通过 `tic` 编译并安装 kmscon 的 terminfo 条目，vim 无需任何 `TERM` 变通即可正确检测终端能力。默认安装 prefix 为 `/usr/local`，如需安装到系统路径请在 meson setup 时追加 `--prefix=/usr`。

在较旧的系统上，`libtsm` 等依赖版本可能不满足编译要求。此时使用包管理器版本并通过 6.3 节的 `TERM` 变通方案即可。

#### 6.2 用 kmscon 替代 tty（永久生效）

让 kmscon 取代传统的 tty/getty 成为默认系统控制台：

```bash
# 停止 tty1 上原有的 getty
sudo systemctl stop getty@tty1.service
sudo systemctl disable getty@tty1.service

# 为 tty1 创建 kmscon systemd 服务
sudo mkdir -p /etc/systemd/system/getty.target.wants
sudo ln -s /usr/lib/systemd/system/kmsconvt@.service \
    /etc/systemd/system/getty.target.wants/kmsconvt@tty1.service

# 覆写 ExecStart 使用 kmscon 自带的终端类型
sudo systemctl edit kmsconvt@tty1.service
```

添加以下覆写内容：

```ini
[Service]
ExecStart=
ExecStart=/usr/bin/kmscon "--vt=%I" --seats=seat0 --no-switchvt \
    --login -- /sbin/agetty -o '-p -- \\u' - --noclear %I kmscon
```

最后的 `kmscon` 参数告诉 agetty 设置 `TERM=kmscon`，与编译时安装的 terminfo 条目匹配。

```bash
# 在 tty1 上启动 kmscon
sudo systemctl start kmsconvt@tty1.service
```

重启后，按 `Ctrl+Alt+F1` 即可切换到支持真彩色和 Unicode 的 kmscon 终端。可按需对 tty2–tty6 重复相同操作。

#### 6.3 真彩色支持

kmscon 支持真彩色（24-bit）。monkey-vim 通过 `has('termguicolors')` 自动检测并使用 GUI 颜色渲染。

如果通过包管理器安装的 kmscon 版本较旧（不含 terminfo）或 terminfo 条目缺失，vim 会报错 `E558: Terminal entry not found in terminfo`。此时在 shell 配置中添加以下内容即可：

```bash
# 添加到 shell 配置文件中（~/.bashrc、~/.zshrc 等）
export TERM=xterm-256color
export COLORTERM=truecolor
```

`COLORTERM=truecolor` 必须在 `TERM=xterm-256color` 时设置，否则 vim 无法检测到真彩色支持。注意使用 `xterm-256color` 替代 kmscon 原生 terminfo 可能导致一定的终端刷新异常。如需最佳体验，请从源码编译获取原生 terminfo 条目。

如果在传统 Linux tty（tty1–tty63）上运行，monkey-vim 将自动降级到 256 色模式，并使用 sonokai 的深色调色板以准确逼近主题颜色。

#### 6.4 字体（可选）

kmscon 使用系统内建的字体渲染器。如需 Powerline 风格图标，可选择性安装 Nerd Font：

```bash
# 下载并安装 Hack Nerd Font 到系统目录（可选）
wget https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Hack.zip
sudo unzip -o Hack.zip -d /usr/share/fonts/truetype/hack
sudo fc-cache -fv
```

## 插件列表

| 插件 | 用途 |
|---|---|
| [yegappan/lsp](https://github.com/yegappan/lsp) | Language Server Protocol 客户端 |
| [hrsh7th/vim-vsnip](https://github.com/hrsh7th/vim-vsnip) | 代码片段引擎 |
| [hrsh7th/vim-vsnip-integ](https://github.com/hrsh7th/vim-vsnip-integ) | LSP 片段集成 |
| [rafamadriz/friendly-snippets](https://github.com/rafamadriz/friendly-snippets) | 常用代码片段集合 |
| [Yggdroot/LeaderF](https://github.com/Yggdroot/LeaderF) | 模糊文件/缓冲/tag 查找 |
| [dyng/ctrlsf.vim](https://github.com/dyng/ctrlsf.vim) | 异步代码搜索（rg/ag 后端） |
| [skywind3000/asyncrun.vim](https://github.com/skywind3000/asyncrun.vim) | 异步命令执行 |
| [itchyny/lightline.vim](https://github.com/itchyny/lightline.vim) | 状态栏 |
| [sainnhe/sonokai](https://github.com/sainnhe/sonokai) | 配色方案 |
| [mg979/vim-visual-multi](https://github.com/mg979/vim-visual-multi) | 多光标编辑 |
| [monkoose/vim9-stargate](https://github.com/monkoose/vim9-stargate) | 快速跳转（替代 vim-sneak） |
| [tpope/vim-fugitive](https://github.com/tpope/vim-fugitive) | Git 集成 |
| [airblade/vim-gitgutter](https://github.com/airblade/vim-gitgutter) | Git 差异标记 |
| [ludovicchabant/vim-gutentags](https://github.com/ludovicchabant/vim-gutentags) | 自动生成 ctags |
| [justinmk/vim-dirvish](https://github.com/justinmk/vim-dirvish) | 目录浏览器（替代 netrw） |
| [tpope/vim-surround](https://github.com/tpope/vim-surround) | 围绕字符编辑 |
| [svermeulen/vim-subversive](https://github.com/svermeulen/vim-subversive) | 使用剪贴板替换 |
| [andymass/vim-matchup](https://github.com/andymass/vim-matchup) | 增强 % 匹配跳转 |
| [wellle/targets.vim](https://github.com/wellle/targets.vim) | 更多文本对象 |
| [michaeljsmith/vim-indent-object](https://github.com/michaeljsmith/vim-indent-object) | 基于缩进的文本对象 |
| [cohama/lexima.vim](https://github.com/cohama/lexima.vim) | 自动配对括号 |
| [tpope/vim-repeat](https://github.com/tpope/vim-repeat) | 使插件映射支持 `.` 重复 |
| [tpope/vim-eunuch](https://github.com/tpope/vim-eunuch) | UNIX Shell 辅助命令（:W sudo保存等） |
| [tpope/vim-obsession](https://github.com/tpope/vim-obsession) | Session 管理 |
| [Konfekt/FastFold](https://github.com/Konfekt/FastFold) | 大文件折叠性能优化 |
| [haya14busa/vim-asterisk](https://github.com/haya14busa/vim-asterisk) | 增强 `*` / `#` 搜索 |
| [kshenoy/vim-signature](https://github.com/kshenoy/vim-signature) | 可视化书签 |
| [airblade/vim-rooter](https://github.com/airblade/vim-rooter) | 自动切换工作目录 |
| [junegunn/gv.vim](https://github.com/junegunn/gv.vim) | Git 提交浏览器 |
| [romainl/vim-qf](https://github.com/romainl/vim-qf) | Quickfix/Location list 增强 |

## 快捷键

```
以下所有"Leader"键，都代表","键
```

### 1. 正常模式

#### 1.1 按键修改

```
s       用剪贴板的内容替换文本对象选中的字符串（详见§1.7）
S       用剪贴板的内容替换当前光标到行尾的文本（详见§1.7）
Y       复制到行尾，相当于"y$"命令
H       跳到当前行第一个非空字符,相当于"^"命令
L       跳到当前行最后一个字符,相当于"$"命令
U       Redo，相当于"Ctrl-r"
;       进入命令行模式，相当于":"键
q       退出窗口（含 diff/fugitive/quickfix 特殊处理）
Shift+q  退出vim，相当于命令":qa"
t       记录操作，相当于原来的q（普通模式和可视化模式）

j       移至下一显示行（gj），在折行中正常移动
k       移至上一显示行（gk），在折行中正常移动
f       搜索 1 个字符跳转（stargate 带提示）
F       搜索 2 个连续字符跳转（stargate 带提示）
gs      选择单词/区域进行多光标编辑（vim-visual-multi）
```

以下按键在插入模式和命令行模式下均适用：

```
Ctrl+p  上移        (Up)
Ctrl+n  下移        (Down)
Ctrl+b  左移        (Left)
Ctrl+f  右移        (Right)
Ctrl+a  跳到行首    (Home)
Ctrl+e  跳到行尾    (End)
Ctrl+h  退格        (BackSpace)
Ctrl+d  向前删除    (Del)
```

#### 1.2 F1 ~ F4

```
F1      打开 CtrlSF 搜索提示
F2      切换 CtrlSF 搜索窗口
F3      异步 Make
F4      异步执行任意命令
```

#### 1.3 缓冲

```
Leader+o    输入打开文件的路径，并在当前窗口打开一个缓冲
[+b         切换到上一个缓冲
]+b         切换到下一个缓冲
```

#### 1.4 分屏

```
Leader+s    输入打开文件的路径，并创建一个水平分屏的窗口
Leader+v    输入打开文件的路径，并创建一个垂直分屏的窗口

Ctrl+h      跳转到左窗口
Ctrl+j      跳转到下窗口
Ctrl+k      跳转到上窗口
Ctrl+l      跳转到右窗口
Leader+z    窗口放大/恢复
```

#### 1.5 Tab

```
Leader+t      输入打开的文件路径，并创建一个新tab窗口

[+t         切换到上一个tab窗口
]+t         切换到下一个tab窗口
Leader+1~9  切换到第1~9个tab窗口
Leader+[    切换到第一个tab窗口
Leader+]    切换到最后一个tab窗口
```

#### 1.6 查找（vim-asterisk）

按 `*` 或 `#` 会高亮光标下的所有单词但不跳转。再次按下则正常跳转。

```
*       高亮当前词，不跳转（再按跳转）
g*      同上，部分匹配
#       同上，反向
g#      同上，反向部分匹配
```

#### 1.7 替换（vim-subversive）

```
s{文本对象}  用剪贴板内容替换一个文本对象（如 siw 替换当前词）
ss          用剪贴板内容替换当前整行
S           用剪贴板内容替换从光标到行尾
```

#### 1.8 LSP（Language Server Protocol）

```
K                   查看光标所在符号的文档说明
gh                  在弹出窗口中显示文档

gd                  跳转到定义
gc                  跳转到声明
gt                  跳转到类型定义
gi                  跳转到实现
gr                  查看引用

Leader+gd           预览定义
Leader+gc           预览声明
Leader+gt           预览类型定义
Leader+gi           预览实现
Leader+gr           预览引用

Leader+rn           重命名符号
[d                  上一个诊断
]d                  下一个诊断
[D                  第一个诊断
]D                  最后一个诊断
Leader+gh           显示当前行诊断
```

文件在保存时自动通过 LSP 格式化。自动补全默认开启 — LSP 建议会自动弹出。  
`K` 使用 `:LspHover` 作为大多数文件类型的关键字程序。

#### 1.9 文件/缓冲/Tag 导航（LeaderF）

```
Ctrl+p      搜索文件

Leader+b    搜索缓冲
Leader+y    搜索当前文件Tag
Leader+f    搜索当前文件函数
Leader+e    搜索当前文件行
```

#### 1.10 Fold

以下是 Vim 内建折叠按键，由 FastFold 插件优化大文件性能：

```
za      当光标下的折叠打开时，关闭它。当折叠关闭时，打开它
zc      关闭光标下的折叠
zo      打开光标下的折叠
zR      打开所有折叠
zM      关闭所有折叠
zuz     手动更新所有折叠（FastFold）
```

#### 1.11 Marks（vim-signature）

```
m[a-zA-Z]   添加/删除标记
m,          添加下一个可用的标记
m.          如果当前行没有标记，添加下一个可用标记。否则，删除第一个标记

dm[a-zA-Z]  删除标记[a-zA-Z]
m-          删除当前行的所有标记
m<Space>    删除当前buffer的所有标记

'[a-zA-Z]   跳转到标记[a-zA-Z]
]`          跳转到下一个标记
[`          跳转到上一个标记
`]          根据字母序列跳转到下一个标记
`[          根据字母序列跳转到上一个标记
m/          在Location List里，查看当前buffer的所有标记

m[0-9]      添加/删除自定义标记!@#$%^&*()

m<S-[0-9]>  删除相应的自定义标记
m<BS>       删除所有自定义标记

]-          跳转到下一个相同类型的自定义标记
[-          跳转到上一个相同类型的自定义标记
]=          跳转到下一个自定义标记
[=          跳转到上一个自定义标记
m?          在Location List里，查看当前buffer的所有自定义标记
```

`:SignatureToggle`   显示/隐藏标记（不删除）  
`:SignatureRefresh`  标记与 sign 不同步时重新同步

#### 1.12 Dirvish（目录浏览器，替代netrw）

```
-           在当前窗口打开文件所在的文件夹
~           在当前窗口打开项目根路径或用户主目录

<CR>        进入目录或打开文件
o           在当前窗口打开
a           在水平分屏打开
i           在垂直分屏打开
t           在新标签页打开
-           返回上一级目录
A/I/O       已禁用（请使用 a/i/o 代替）
x           将文件添加到 arglist
R           刷新目录视图
:Shdo       根据行内容生成 shell 脚本（如 :%Shdo）
```

#### 1.13 代码搜索（ctrlsf）

```
Leader+a        当前目录搜索光标所在的词
```

#### 1.14 围绕字符编辑（vim-surround）

```
ys+textobj+surroundA        在textobj指定的范围增A围绕字符
yss+surroundA               在当前行增加A围绕字符
ds+surroundA                删除A围绕字符
cs+surroundA+surroundB      将A围绕字符改成B围绕字符
```

#### 1.15 异步运行

```
F3      异步 Make（使用 asyncrun 替代阻塞的内置 :make）
F4      异步运行任意命令
```

`:Make` 命令异步执行 `make`，不会阻塞 Vim。完成后快速修复窗口自动打开。

#### 1.16 其他

```
Leader+ws       保存session
Leader+rs       删除session
```

Session 保存到 `~/.cache/sessions/`。Vim 启动时自动从此目录恢复 session。

```
'.              最后一次变更的地方
''              跳回来的地方（最近两个位置跳转）
Ctrl+o          跳回，可用于多种类型跳转（符号跳转，定义跳转，屏幕跳转等）
Ctrl+i          继续上次跳转（与Ctrl+o操作相反），可用于多种类型跳转（符号跳转，定义跳转，屏幕跳转等）
Ctrl+^          打开上次编辑的文件
cod             切换diff模式
cop             切换paste模式
col             切换list模式
con             清除搜索高亮
Leader+cr       切换到当前文件所在项目根路径（手动触发，不会自动切换）
cop             切换粘贴模式（退出插入模式时自动关闭）
Leader+space        去除行尾空白字符（:substitute）
Leader+Leader+space  去除行尾空白字符 + \\r（DOS 换行符）
Leader+q            打开/关闭quickfix
Leader+l            打开/关闭location list
```

在 quickfix/location 窗口中（ack 风格映射）：
- `o`/`Enter` — 打开条目（文件+行号）
- `go` — 在水平分屏中打开
- `gO` — 打开并聚焦新窗口
- `t` — 在新标签页中打开
- `T` — 在新标签页中打开（保持 quickfix 聚焦）
- `q` — 关闭 quickfix 窗口

Quickfix 窗口自动调整大小（最多 10 行），为空时自动关闭，始终置于底部。

注意：`gdefault` 已设置，`:s` 默认执行全局替换（每行所有匹配）。  
每次启动 Vim 时会清除跳转列表（`clearjumps`），避免跨项目污染。`jumpoptions+=stack` 使跳转列表行为类似标签栈。

#### 1.17 自动插入文件头

新建 `.sh` 和 `.py` 文件会自动插入 shebang 行：
- `.sh` → `#!/usr/bin/env bash`
- `.py` → `#!/usr/bin/env python3`

#### 1.18 Match-up（增强 % 匹配跳转）

```
%       正向跳转到下一个匹配词（闭合处循环回到开头）
g%      反向跳转到上一个匹配词
[%      跳转到上一个外部左括号
]%      跳转到下一个外部右括号
z%      进入最近的内层块
i%      任意块的内部（文本对象）
a%      任意块的范围（文本对象）
```

#### 1.19 Lexima（自动配对括号）

Lexima 自动配对：`()`、`[]`、`{}`、`""`、`''`、` `` `` `。在空括号内按退格会同时删除两个字符。在 `{}` 中按回车会自动缩进并生成闭括号。在 vim 文件中 `"` 不自动配对（因为 `"` 是注释引导符）。

### 2. 插入模式

#### 2.1 代码片段（vim-vsnip）

```
Ctrl+l      展开代码片段
Tab         跳转到下一个占位符
Shift+Tab   跳转到上一个占位符
```

### 3. 可视化模式

#### 3.1 按键修改

```
s       用剪贴板的内容替换选中文本
;       进入命令行模式，相当于":"键
<       减少缩进，保持选中
>       增加缩进，保持选中
```

#### 3.2 查找

```
*       正向查找选中的字符串（标准 vim 行为，由 vim-asterisk 增强）
#       逆向查找选中的字符串（标准 vim 行为，由 vim-asterisk 增强）
```

#### 3.3 替换

```
# '\r'代表换行

s{文本对象}  用剪贴板内容替换文本对象（如 siw）
ss          用剪贴板内容替换当前整行
S           用剪贴板内容替换光标到行尾
```

#### 3.4 快速跳转（vim9-stargate）

```
f           搜索1个字符并跳转
F           搜索2个连续字符并跳转（stargate 带提示）
```

#### 3.5 代码搜索（ctrlsf）

```
Leader+a        当前目录搜索选中字符串
```

#### 3.6 围绕字符编辑（vim-surround）

```
S+surroundA     选中字符串增加A围绕字符
```

### 4. 命令行模式

```
Ctrl+p  上一条命令
Ctrl+n  下一条命令
Ctrl+a  跳到命令行最前
Ctrl+e  跳到命令行最后
```

## 常用命令

### 1. W（vim-eunuch）

```vim
" 使用root权限保存文件
:W
```

### 2. CtrlSF

```vim
" 递归搜索当前目录中包含 PATTERN 的代码
:CtrlSF[!] [PATTERN]
```

### 3. GutentagsUpdate

```vim
" 为当前文件生成tag
:GutentagsUpdate

" 为整个工程生成tag
:GutentagsUpdate!
```

### 4. LeaderF

```vim
" 搜索文件
:LeaderfFile [QUERY]

" 搜索缓冲区
:LeaderfBuffer [QUERY]

" 搜索项目 tags
:LeaderfTag [QUERY]

" 搜索当前文件 tags
:LeaderfBufTag [QUERY]

" 搜索函数
:LeaderfFunction [QUERY]

" 搜索 Marks
:LeaderfMarks [QUERY]

" 搜索行
:LeaderfLine [QUERY]

" 搜索最近使用的文件
:LeaderfMru [QUERY]

" 交互式 ripgrep 搜索
:LeaderfRgInteractive [QUERY]

" 搜索命令历史
:LeaderfHistoryCmd

" 搜索 help 标签
:LeaderfHelp [QUERY]
```

## 在vim中使用git

### 1. git for vim: [vim-fugitive](https://github.com/tpope/vim-fugitive)

#### 核心命令

```vim
" 相当于:!git [args]，但会先自动切换到仓库根目录。推荐使用 :Git 而非 :Gstatus, :Gcommit, :Gdiff 等
:Git [args]

" :Git 的缩写
:G [args]
```

#### 常用示例

```vim
:Git status
:Git diff
:Git commit
:Git log
:Git blame
:Git pull
:Git push
```

#### 暂存 / 写 / 追溯

```vim
" 暂存当前文件 (git add)
:Gwrite
" 暂存并退出
:Gwq

" 从 git 和 buffer 中删除文件
:GDelete
" 从 git 中删除，保留 buffer
:GRemove
" 重命名 / 移动文件
:GMove {dest}

" 在滚动同步的分屏中查看 blame
:Git blame
```

#### 差异对比

```vim
" 与暂存区对比
:Gdiffsplit
" 与 HEAD 对比
:Gdiffsplit HEAD
" 始终垂直分屏
:Gvdiffsplit
```

#### 日志与搜索

```vim
" git-log 放入 quickfix
:Gclog
" git-log 放入 location list
:Gllog
" git-grep 放入 quickfix
:Ggrep [args]

" 在 GitHub 浏览器中打开当前文件/提交
:GBrowse
" 复制 URL 到剪贴板
:GBrowse!
```

#### Git status 窗口快捷键

在 `:Git` 打开的 status 窗口内：
- `s` — 暂存文件
- `u` — 取消暂存
- `-` — 切换暂存
- `X` — 丢弃修改
- `=` — 切换内联差异
- `cc` — 提交
- `ca` — 修改上次提交
- `cf` — fixup 提交
- `cs` — squash 提交
- `crc` — 还原提交
- `coo` — 检出文件
- `dd` — `:Gdiffsplit`
- `dv` — `:Gvdiffsplit`
- `gq` — 关闭 status 窗口

更多帮助：`:h fugitive.txt` 或 https://github.com/tpope/vim-fugitive#screencasts

### 2. Git 提交浏览器：[gv.vim](https://github.com/junegunn/gv.vim)

```vim
" 打开 Git 提交浏览器
:GV
" 只列出当前文件的提交
:GV!
" 将当前文件的版本历史放入 location list
:GV?
```

### 3. Git 差异标记：[vim-gitgutter](https://github.com/airblade/vim-gitgutter)

```vim
" 跳转到下一个/上一个修改块
]c / [c

" 预览 / 暂存 / 撤销当前修改块
:GitGutterPreviewHunk
:GitGutterStageHunk
:GitGutterUndoHunk

" 折叠所有未修改行
:GitGutterFold

" 将所有修改块加载到 quickfix
:GitGutterQuickFix
```

## 常用 Vim 命令

### 1. vim-eunuch（UNIX Shell 辅助）

```vim
" 写入所有窗口中修改过的 buffer
:W (:wall)

" 使用 root 权限保存文件
:SudoWrite

" 使用 root 权限编辑文件
:SudoEdit {file}

" 从磁盘和 buffer 中删除文件
:Delete
" 从磁盘中删除文件，保留 buffer
:Remove

" 重命名 / 移动文件
:Rename {dest}

" 复制文件
:Copy {dest}

" 修改文件权限
:Chmod {mode}

" 创建目录（含父目录）
:Mkdir {dir}
" 单独 :Mkdir 创建当前文件所在的目录

" 查找文件（结果放入 quickfix）
:Cfind {args}
```

### 2. asyncrun.vim

```vim
" 异步运行命令（不阻塞 Vim）
:AsyncRun {cmd}

" 常用选项：
" -program=make    — 设置程序名称，影响输出格式
" -cwd=<root>      — 在项目根目录运行
" -save=2          — 自动保存所有修改过的文件
" -silent          — 不弹出 quickfix 窗口
" -mode=term       — 在终端窗口中运行

" 停止正在运行的任务
:AsyncStop

" Make 命令（monkey-vim 自定义）
:Make [args]
```

### 3. CtrlSF

```vim
" 递归搜索当前目录中包含 PATTERN 的代码
:CtrlSF[!] [PATTERN] [path]

" 重新打开 CtrlSF 窗口
:CtrlSFOpen

" 关闭 CtrlSF 窗口
:CtrlSFClose
```

### 4. Gutentags

```vim
" 为当前文件生成tag
:GutentagsUpdate

" 为整个工程生成tag
:GutentagsUpdate!
```

### 5. vim-qf（Quickfix 增强）

```vim
" 只保留匹配的条目
:Keep {pattern}

" 删除匹配的条目
:Reject {pattern}

" 按名称保存当前列表
:SaveList {name}

" 加载已命名的列表
:LoadList {name}

" 对列表中的每个文件执行命令
:Dofile {cmd}

" 对列表中的每一行执行命令
:Doline {cmd}
```

### 6. vim-obsession（Session 管理）

```vim
" 开始/更新 session（保存到 ~/.cache/sessions/）
:Obsession {file}

" 暂停/恢复 session 追踪
:Obsession

" 停止并删除 session 文件
:Obsession!
```

### 7. LSP 命令（yegappan/lsp）

```vim
" 在整个工作区搜索符号
:LspSymbolSearch [查询]

" 显示当前文件大纲
:LspOutline

" 在弹窗中显示文件符号
:LspDocumentSymbol

" 在源码和头文件之间切换
:LspSwitchSourceHeader

" 显示所有 server 状态
:LspShowAllServers

" 工作区管理
:LspWorkspaceAddFolder {folder}
:LspWorkspaceRemoveFolder {folder}
:LspWorkspaceListFolders
```

## 注意事项

- monkey-vim默认tab的缩进为8个字符，不使用space替代tab。如果你喜欢tab缩进为4个字符，并且使用space替代tab。你可以将以下vim配置

```vim
set tabstop=8
set softtabstop=8
set shiftwidth=8
set noexpandtab
```

改为

```vim
set tabstop=4
set softtabstop=4
set shiftwidth=4
set expandtab
```

- Vim 剪贴板集成

monkey-vim 设置了 `clipboard=unnamed,unnamedplus`，vim 的复制/删除操作会自动同步到系统剪贴板。退出 vim 后，复制的内容仍然保留在系统剪贴板中（系统剪贴板由显示服务器/Wayland 合成器/终端管理，不受 vim 退出影响）。

如需独立的剪贴板管理工具（可选）：

| 工具 | 平台 | 用途 |
|---|---|---|
| [parcellite](https://parcellite.sourceforge.net/) | X11 | 轻量级剪贴板管理器，支持持久化历史 |
| [cliphist](https://github.com/sentriz/cliphist) | Wayland | wlroots 剪贴板历史管理 |
| 系统自带 | macOS/WSL | 系统剪贴板默认持久化，无需额外工具 |

## 推荐设置

- [源码构建vim](https://github.com/QMonkey/monkey-vim/wiki/Build-Vim-from-source)

- 在bashrc中加入以下Shell代码，即可在vim中查看man文档

```bash
export MANPAGER="env MAN_PN=1 vim -R +MANPAGER -"
```
