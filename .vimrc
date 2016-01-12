set nocompatible
filetype off

" Set the runtime path to include Vundle and initialize
set rtp+=~/.vim/bundle/Vundle.vim
call vundle#begin()
" alternatively, pass a path where Vundle should install plugins
"call vundle#begin('~/some/path/here')

" Let Vundle manage Vundle, required
Plugin 'VundleVim/Vundle.vim'

" Bundle
Bundle 'scrooloose/nerdtree'
Bundle 'szw/vim-tags'
Bundle 'majutsushi/tagbar'
Bundle 'itchyny/lightline.vim'
Bundle 'Chiel92/vim-autoformat'
Bundle 'Shougo/neocomplete.vim'
Bundle 'fatih/vim-go'
Bundle 'tomasr/molokai'
"Bundle 'Rip-Rip/clang_complete'

" All of your Plugins must be added before the following line
call vundle#end()            " required
filetype plugin indent on    " required
" To ignore plugin indent changes, instead use:
"filetype plugin on
"
" Brief help
" :PluginList       - lists configured plugins
" :PluginInstall    - installs plugins; append `!` to update or just
" :PluginUpdate
" :PluginSearch foo - searches for foo; append `!` to refresh local cache
" :PluginClean      - confirms removal of unused plugins; append `!` to
" auto-approve removal
" 
" see :h vundle for more details or wiki for FAQ
" Put your non-Plugin stuff after this line

set number
" show the cursor position all the time
set ruler

" search in time
set incsearch
set hlsearch
set ignorecase

set wildmenu

" share clipboard with system (gvim -v in xterm)
set clipboard=unnamedplus

" make "tab" insert indents instead of tabs at the beginning of a line
set smarttab
" size of a hard tabstop
set tabstop=8
" size of an "indent"
set shiftwidth=8
" never use space to replace tab
set noexpandtab

set foldenable
set foldmethod=manual
set foldlevel=1

language message en_US.UTF-8
set langmenu=en_US.UTF-8 

" character width
set ambiwidth=double

set encoding=utf-8
set fileencodings=utf-8,gb18030,ucs-bom,big5,euc-jp,euc-kr,latin1

" always show status line
set laststatus=2

colorscheme molokai
let g:molokai_original = 1
let g:rehash256 = 1

" Key map
map <F2> :NERDTreeToggle<CR>
map <F3> :TagbarToggle<CR>

" Open a NERDTree automatically when vim starts up
" autocmd vimenter * NERDTree

" Use neocomplete.
let g:neocomplete#enable_at_startup = 1

" Open a NERDTree automatically when vim starts up if no files were specified
autocmd StdinReadPre * let s:std_in=1
autocmd VimEnter * if argc() == 0 && !exists('s:std_in') | NERDTree | endif

" Close vim if the only window left open is a NERDTree
autocmd bufenter * if (winnr('$') == 1 && exists('b:NERDTree') && b:NERDTree.isTabTree()) | q | endif

" Enable auto popup, use <Tab> to autocomplete
let g:clang_complete_auto = 1
" Show clang errors in the quickfix window
let g:clang_complete_copen = 1

" Execute Autoformat onsave
autocmd BufWrite * :Autoformat

" Generic C, C++, Objective-C style
let g:formatdef_clangformat = "'clang-format -style=\"{BasedOnStyle: LLVM, IndentWidth: 8, UseTab: Always, Language: Cpp, BreakBeforeBraces: Allman, AllowShortBlocksOnASingleLine: false, AllowShortFunctionsOnASingleLine: false, AllowShortIfStatementsOnASingleLine: false, AllowShortLoopsOnASingleLine: false, IndentCaseLabels: false, DerivePointerAlignment: false, MaxEmptyLinesToKeep: 1, ColumnLimit: 0, PointerAlignment: Left}\"'"

" go-vim settings
let g:go_highlight_functions               = 1
let g:go_highlight_methods                 = 1
let g:go_highlight_structs                 = 1
let g:go_fmt_fail_silently                 = 1
let g:go_disable_autoinstall               = 1
let g:go_fmt_autosave                      = 1
let g:go_fmt_command                       = "goimports"
let g:godef_split                          = 2
let g:godef_same_file_in_same_window       = 1

let g:tagbar_type_go = {
			\ 'ctagstype' : 'go',
			\ 'kinds'     : [
			\ 'p:package',
			\ 'i:imports:1',
			\ 'c:constants',
			\ 'v:variables',
			\ 't:types',
			\ 'n:interfaces',
			\ 'w:fields',
			\ 'e:embedded',
			\ 'm:methods',
			\ 'r:constructor',
			\ 'f:functions'
			\ ],
			\ 'sro' : '.',
			\ 'kind2scope' : {
			\ 't' : 'ctype',
			\ 'n' : 'ntype'
			\ },
			\ 'scope2kind' : {
			\ 'ctype' : 't',
			\ 'ntype' : 'n'
			\ },
			\ 'ctagsbin'  : 'gotags',
			\ 'ctagsargs' : '-sort -silent'}
