" Add below code to ~/.bashrc
"export TERM=xterm-256color
"
"if [ -x $(which gvim) ]
"then
"	alias vi='gvim -v'
"	alias vim='gvim -v'
"	alias view='gvim -v -R'
"	alias vimdiff='gvim -v -d'
"fi
"
"vman() {
"	vim -R -c "Man $*" -c "if line('$') == 1 | cquit | endif" -c "silent only" -c "setlocal nomodifiable"
"	if [ "$?" != "0" ]; then
"		echo "No manual entry for $*"
"	fi
"}

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
Bundle 'jistr/vim-nerdtree-tabs'
Bundle 'majutsushi/tagbar'
Bundle 'itchyny/lightline.vim'
Bundle 'ctrlpvim/ctrlp.vim'
Bundle 'easymotion/vim-easymotion'
Bundle 'mileszs/ack.vim'
Bundle 'Chiel92/vim-autoformat'
Bundle 'bronson/vim-trailing-whitespace'
Bundle 'airblade/vim-rooter'
Bundle 'xolox/vim-misc'
Bundle 'xolox/vim-easytags'
Bundle 'scrooloose/syntastic'
Bundle 'Valloric/YouCompleteMe'
Bundle 'SirVer/ultisnips'
Bundle 'honza/vim-snippets'
Bundle 'Raimondi/delimitMate'
Bundle 'tpope/vim-endwise'
Bundle 'tpope/vim-ragtag'
Bundle 'docunext/closetag.vim'
Bundle 'fatih/vim-go'
Bundle 'pangloss/vim-javascript'
Bundle 'mattn/emmet-vim'
Bundle 'godlygeek/tabular'
Bundle 'plasticboy/vim-markdown'
Bundle 'cespare/vim-toml'
Bundle 'tpope/vim-fugitive'
Bundle 'gregsexton/gitv'
Bundle 'airblade/vim-gitgutter'
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

set showmatch

" hightlight current line
set cursorline

" search in time
set incsearch
set hlsearch
set ignorecase
set smartcase

set wildmenu
set wildmode=longest,list,full

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

set scrolloff=7

set foldenable
set foldmethod=manual
set foldlevel=99

language message en_US.UTF-8
set langmenu=en_US.UTF-8

" Character width
set ambiwidth=double

scriptencoding utf-8
set encoding=utf-8
set fileencodings=utf-8,gb18030,ucs-bom,big5,euc-jp,euc-kr,latin1

" Only work in terminal vim
set termencoding=utf-8

" A buffer becomes hidden when it is abandoned
set hidden

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
syntax enable
set regexpengine=1

" Key map
noremap q :q<CR>

" tab
map <C-n> :tabnew<CR>
map <S-h> :tabprevious<CR>
map <S-l> :tabNext<CR>
map <leader><S-h> :tabfirst<CR>
map <leader><S-l> :tablast<CR>

" split
map <C-j> <C-w>j
map <C-k> <C-w>k
map <C-h> <C-w>h
map <C-l> <C-w>l
map <leader>s :new<CR>
map <leader>v :vnew<CR>

map <F2> :NERDTreeTabsToggle<CR>
map <F3> :TagbarToggle<CR>

" Open NERDTreeTabs automatically when vim starts up
" let g:nerdtree_tabs_open_on_console_startup = 1

" Open NERDTreeTabs automatically when vim starts up if no files were specified
" autocmd StdinReadPre * let s:std_in = 1
" autocmd VimEnter * if argc() == 0 && !exists('s:std_in') | execute ':NERDTreeTabsOpen' | endif

" Auto set tag file path, when vim start
autocmd BufReadPre,FileReadPre * execute !empty(FindRootDirectory()) ? 'setlocal tags=' . FindRootDirectory() . "/.tags" : 'setlocal tags=./.tags'

" Highlight .tags file as tags file
autocmd BufNewFile,BufRead *.tags set filetype=tags

" Close vim if the only window left open is a NERDTree
autocmd BufEnter * if (winnr('$') == 1 && exists('b:NERDTree') && b:NERDTree.isTabTree()) | q | endif

" Execute Autoformat onsave
autocmd BufWrite * :Autoformat

" YouCompleteMe
if !empty(glob('~/.vim/bundle/YouCompleteMe/third_party/ycmd/cpp/ycm/.ycm_extra_conf.py'))
	let g:ycm_global_ycm_extra_conf = '~/.vim/bundle/YouCompleteMe/third_party/ycmd/cpp/ycm/.ycm_extra_conf.py'
