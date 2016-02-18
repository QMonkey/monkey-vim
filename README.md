# monkey-vim

## 简介

也许你也有这样的经历：IDE不够强大，于是你给你的IDE装上各种各样的插件。随着插件增多，你发现IDE变得越来越卡，占用越来越多系统资源（我的Atom曾经占用了2G内存！！！）。最后，你不得不在强大和轻量之间权衡。

monkey-vim项目，旨在打造一个强大，快速，并且占用少量系统资源的IDE。

## 安装步骤

### 1. clone到本地

```
git clone https://github.com/QMonkey/monkey-vim.git
```

### 2. 安装依赖

#### 2.1 工具依赖

```
# Ubuntu
sudo apt-get install ctags
sudo apt-get install ack-grep

# OpenSUSE
sudo zypper install ctags
sudo zypper install ack

# CentOS
sudo yum install ctags
sudo yum install ack
```

#### 2.2 C/C++

```
# Ubuntu
sudo apt-get install gcc
sudo apt-get install g++
sudo apt-get install llvm

# OpenSUSE
sudo zypper install gcc
sudo zypper install gcc-c++
sudo zypper install llvm-clang

# CentOS
sudo yum install gcc
sudo yum install gcc-c++
sudo yum install clang
```

#### 2.2 Javascript

```
sudo npm install -g jslint
sudo npm install -g js-beautify
sudo npm install -g tern
```

#### 2.3 JSON

```
sudo npm install -g jsonlint
```

#### 2.4 HTML

```
sudo npm install -g jshint
```

#### 2.5 CSS

```
sudo npm install -g csslint
```

#### 2.6 Python

```
sudo pip install pyflakes
sudo pip install autopep8
sudo pip install pep8
sudo pip install jedi
```

#### 2.7 Golang

```
# Ubuntu
sudo apt-get install golang

# OpenSUSE
sudo zypper install go

# CentOS
sudo zypper install golang

# monkey-vim 安装成功后，执行以下vim命令
:GoInstallBinaries
```

#### 2.8 Java

```
# Ubuntu
sudo apt-get install astyle
sudo apt-get install openjdk-8-jdk

# OpenSUSE
sudo zypper install astyle
sudo zypper install java-1_8_0-openjdk-devel

# CentOS
sudo yum install astyle
sudo yum install java-1.7.0-openjdk-headless.x86_64
```

#### 2.9 Shell

```
# Ubuntu
sudo apt-get install devscripts

# OpenSUSE
sudo zypper install checkbashisms

# CentOS
sudo yum install rpmdevtools
```

#### 2.10 Markdown

```
sudo npm install -g instant-markdown-d
sudo gem install mdl
```

### 3. 安装

```
cd monkey-vim
cp .vimrc ~/.vimrc
vim
```

## 快捷键

```
以下所有“Leader”键，都代表“\”键
```

### 1. 正常模式

```
# 按键修改
Y       复制到行尾，相当于“y$”命令
U       Redo，相当于“Ctrl-r”
;       进入命令行模式，相当于“:”键
q       退出窗口，相当于命令“:q”
Ctrl+c  退出当前模式，并返回到正常模式，相当于<ESC>键

# F2 ~ F10
F2  打开/关闭NERDTree
F3  打开/关闭Tagbar
F4  打开/关闭Gundo
F5  打开/关闭paste模式
F6  运行当前项目（可用:Focus注册执行的命令，如:Focus gcc % -o a.out）
F7  异步运行当前项目
F8  显示F6或F7运行结果
F9  预览Markdown
F10 打开/关闭RainbowParentheses
F11 全屏切换（仅在gui模式下有效）

# 分屏
Leader+s 输入打开文件的路径，并创建一个水平分屏的窗口
Leader+v 输入打开文件的路径，并创建一个垂直分屏的窗口

Ctrl+h 跳转到左窗口
Ctrl+j 跳转到下窗口
Ctrl+k 跳转到上窗口
Ctrl+l 跳转到右窗口

Ctrl+up     窗口垂直方向伸展
Ctrl+down   窗口垂直方向收缩
Ctrl+left   窗口水平方向伸展
Ctrl+right  窗口水平方向收缩
Leader+z    窗口放大/恢复

# Tab
C-t 输入打开的文件路径，并创建一个新tab窗口

H           切换到上一个tab窗口
L           切换到下一个tab窗口
Leader+1~9  切换到第1~9个tab窗口
Leader+[    切换到第一个tab窗口
Leader+]    切换到最后一个tab窗口

# 语言相关
K 查看光标所在的单词在文档（目前只支持man, godoc, pydoc, vim help）中的解释。

# 其它
Leader+/        取消搜索高亮
Leader+space    去除行尾空白字符
```

### 2. 插入模式

```
Ctrl+c  退出当前模式，并返回到正常模式，相当于<ESC>键
```

### 3. 可视化模式

```
# 按键修改
Y       复制到行尾
U       Redo
;       进入命令行模式，相当于“:”键
Ctrl+c  退出当前模式，并返回到正常模式，相当于<ESC>键

# 语言相关
K 查看所选字符串在文档（目前只支持man, godoc, pydoc, vim help）中的解释。
```

### 4. 命令行模式

```
Ctrl+j 下一条命令
Ctrl+k 上一条命令
Ctrl+a 跳到命令行最前
Ctrl+e 跳到命令行最后
```
