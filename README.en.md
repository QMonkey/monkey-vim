# monkey-vim

* **xterm vim**

![xterm vim](https://raw.githubusercontent.com/QMonkey/monkey-vim/master/pictures/xterm_vim.png "xterm vim")

* **gvim**

![gvim](https://raw.githubusercontent.com/QMonkey/monkey-vim/master/pictures/gvim.png "gvim")

## Introduction

Maybe you feel like your IDE is not powerful or convenient. Therefore, you may install lots of plugins. After that, you may find your IDE is too slow! That is unbearable! Finally, you have to choose between powerful and lightweight. Perhaps you can also install an IDE for a specific programming language.

The project monkey-vim, aims to make a convenient, powerful but still lightweight and fast IDE.

## How to install

### 1. Git clone

```bash
git clone https://github.com/QMonkey/monkey-vim.git
```

### 2. Install dependences

#### 2.1 Dependent tools

```bash
# Ubuntu
sudo apt-get install ctags
sudo apt-get install silversearcher-ag or sudo apt-get install ack-grep

# OpenSUSE
sudo zypper install ctags
sudo zypper install the_silver_searcher or sudo zypper install ack

# CentOS
sudo yum install ctags
sudo yum install the_silver_searcher or sudo yum install ack
```

#### 2.2 Fonts

* [powerline-font](https://github.com/powerline/fonts)
* [nerd-font](https://github.com/ryanoasis/nerd-fonts)

#### 2.3 Docset

* [Dash](https://kapeli.com/dash/)
* [Zeal](https://zealdocs.org/)

#### 2.4 C/C++

```bash
# Ubuntu
sudo apt-get install gcc
sudo apt-get install g++
# "x" depends on your clang version
sudo apt-get install clang-3.x

# OpenSUSE
sudo zypper install gcc
sudo zypper install gcc-c++
sudo zypper install llvm-clang

# CentOS
sudo yum install gcc
sudo yum install gcc-c++
sudo yum install clang
```

#### 2.5 Javascript

```bash
sudo npm install -g jslint
sudo npm install -g js-beautify
sudo npm install -g tern
```

#### 2.6 JSON

```bash
sudo npm install -g jsonlint
```

#### 2.7 HTML

```bash
sudo npm install -g jshint
```

#### 2.8 CSS

```bash
sudo npm install -g csslint
```

#### 2.9 Python

```bash
sudo pip install pyflakes
sudo pip install autopep8
sudo pip install pep8
sudo pip install jedi
```

#### 2.10 Golang

```bash
# Ubuntu
sudo apt-get install golang

# OpenSUSE
sudo zypper install go

# CentOS
sudo zypper install golang

# Other golang dependences
# Execute vim command below after successfully install monkey-vim
:GoInstallBinaries
```

#### 2.11 Java

```bash
# Ubuntu
sudo apt-get install astyle
sudo apt-get install openjdk-8-jdk

# OpenSUSE
sudo zypper install astyle
sudo zypper install java-1_8_0-openjdk-devel

# CentOS
sudo yum install astyle
sudo yum install java-1.8.0-openjdk-devel.x86_64
```

#### 2.12 PHP

```bash
pear install doc.php.net/pman
```

#### 2.13 Shell

```bash
# Ubuntu
sudo apt-get install devscripts

# OpenSUSE
sudo zypper install checkbashisms

# CentOS
sudo yum install rpmdevtools
```

#### 2.14 Markdown

```bash
sudo npm install -g instant-markdown-d
sudo gem install mdl
```

### 3. Install monkey-vim

```bash
cd monkey-vim
cp .vimrc ~/.vimrc
vim
```

## Keyboard shortcut

```
The "Leader" key below means backslash key.
```

### 1. Normal mode

#### 1.1 Remap

```
Y       Delete from the cursor position to the end of the line, same as y$
U       Redo, same as Ctrl-r
;       Enter command line mode, same as :
q       Quit current window, same as :q
Ctrl+c  Switch to normal mode, same as <ESC>
```

#### 1.2 F2 ~ F10

```
F2      Toggle NERDTree
F3      Toggle Tagbar
F4      Toggle Gundo
F5      Toggle paste mode
F7      Run current project asynchronously. You can use ":FocusDispatch" command to override the default command. For example, :FocusDispatch gcc % -o a.out
F8      Toggle output window of F7
F9      Markdown preview in browser
F10     Toggle RainbowParentheses
F11     Toggle fullscreen, only available in GUI mode
```

#### 1.3 Split

```
Leader+s    Open a horizontal split with given file path in current window
Leader+v    Open a vertical split with given file path in current window

Ctrl+h      Jump to the left split
Ctrl+j      Jump to the below split
Ctrl+k      Jump to the above split
Ctrl+l      Jump to the right split

Ctrl+up     Stretch the window vertically
Ctrl+down   Shrink the window vertically
Ctrl+left   Stretch the window horizontally
Ctrl+right  Shrink the window horizontally
Leader+z    Toggle zoom

Leader+ww   Swap two splits. You need to execute the command in that splits
```

#### 1.4 Tab

```
Ctrl+t      Open a tab with given file path in current window

H           Jump to previous tab
L           Jump to next tab
Leader+1~9  Jump to the 1~9 tab
Leader+[    Jump to first tab
Leader+]    Jump to last tab
```

#### 1.5 Replace

```
Leader+R    Replace current word. Not whole word, and don't need to confirm
Leader+rw   Replace current word. Whole word, but don't need to confirm
Leader+rc   Replace current word. Not whole word, but need to confirm
Leader+rwc  Replace current word. Whole word and need to confirm
```

#### 1.6 Programming language

```
K                   Refer current word in doc
Leader+Leader+z     Refer doc in dash or zeal

gd      GoDef
gi      GoImports
gt      GoTest, execute go test for current go source
gf      GoTestFunc, execute go test for current go test function
```

#### 1.7 Ctags

```
Ctrl+]  Jump to the definition of the keyword under the cursor
g]      Like "Ctrl+]", but need to choose one tag to jump
```

#### 1.8 Marks

```
m[a-zA-Z]   Mark current row
dm[a-zA-Z]  Delete mark[a-zA-Z]

'[a-zA-Z]   Jump to the mark

m/          View all marks in Location List
m-          Delete all marks in current line
m<space>    Delete all marks in current buffer
```

#### 1.9 Pairs of handy bracket mappings: [vim-unimpaired](https://github.com/tpope/vim-unimpaired)

```
[b                  Jump to previous buffer
]b                  Jump to next buffer
[B                  Jump to first buffer
]B                  Jump to last buffer

[t                  Jump to previous tab
]t                  Jump to next tab
[T                  Jump to first tab
]T                  Jump to last tab

[n                  Go to the previous SCM conflict marker or diff/patch hunk
]n                  Go to the next SCM conflict marker or diff/patch hunk

[<Space>            Add [count] blank lines above the cursor
]<Space>            Add [count] blank lines below the cursor

cob                 Toggle 'background' (dark/light)
coc                 Toggle 'cursorline'
cod                 Toggle 'diff' (:diffthis/:diffoff)
coh                 Toggle 'hlsearch'
coi                 Toggle 'ignorecase'
col                 Toggle 'list'
con                 Toggle 'number'
cor                 Toggle 'relativenumber'
cos                 Toggle 'spell'
cou                 Toggle 'cursorcolumn'
cov                 Toggle 'virtualedit'
cow                 Toggle 'wrap'
cox                 Toggle 'cursorline' or 'cursorcolumn'

[x{motion}          XML encode
[xx                 XML encode for current line
]x{motion}          HTML/XML decode
]xx                 HTML/XML decode for current line

[u{motion}          URL encode
[uu                 URL encode for current line
]u{motion}          URL decode
]uu                 URL decode for current line

[y{motion}          C String encode
[yy                 C String encode for current line
]y{motion}          C String decode
]yy                 C String decode for current line
```

#### 1.10 Code-completion engine: [YouCompleteMe](https://github.com/Valloric/YouCompleteMe)

```
gd          Go to definition
Leader+jd   Go to declaration
Leader+ji   Go to header file
```

#### 1.11 Syntax checking plugin: [Syntastic](https://github.com/scrooloose/syntastic)

```
Leader+e    Toggle error window
```

#### 1.12 Motions on speed: [EasyMotion](https://github.com/easymotion/vim-easymotion)

```
Leader+Leader+j     跳转到当前屏幕，光标后任何指定行
Leader+Leader+k     跳转到当前屏幕，光标前任何指定行
Leader+Leader+w     跳转到当前屏幕，光标后任何指定单词
Leader+Leader+b     跳转到当前屏幕，光标前任何指定单词
Leader+Leader+s     搜索字符，并跳转到当前屏幕指定字符
```

#### 1.13 buffer、tab切换，保存/恢复workspace插件：[Vim-CtrlSpace](https://github.com/vim-ctrlspace/vim-ctrlspace)

```
Ctrl+Space  打开CtrlSpace

Leader+ss   保存workspace
Leader+rs   恢复workspace
```

#### 1.14 项目文件搜索插件：[CtrlP](https://github.com/ctrlpvim/ctrlp.vim)

```
Ctrl+p      打开CtrlP
```

#### 1.15 多光标操作插件：[vim-multiple-cursors](https://github.com/terryma/vim-multiple-cursors)

```
Ctrl+n      选中一个字符串（若未进入多光标模式，则进入）
Ctrl+p      放弃当前选中字符串，回到上次选中的地方（多光标模式下有效）
Ctrl+x      跳过当前选中字符串，选中下一个（多光标模式下有效）
<ESC>       退出多光标模式
```

#### 1.16 区域选中插件：[vim-expand-region](https://github.com/terryma/vim-expand-region)

```
+       扩大选中区域，并进入可视化模式
```

#### 1.17 注释插件：[nerdcommenter](https://github.com/scrooloose/nerdcommenter)

```
Leader+cc       注释光标所在行
Leader+cu       取消注释
```

#### 1.18 围绕字符编辑插件：[vim-surround](https://github.com/tpope/vim-surround)

```
ys+textobj+surroundA        在textobj指定的范围增A围绕字符
yss+surroundA               在当前行增加A围绕字符
ds+surroundA                删除A围绕字符
cs+surroundA+surroundB      将A围绕字符改成B围绕字符
```

#### 1.19 HTML, CSS神器：[emmet-vim](https://github.com/mattn/emmet-vim)

```
Ctrl+y+,        展开模板缩写
```

#### 1.20 Others

```
%               成对标签跳转（(),[],{},<>,html xml标签,if,else,endif等）
bd              删除当前buffer
'.              最后一次变更的地方
''              跳回来的地方（最近两个位置跳转）
Ctrl+o          跳回，可用于多种类型跳转（符号跳转，定义跳转，屏幕跳转等）
Ctrl+i          继续上次跳转（与Ctrl+o操作相反），可用于多种类型跳转（符号跳转，定义跳转，屏幕跳转等）
Leader+cd       切换到当前文件所在项目根路径
Leader+/        取消搜索高亮
Leader+space    去除行尾空白字符
Leader+q        打开/关闭quickfix list
Leader+l        打开/关闭location list
```

### 2. Insert mode

#### 2.1 Remap

```
Ctrl+c  退出当前模式，并返回到正常模式，相当于<ESC>键
```

### 3. Visual mode

#### 3.1 Remap

```
Y       复制到行尾
U       Redo
;       进入命令行模式，相当于“:”键
Ctrl+c  退出当前模式，并返回到正常模式，相当于<ESC>键
```

#### 3.2 Replace

```
Leader+R    替换选中的字符串（不需要逐一确认）
Leader+rc   替换选中的字符串（需要逐一确认）
```

#### 3.3 Programming language

```
K       查看所选字符串在文档（若文件类型为c,c++,sh,go,python,ruby,php,vim，则打开split查看。否则打开dash或zeal查看。）中的解释
```

#### 3.4 包含实用快捷键的插件：[vim-unimpaired](https://github.com/tpope/vim-unimpaired)

```
[x      对选中字符串进行XML encode
]x      对选中字符串进行HTML/XML decode

[u      对选中字符串进行URL encode
]u      对选中字符串进行URL decode

[y      对选中字符串进行C String encode
]y      对选中字符串进行C string decode
```

#### 3.5 快速移动插件：[EasyMotion](https://github.com/easymotion/vim-easymotion)

```
Leader+Leader+j     跳转到当前屏幕，光标后任何指定行
Leader+Leader+k     跳转到当前屏幕，光标前任何指定行
Leader+Leader+w     跳转到当前屏幕，光标后任何指定单词
Leader+Leader+b     跳转到当前屏幕，光标前任何指定单词
Leader+Leader+s     搜索字符，并跳转到当前屏幕指定字符
```

#### 3.6 多光标操作插件：[vim-multiple-cursors](https://github.com/terryma/vim-multiple-cursors)

```
Ctrl+n      选中一个字符串（若未进入多光标模式，则进入）
Ctrl+p      放弃当前选中字符串，回到上次选中的地方（多光标模式下有效）
Ctrl+x      跳过当前选中字符串，选中下一个（多光标模式下有效）
<ESC>       退出多光标模式
```

#### 3.7 区域选中插件：[vim-expand-region](https://github.com/terryma/vim-expand-region)

```
+       扩大选中区域
-       缩小选中区域
```

#### 3.8 注释插件：[nerdcommenter](https://github.com/scrooloose/nerdcommenter)

```
Leader+cc       注释选中的代码
Leader+cu       取消选中代码的注释
```

#### 3.9 围绕字符编辑插件：[vim-surround](https://github.com/tpope/vim-surround)

```
S+surroundA     选中字符串增加A围绕字符
```

#### 3.10 HTML, CSS神器：[emmet-vim](https://github.com/mattn/emmet-vim)

```
Ctrl+y+,        展开模板缩写
```

### 4. Command line mode

```
Ctrl+j  下一条命令
Ctrl+k  上一条命令
Ctrl+a  跳到命令行最前
Ctrl+e  跳到命令行最后

w!!     使用root权限写文件
```

## Useful command

### 1. Ack

```vim
" 递归搜索包含test的代码，搜索结果加载到quickfix list，并打开第一个搜索结果
:Ack -r test

" 递归搜索包含test的代码，搜索结果加载到quickfix list
:Ack! -r test

" 同Ack，但搜索结果加载到location list
:LAck -r test

" 同Ack!，但搜索结果加载到location list
:LAck! -r test
```

### 2. UpdateTags

```vim
" 为当前文件生成tag
:UpdateTags

" 为整个工程生成tag
:UpdateTags -R
```

### 3. YcmGenerateConfig

```vim
" 为整个工程生成.ycm_extra_conf.py文件
:YcmGenerateConfig
```

### 4. DirDiff

```vim
" A, B文件夹进入vimdiff mode
:DirDiff A B
```

### 5. Gist

```bash
# 使用改命令需要先进行以下配置
git config --global github.user <username>
```

```vim
" 将当前buffer，或将选中内容（可视化模式）推送到Gist
:Gist

" 更多Gist的用法，请参考
:h Gist.vim
```

## Use git in vim

### 1. git for vim: [vim-fugitive](https://github.com/tpope/vim-fugitive)

```vim
" 相当于:!git [args]
:Git [args]

" 相当于git status。“g?”命令查看Gstatus窗口支持的操作
:Gstatus

" 相当于git commit
:Gcommit [args]

" 相当于git merge，错误和冲突会加载到quickfix list（Leader+q快捷键打开）
:Gmerge [args]

" 相当于git pull
:Gpull [args]

" 相当于git fetch
:Gfetch [args]

" 相当于git push
:Gpush [args]

" 相当于git grep
:Ggrep [args]

" 在非Gdiff模式下相当于git checkout。args为空的情况下，相当于git checkout %
:Gread [path]

" 在非Gdiff模式下相当于git add。args为空的情况下，相当于git checkout %
:Gwrite [path]

" 相当于git mv % {destination}
:Gmove {destination}

" 相当于git rm %
:Gremove

" 使用vimdiff展示git diff
:Gdiff [args]

" 将当前文件所有历史提交记录加载到quickfix list
" 若带有“--”参数，则展示某次commit的full-diff，而不是历史版本
:Glog [args]

" 同:Glog，把提交记录加载到location list（Leader+l快捷键打开），而不是quickfix list
:Gllog [args]

" 同:Glog，但只针对指定范围（可在可视化模式下使用）
:{range}Glog [args]

" vsplit打开git blame的结果。“g?”命令查看Gblame窗口支持的操作
:Gblame [flags]

" 同:Gblame，但只针对指定范围（可在可视化模式下使用）
:{range}Gblame [flags]

" 详细教程请参考以下视频
https://github.com/tpope/vim-fugitive#screencasts

" 或官方文档
:h fugitive.txt
```

### 2. gitk for vim: [gitv](https://github.com/gregsexton/gitv)

```vim
" 文件模式，显示当前文件的所有历史版本。以split的方式打开Gitv，只显示与当前文件相关的提交
" args为git log所支持的参数
:Gitv! [args]

" 同:Gitv!，但只显示与选中行相关的提交（可在可视化模式下使用）
:{range}Gitv! [args]

" 浏览器模式，显示所有提交的git diff。以tab的方式打开Gitv
:Gitv [args]

" 详细教程请参考官方文档
:h gitv.txt
```

## Precautions

* monkey-vim默认tab的缩进为8个字符，不使用space替代tab。如果你喜欢tab缩进为4个字符，并且使用space替代tab。你可以将以下vim配置

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

* 为了让运行在xterm上的vim可以与系统共享剪贴板，请安装gvim，并在~/.bashrc中加入以下Shell命令：

```bash
if [ -x $(which gvim) ]
then
    alias vi='gvim -v'
    alias vim='gvim -v'
    alias view='gvim -v -R'
    alias vimdiff='gvim -v -d'
fi
```

* 如果你觉得打开/保存go文件需要较长时间，或者你不希望保存go文件时，自动生成可执行文件，你可以将以下vim配置

```vim
let g:syntastic_go_checkers = ['go', 'golint', 'govet', 'errcheck']
```

改为

```vim
let g:syntastic_go_checkers = ['golint', 'govet', 'errcheck']
```

## FAQ

[FAQ](https://github.com/QMonkey/monkey-vim/wiki/FAQ)

## Recommended settings

### How to: Add shell code below to your "~/.bashrc" file

* 使用vman命令，可在vim中下查看man文档

```bash
vman() {
    vim -R -c "Ref man $*" ~/.vimrc \
        -c "if line('$') == 1 | cquit | endif" \
        -c "silent only" \
        -c "setlocal nomodifiable" \
        -c "execute 'bdelete ' . bufnr('~/.vimrc')"
    if [ "$?" != "0" ]; then
        echo "No manual entry for $*"
    fi
}
```

* 使用dirdiff命令，可在vimdiff中查看，比较和编辑两个文件夹

```bash
dirdiff() {
    if [ $# -ne 2 ]; then
        echo "Invalid arguments, please pass two arguments"
        return
    fi

    vim -c "DirDiff $*" ~/.vimrc \
        -c "execute 'bdelete ' . bufnr('~/.vimrc')"
}
```
