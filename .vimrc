" Add below code to ~/.bashrc
"export TERM=xterm-256color
"
"if [ -x $(which gvim) ]
"then
"	alias vi='gvim -v'
"	alias vim='gvim -v'
"fi

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
Bundle 'majutsushi/tagbar'
Bundle 'itchyny/lightline.vim'
Bundle 'ctrlpvim/ctrlp.vim'
Bundle 'Chiel92/vim-autoformat'
Bundle 'bronson/vim-trailing-whitespace'
Bundle 'scrooloose/syntastic'
Bundle 'Valloric/YouCompleteMe'
Bundle 'Raimondi/delimitMate'
Bundle 'docunext/closetag.vim'
Bundle 'fatih/vim-go'
Bundle 'tpope/vim-fugitive'
Bundle 'tomasr/molokai'

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
set smartcase

set wildmenu
set completeopt=longest,menu

set smartindent
set autoindent

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

" Character width
set ambiwidth=double

scriptencoding utf-8
set encoding=utf-8
set fileencodings=utf-8,gb18030,ucs-bom,big5,euc-jp,euc-kr,latin1

" Always show status line
set laststatus=2

" lightline.vim
let g:lightline = {
			\ 'colorscheme': 'powerline',
			\ 'active': {
			\   'left': [ [ 'mode', 'paste' ],
			\             [ 'fugitive', 'filename' ] ]
			\ },
			\ 'component_function': {
			\   'fugitive': 'LightLineFugitive',
			\   'readonly': 'LightLineReadonly',
			\   'modified': 'LightLineModified',
			\   'filename': 'LightLineFilename'
			\ }
			\ }

function! LightLineModified()
	if &filetype == "help"
		return ""
	elseif &modified
		return "+"
	elseif &modifiable
		return ""
	else
		return ""
	endif
endfunction

function! LightLineReadonly()
	if &filetype == "help"
		return ""
	elseif &readonly
		return "\ue0a2"
	else
		return ""
	endif
endfunction

function! LightLineFugitive()
	if exists("*fugitive#head")
		let _ = fugitive#head()
		return strlen(_) ? "\ue0a0 "._ : ''
	endif
	return ''
endfunction

function! LightLineFilename()
	return ('' != LightLineReadonly() ? LightLineReadonly() . ' ' : '') .
				\ ('' != expand('%:t') ? expand('%:t') : '[No Name]') .
				\ ('' != LightLineModified() ? ' ' . LightLineModified() : '')
endfunction

" must execute 'export TERM=xterm-256color' first
colorscheme molokai
let g:molokai_original = 1
let g:rehash256 = 1

" Key map
map <F2> :NERDTreeToggle<CR>
map <F3> :TagbarToggle<CR>

" Open a NERDTree automatically when vim starts up
" autocmd vimenter * NERDTree

" Open a NERDTree automatically when vim starts up if no files were specified
autocmd StdinReadPre * let s:std_in=1
autocmd VimEnter * if argc() == 0 && !exists('s:std_in') | NERDTree | endif

" Close vim if the only window left open is a NERDTree
autocmd bufenter * if (winnr('$') == 1 && exists('b:NERDTree') && b:NERDTree.isTabTree()) | q | endif

" Execute Autoformat onsave
autocmd BufWrite * :Autoformat

" YouCompleteMe
if !empty(glob("~/.vim/bundle/YouCompleteMe/third_party/ycmd/cpp/ycm/.ycm_extra_conf.py"))
	let g:ycm_global_ycm_extra_conf = "~/.vim/bundle/YouCompleteMe/third_party/ycmd/cpp/ycm/.ycm_extra_conf.py"
endif
let g:ycm_complete_in_comments = 1
let g:ycm_complete_in_strings = 1
let g:ycm_use_ultisnips_completer = 1
let g:ycm_collect_identifiers_from_comments_and_strings = 1
let g:ycm_collect_identifiers_from_tags_files = 1
let g:ycm_seed_identifiers_with_syntax=1
let g:ycm_goto_buffer_command = 'new-or-existing-tab'

nnoremap <leader>gd :YcmCompleter GoToDefinitionElseDeclaration<CR>
nnoremap <leader>dc :YcmCompleter GoToDeclaration<CR>

" Generic C, C++, Objective-C style
let g:formatdef_clangformat = "'clang-format -style=\"{BasedOnStyle: LLVM, IndentWidth: 8, UseTab: Always, Language: Cpp, BreakBeforeBraces: Allman, AllowShortBlocksOnASingleLine: false, AllowShortFunctionsOnASingleLine: false, AllowShortIfStatementsOnASingleLine: false, AllowShortLoopsOnASingleLine: false, IndentCaseLabels: false, DerivePointerAlignment: false, MaxEmptyLinesToKeep: 1, ColumnLimit: 0, PointerAlignment: Left}\"'"

" vim-go settings
let g:go_highlight_functions               = 1
let g:go_highlight_methods                 = 1
let g:go_highlight_structs                 = 1
let g:go_fmt_fail_silently                 = 1
let g:go_disable_autoinstall               = 1
let g:go_fmt_autosave                      = 1
let g:go_fmt_command                       = "goimports"
let g:godef_split                          = 2
let g:godef_same_file_in_same_window       = 1

" CtrlP runtime path
set runtimepath^=~/.vim/bundle/ctrlp.vim

" Tagbar
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

" Syntastic
let g:syntastic_always_populate_loc_list = 0
let g:syntastic_auto_loc_list = 0
let g:syntastic_check_on_open = 1
let g:syntastic_check_on_wq = 0
let g:syntastic_enable_highlighting=1
