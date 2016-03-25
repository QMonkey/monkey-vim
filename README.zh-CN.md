# monkey-vim

其他语言版本：[English](README.md)

## 简介

也许你也有这样的经历：IDE不够强大，于是你给你的IDE装上各种各样的插件。随着插件增多，你发现IDE变得越来越卡，占用越来越多系统资源（我的Atom曾经占用了2G内存！！！）。最后，你不得不在强大和轻量之间权衡。

monkey-vim项目，旨在打造一个强大，快速，并且占用少量系统资源的IDE。

## 截图

- **xterm vim**

![xterm vim](https://raw.githubusercontent.com/QMonkey/monkey-vim/master/pictures/xterm_vim.png "xterm vim")

- **gvim**

![gvim](https://raw.githubusercontent.com/QMonkey/monkey-vim/master/pictures/gvim.png "gvim")

## 安装步骤

### 1. clone到本地

```bash
git clone https://github.com/QMonkey/monkey-vim.git
```

### 2. 安装依赖

#### 2.1 工具依赖

```bash
# Ubuntu
sudo apt-get install ctags
sudo apt-get install silversearcher-ag 或 sudo apt-get install ack-grep
sudo apt-get install fortune
sudo apt-get install cowsay

# OpenSUSE
sudo zypper install ctags
sudo zypper install the_silver_searcher 或 sudo zypper install ack
sudo zypper install fortune
sudo zypper install cowsay

# CentOS
sudo yum install ctags
sudo yum install the_silver_searcher 或 sudo yum install ack
sudo yum install fortune-mod
sudo yum install cowsay
```

#### 2.2 Fonts

- [powerline-font](https://github.com/powerline/fonts)
- [nerd-font](https://github.com/ryanoasis/nerd-fonts)

#### 2.3 Docset

- [Dash](https://kapeli.com/dash/)
- [Zeal](https://zealdocs.org/)

#### 2.4 Eclim

Java, Ruby, PHP代码补全插件：[Eclim](http://eclim.org/)

#### 2.5 C/C++

```bash
# Ubuntu
sudo apt-get install gcc
sudo apt-get install g++
# x取决于你要安装的版本
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

#### 2.6 Javascript

```bash
sudo npm install -g jslint
sudo npm install -g js-beautify
sudo npm install -g tern
```

#### 2.7 JSON

```bash
sudo npm install -g jsonlint
```

#### 2.8 HTML

```bash
sudo npm install -g jshint
```

#### 2.9 CSS

```bash
sudo npm install -g csslint
```

#### 2.10 Python

```bash
sudo pip install pyflakes
sudo pip install autopep8
sudo pip install pep8
sudo pip install jedi
```

#### 2.11 Golang

```bash
# Ubuntu
sudo apt-get install golang

# OpenSUSE
sudo zypper install go

# CentOS
sudo zypper install golang

# 其他golang依赖工具
# monkey-vim 安装成功后，执行以下vim命令
:GoInstallBinaries
```

#### 2.12 Java

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

#### 2.13 PHP

```bash
pear install doc.php.net/pman
```

#### 2.14 Shell

```bash
# Ubuntu
sudo apt-get install devscripts

# OpenSUSE
sudo zypper install checkbashisms

# CentOS
sudo yum install rpmdevtools
```

#### 2.15 Markdown

```bash
sudo npm install -g instant-markdown-d
sudo npm install -g remark
sudo gem install mdl
```

### 3. 安装

```bash
cd monkey-vim
cp .vimrc ~/.vimrc
vim
```

## 快捷键

```
以下所有“Leader”键，都代表“,”键
```

### 1. 正常模式

#### 1.1 按键修改

```
Y       复制到行尾，相当于“y$”命令
U       Redo，相当于“Ctrl-r”
;       进入命令行模式，相当于“:”键
q       退出窗口，相当于命令“:q”
Ctrl+c  退出当前模式，并返回到正常模式，相当于<ESC>键
```

#### 1.2 F2 ~ F10

```
F2      打开/关闭NERDTree
F3      打开/关闭Tagbar
F4      打开/关闭Gundo
F5      打开/关闭paste模式
F6      运行当前项目（可用:FocusDispatch注册执行的命令，如:FocusDispatch gcc % -o a.out）
F7      异步运行当前项目
F8      打开/关闭F6或F7运行结果
F9      预览Markdown
F10     打开/关闭RainbowParentheses
F11     全屏切换（仅在gui模式下有效）
```

#### 1.3 缓冲

```
Leader+o    输入打开文件的路径，并在当前窗口打开一个缓冲
bd          删除当前buffer
```

#### 1.4 分屏

```
Leader+s    输入打开文件的路径，并创建一个水平分屏的窗口
Leader+v    输入打开文件的路径，并创建一个垂直分屏的窗口

Ctrl+h      跳转到左窗口
Ctrl+j      跳转到下窗口
Ctrl+k      跳转到上窗口
Ctrl+l      跳转到右窗口

Ctrl+up     窗口垂直方向伸展
Ctrl+down   窗口垂直方向收缩
Ctrl+left   窗口水平方向伸展
Ctrl+right  窗口水平方向收缩
Leader+z    窗口放大/恢复

Leader+ww   交换两个窗口（两个窗口都需要执行该命令）
```

#### 1.5 Tab

```
Leader+t      输入打开的文件路径，并创建一个新tab窗口

H           切换到上一个tab窗口
L           切换到下一个tab窗口
Leader+1~9  切换到第1~9个tab窗口
Leader+[    切换到第一个tab窗口
Leader+]    切换到最后一个tab窗口
```

#### 1.6 查找

```
#       正向查找光标所在的单词
*       逆向查找光标所在的单词
```

#### 1.7 替换

```
Leader+R    替换光标所在的单词（非整词，不需要逐一确认）
Leader+rw   替换光标所在的单词（整词，不需要逐一确认）
Leader+rc   替换光标所在的单词（非整词，需要逐一确认）
Leader+rcw  替换光标所在的单词（整词，需要逐一确认）
```

#### 1.8 语言相关

```
K                   查看光标所在的单词在文档（若文件类型为c,c++,sh,go,python,ruby,php,vim，则打开split查看。否则打开dash或zeal查看。）中的解释
Leader+Leader+z     输入语言类型和关键字，在dash或zeal中查看相应的解释

gd      GoDef
gi      GoImports
gt      GoTest，执行当前go文件的单元测试
gf      GoTestFunc，执行光标所在的单元测试函数
```

#### 1.9 Ctags

```
Ctrl+]  跳转到符号定义处，如有多处定义，则跳到第一处
g]      选择一处符号定义并跳转
```

#### 1.10 Marks

```
m[a-zA-Z]   标记当前行
dm[a-zA-Z]  删除标记[a-zA-Z]

'[a-zA-Z]   跳转到标记行

m/          在Location List里，查看当前buffer的所有标记
m-          删除当前行的所有标记
m<space>    删除当前buffer的所有标记
```

#### 1.11 包含实用快捷键的插件：[vim-unimpaired](https://github.com/tpope/vim-unimpaired)

```
[b                  切换到上一个buffer窗口
]b                  切换到下一个buffer窗口
[B                  切换到第一个buffer窗口
]B                  切换到最后一个buffer窗口

[t                  切换到上一个tab窗口
]t                  切换到下一个tab窗口
[T                  切换到第一个tab窗口
]T                  切换到最后一个tab窗口

[n                  跳到版本管理上一次冲突的地方
]n                  跳到版本管理下一次冲突的地方

[<Space>            当前行之前增加[count]个空行
]<Space>            当前行之后增加[count]个空行

[e                  交换当前行和前[count]行
]e                  交换当前行和后[count]行

cob                 切换'background' (dark/light)
coc                 切换'cursorline'
cod                 切换'diff' (:diffthis/:diffoff)
coh                 切换'hlsearch'
coi                 切换'ignorecase'
col                 切换'list'
con                 切换'number'
cor                 切换'relativenumber'
cos                 切换'spell'
cou                 切换'cursorcolumn'
cov                 切换'virtualedit'
cow                 切换'wrap'
cox                 同时切换'cursorline'和'cursorcolumn'

[x{motion}          对motion选中的字符串进行XML encode
[xx                 对当前行进行XML encode
]x{motion}          对motion选中的字符串进行HTML/XML decode
]xx                 对当前行进行HTML/XML decode

[u{motion}          对motion选中行的字符串进行URL encode
[uu                 对当前行进行URL encode
]u{motion}          对motion选中的字符串进行URL decode
]uu                 对当前行进行URL decode

[y{motion}          对motion选中的字符串进行C String encode
[yy                 对当前行进行C String encode
]y{motion}          对motion选中的字符串进行C String decode
]yy                 对当前行进行C String decode
```

#### 1.12 代码补全，定义、声明跳转插件：[YouCompleteMe](https://github.com/Valloric/YouCompleteMe)

```
gd          跳转到定义
Leader+jd   跳转到声明
Leader+ji   跳转到头文件
```

#### 1.13 静态语义语法检查插件：[Syntastic](https://github.com/scrooloose/syntastic)

```
Leader+e    打开/关闭错误信息窗口
```

#### 1.14 快速移动插件：[EasyMotion](https://github.com/easymotion/vim-easymotion)

```
Leader+Leader+j     跳转到当前屏幕，光标后任何指定行
Leader+Leader+k     跳转到当前屏幕，光标前任何指定行
Leader+Leader+w     跳转到当前屏幕，光标后任何指定单词
Leader+Leader+b     跳转到当前屏幕，光标前任何指定单词
Leader+Leader+s     搜索字符，并跳转到当前屏幕指定字符
```

#### 1.15 buffer、tab切换，保存/恢复workspace插件：[Vim-CtrlSpace](https://github.com/vim-ctrlspace/vim-ctrlspace)

```
Ctrl+Space  打开CtrlSpace

Leader+bs   保存workspace
Leader+rs   恢复workspace
```

#### 1.16 项目文件搜索插件：[CtrlP](https://github.com/ctrlpvim/ctrlp.vim)

```
Ctrl+p      打开CtrlP
```

#### 1.17 多光标操作插件：[vim-multiple-cursors](https://github.com/terryma/vim-multiple-cursors)

```
Ctrl+n      选中当前单词（若未进入多光标模式，则进入）
Ctrl+p      放弃当前选中字符串，回到上次选中的地方（多光标模式下有效）
Ctrl+x      跳过当前选中字符串，选中下一个（多光标模式下有效）
<ESC>       退出多光标模式
```

#### 1.18 区域选中插件：[vim-expand-region](https://github.com/terryma/vim-expand-region)

```
+       扩大选中区域，并进入可视化模式
```

#### 1.19 注释插件：[nerdcommenter](https://github.com/scrooloose/nerdcommenter)

```
Leader+cc       注释光标所在行
Leader+cu       取消注释
```

#### 1.20 围绕字符编辑插件：[vim-surround](https://github.com/tpope/vim-surround)

```
ys+textobj+surroundA        在textobj指定的范围增A围绕字符
yss+surroundA               在当前行增加A围绕字符
ds+surroundA                删除A围绕字符
cs+surroundA+surroundB      将A围绕字符改成B围绕字符
```

#### 1.21 HTML, CSS神器：[emmet-vim](https://github.com/mattn/emmet-vim)

```
Ctrl+y+,        展开模板缩写
```

```vim
" 更多emmet帮助，请参考：
:h emmet
```

#### 1.22 其他

```
%               成对标签跳转（(),[],{},<>,html xml标签,if,else,endif等）
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

### 2. 插入模式

#### 2.1 按键修改

```
Ctrl+c  退出当前模式，并返回到正常模式，相当于<ESC>键
Ctrl+d  删除当前行
```

### 3. 可视化模式

#### 3.1 按键修改

```
Y       复制到行尾
U       Redo
;       进入命令行模式，相当于“:”键
Ctrl+c  退出当前模式，并返回到正常模式，相当于<ESC>键
```

#### 3.2 查找

```
#       正向查找选中的字符串
*       逆向查找选中的字符串
```

#### 3.3 替换

```
Leader+R    替换选中的字符串（不需要逐一确认）
Leader+rc   替换选中的字符串（需要逐一确认）
```

#### 3.4 语言相关

```
K       查看所选字符串在文档（若文件类型为c,c++,sh,go,python,ruby,php,vim，则打开split查看。否则打开dash或zeal查看。）中的解释
```

#### 3.5 包含实用快捷键的插件：[vim-unimpaired](https://github.com/tpope/vim-unimpaired)

```
[x      对选中字符串进行XML encode
]x      对选中字符串进行HTML/XML decode

[u      对选中字符串进行URL encode
]u      对选中字符串进行URL decode

[y      对选中字符串进行C String encode
]y      对选中字符串进行C string decode
```

#### 3.6 快速移动插件：[EasyMotion](https://github.com/easymotion/vim-easymotion)

```
Leader+Leader+j     跳转到当前屏幕，光标后任何指定行
Leader+Leader+k     跳转到当前屏幕，光标前任何指定行
Leader+Leader+w     跳转到当前屏幕，光标后任何指定单词
Leader+Leader+b     跳转到当前屏幕，光标前任何指定单词
Leader+Leader+s     搜索字符，并跳转到当前屏幕指定字符
```

#### 3.7 多光标操作插件：[vim-multiple-cursors](https://github.com/terryma/vim-multiple-cursors)

```
Ctrl+n      选中一个字符串（若未进入多光标模式，则进入）
Ctrl+p      放弃当前选中字符串，回到上次选中的地方（多光标模式下有效）
Ctrl+x      跳过当前选中字符串，选中下一个（多光标模式下有效）
<ESC>       退出多光标模式
```

#### 3.8 区域选中插件：[vim-expand-region](https://github.com/terryma/vim-expand-region)

```
+       扩大选中区域
-       缩小选中区域
```

#### 3.9 注释插件：[nerdcommenter](https://github.com/scrooloose/nerdcommenter)

```
Leader+cc       注释选中的代码
Leader+cu       取消选中代码的注释
```

#### 3.10 围绕字符编辑插件：[vim-surround](https://github.com/tpope/vim-surround)

```
S+surroundA     选中字符串增加A围绕字符
```

#### 3.11 HTML, CSS神器：[emmet-vim](https://github.com/mattn/emmet-vim)

```
Ctrl+y+,        展开模板缩写
```

```vim
" 更多emmet帮助，请参考：
:h emmet
```

### 4. 命令行模式

```
Ctrl+j  下一条命令
Ctrl+k  上一条命令
Ctrl+a  跳到命令行最前
Ctrl+e  跳到命令行最后
```

## 常用命令

### 1. SudoWrite

```vim
" 使用root权限写文件
:SudoWrite
```

### 2. Ack

```vim
" 递归搜索包含test的代码，搜索结果加载到quickfix list，并打开第一个搜索结果
:Ack test

" 递归搜索包含test的代码，搜索结果加载到quickfix list
:Ack! test

" 同Ack，但搜索结果加载到location list
:LAck test

" 同Ack!，但搜索结果加载到location list
:LAck! test
```

### 3. UpdateTags

```vim
" 为当前文件生成tag
:UpdateTags

" 为整个工程生成tag
:UpdateTags -R
```

### 4. YcmGenerateConfig

```vim
" 为整个工程生成.ycm_extra_conf.py文件
:YcmGenerateConfig
```

### 5. DirDiff

```vim
" A, B文件夹进入vimdiff mode
:DirDiff A B
```

### 6. Gist

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

## 在vim中使用git

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

" 在非Gdiff模式下相当于git add。args为空的情况下，相当于git add %
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

## 用Eclim命令管理eclipse项目

- Eclipse项目管理命令，请参考[这里](http://eclim.org/vim/core/project.html)

- Java项目管理命令，请参考[这里](http://eclim.org/vim/java/index.html)

- Ruby项目管理命令，请参考[这里](http://eclim.org/vim/ruby/index.html)

- PHP项目管理命令，请参考[这里](http://eclim.org/vim/php/index.html)

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

- 为了让运行在xterm上的vim可以与系统共享剪贴板，请安装gvim，并在~/.bashrc中加入以下Shell命令：

```bash
if [ -x $(which gvim) ]
then
    alias vi='gvim -v'
    alias vim='gvim -v'
    alias view='gvim -v -R'
    alias vimdiff='gvim -v -d'
fi
```

- 如果你想在保存的时候，检查go代码的编译错误，你可以将以下vim配置

```vim
let g:syntastic_go_checkers = ['golint', 'govet', 'errcheck']
```

改为

```vim
let g:syntastic_go_checkers = ['go', 'golint', 'govet', 'errcheck']
```

## FAQ

[FAQ](https://github.com/QMonkey/monkey-vim/wiki/FAQ.zh_CN)

## 推荐设置

### 设置方法：在~/.bashrc中加入以下Shell命令

- 使用vman命令，可在vim中下查看man文档

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

- 使用dirdiff命令，可在vimdiff中查看，比较和编辑两个文件夹

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

## 意见或建议

如果你对monkey-vim项目有什么意见或建议，欢迎给我个[issue](https://github.com/QMonkey/monkey-vim/issues)