endif
let g:ycm_complete_in_comments = 1
let g:ycm_complete_in_strings = 1
let g:ycm_use_ultisnips_completer = 1
let g:ycm_collect_identifiers_from_comments_and_strings = 1
let g:ycm_collect_identifiers_from_tags_files = 1
let g:ycm_seed_identifiers_with_syntax = 1
let g:ycm_autoclose_preview_window_after_insertion = 1
let g:ycm_goto_buffer_command = 'same-buffer'
let g:ycm_filepath_completion_use_working_dir = 1

" Use Ctrl-o to jump back, see :help jumplist
nnoremap <leader>jd :YcmCompleter GoToDefinitionElseDeclaration<CR>
nnoremap <leader>dc :YcmCompleter GoToDeclaration<CR>
nnoremap <leader>ji :YcmCompleter GoToInclude<CR>
nnoremap <leader>jim :YcmCompleter GoToImprecise<CR>

" Generic C, C++, Objective-C style
let g:formatdef_clangformat = "'clang-format -style=\"{BasedOnStyle: LLVM, IndentWidth: 8, UseTab: Always, Language: Cpp, BreakBeforeBraces: Allman, AllowShortBlocksOnASingleLine: false, AllowShortFunctionsOnASingleLine: false, AllowShortIfStatementsOnASingleLine: false, AllowShortLoopsOnASingleLine: false, IndentCaseLabels: false, DerivePointerAlignment: false, MaxEmptyLinesToKeep: 1, ColumnLimit: 0, PointerAlignment: Left}\"'"

" vim-go settings
let g:go_highlight_functions = 1
let g:go_highlight_methods = 1
let g:go_highlight_structs = 1
let g:go_highlight_build_constraints = 1
let g:go_fmt_fail_silently = 1
let g:go_disable_autoinstall = 1
let g:go_fmt_autosave = 1
let g:go_fmt_command = "goimports"
let g:godef_split = 2
let g:godef_same_file_in_same_window = 1

" Use Ctrl-o to jump back, see :help jumplist
nnoremap <leader>gd :GoDef<CR>
nnoremap <leader>gi :GoImports<CR>
nnoremap <leader>gt :GoTest<CR>
nnoremap <leader>gtf :GoTestFunc<CR>
nnoremap <leader>gl :GoLint<CR>
nnoremap <leader>gv :GoVet<CR>
nnoremap <leader>gdc :GoDoc<CR>

" Vim man
source $VIMRUNTIME/ftplugin/man.vim
noremap <S-k> :Man <cword><CR>

" CtrlP runtime path
set runtimepath^=~/.vim/bundle/ctrlp.vim

" vim-easytags
let g:easytags_async = 1

" Disable recurse, do it manually by :UpdateTags -R
" let g:easytags_autorecurse = 1

" Global tag file
let g:easytags_file = '~/.vim/.tags'

let g:easytags_opts = ['--fields=+l']
" Create dynamic tag file if not exists
let g:easytags_dynamic_files = 2
" Disable auto update tag files
let g:easytags_auto_update = 1

" Only update tag file on write
let g:easytags_events = ['BufWritePost']
let g:easytags_on_cursorhold = 0
" Update interval, default 4s
" let g:easytags_updatetime_min = 10000

" vim-rooter
let g:rooter_silent_chdir = 1

" Syntastic
let g:syntastic_error_symbol = '>>'
let g:syntastic_warning_symbol = '>'
let g:syntastic_always_populate_loc_list = 0
let g:syntastic_auto_loc_list = 0
let g:syntastic_check_on_open = 1
let g:syntastic_check_on_wq = 0
let g:syntastic_enable_highlighting = 1

function! ToggleErrors()
	let old_last_winnr = winnr('$')
	lclose
	if old_last_winnr == winnr('$')
		" Nothing was closed, open syntastic_error location panel
		Errors
	endif
endfunction
nnoremap <Leader>e :call ToggleErrors()<cr>
" nnoremap <Leader>sn :lnext<cr>
" nnoremap <Leader>sp :lprevious<cr>

" Emmet
" Enable all function in all mode.
let g:user_emmet_mode = 'a'

" Ultisnips
let g:UltiSnipsExpandTrigger="<C-e>"

" vim-EasyMotion
let g:EasyMotion_smartcase = 1

map <Leader><leader>h <Plug>(easymotion-linebackward)
map <Leader><Leader>j <Plug>(easymotion-j)
map <Leader><Leader>k <Plug>(easymotion-k)
map <Leader><leader>l <Plug>(easymotion-lineforward)
map <Leader><Leader>w <Plug>(easymotion-w)
map <Leader><Leader>b <Plug>(easymotion-b)
map <Leader><leader>s <Plug>(easymotion-sn)
