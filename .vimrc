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
"Bundle 'fholgado/minibufexpl.vim'
Bundle 'sjl/gundo.vim'
Bundle 'vim-airline/vim-airline'
Bundle 'ryanoasis/vim-devicons'
Bundle 'ctrlpvim/ctrlp.vim'
Bundle 'easymotion/vim-easymotion'
Bundle 'mileszs/ack.vim'
Bundle 'scrooloose/nerdcommenter'
Bundle 'mhinz/vim-startify'
Bundle 'Chiel92/vim-autoformat'
Bundle 'bronson/vim-trailing-whitespace'
Bundle 'tpope/vim-dispatch'
Bundle 'airblade/vim-rooter'
Bundle 'xolox/vim-misc'
Bundle 'xolox/vim-easytags'
Bundle 'xolox/vim-session'
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
Bundle 'suan/vim-instant-markdown'
Bundle 'sheerun/vim-polyglot'
Bundle 'tpope/vim-fugitive'
Bundle 'gregsexton/gitv'
Bundle 'airblade/vim-gitgutter'
Bundle 'tomasr/molokai'
Bundle 'kien/rainbow_parentheses.vim'

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
" By default add g flag to search/replace.
set gdefault

set wildmenu
set wildmode=list:longest,full

set smartindent
set autoindent

" Share clipboard with system (gvim -v in xterm)
set clipboard=unnamedplus

" Make "tab" insert indents instead of tabs at the beginning of a line
set smarttab
" Size of a hard tabstop
set tabstop=8
set softtabstop=8
" Size of an "indent"
set shiftwidth=8
" Never use space to replace tab
set noexpandtab

" Unrecognized filetype set to text
autocmd BufNewFile,BufRead * if &filetype == "" | setfiletype text | endif

autocmd FileType python setlocal expandtab tabstop=4 shiftwidth=4 softtabstop=4
autocmd FileType markdown setlocal expandtab tabstop=4 shiftwidth=4 softtabstop=4 equalprg=pandoc\ -f\ markdown_github\ -t\ markdown_github\ --atx-headers
" Disable autoindent for text file
autocmd FileType text setlocal equalprg=cat

set scrolloff=7

" Enable undo file
set undofile
" Undo files
set undodir=~/.vim/undofiles/

" Disable fold on start up
set nofoldenable
set foldmethod=syntax
set foldlevel=1

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

" Auto reload file changes outside vim
set autoread

" No error bells
set noerrorbells
set novisualbell
set t_vb=

" Always show status line
set laststatus=2

let g:airline_theme = 'badwolf'
let g:airline_detect_paste = 1
let g:airline#extensions#syntastic#enabled = 1
let g:airline#extensions#tagbar#enabled = 1
let g:airline_left_sep = ""
let g:airline_right_sep = ""
if !exists('g:airline_symbols')
	let g:airline_symbols = {}
endif
let g:airline_symbols.branch = "\ue0a0"
let g:airline_symbols.readonly = "\ue0a2"
let g:airline_symbols.linenr = "LN"

let g:rbpt_colorpairs = [
			\ ['brown',       'RoyalBlue3'],
			\ ['Darkblue',    'SeaGreen3'],
			\ ['darkgray',    'DarkOrchid3'],
			\ ['darkgreen',   'firebrick3'],
			\ ['darkcyan',    'RoyalBlue3'],
			\ ['darkred',     'SeaGreen3'],
			\ ['darkmagenta', 'DarkOrchid3'],
			\ ['brown',       'firebrick3'],
			\ ['gray',        'RoyalBlue3'],
			\ ['black',       'SeaGreen3'],
			\ ['darkmagenta', 'DarkOrchid3'],
			\ ['Darkblue',    'firebrick3'],
			\ ['darkgreen',   'RoyalBlue3'],
			\ ['darkcyan',    'SeaGreen3'],
			\ ['darkred',     'DarkOrchid3'],
			\ ['red',         'firebrick3'],
			\ ]
let g:rbpt_max = 16
let g:rbpt_loadcmd_toggle = 1

" Must execute 'export TERM=xterm-256color' first
colorscheme molokai
let g:molokai_original = 1
let g:rehash256 = 1
syntax enable
set regexpengine=1

" Key map
noremap <C-c> <ESC>
noremap q :q<CR>
noremap <Leader>sw :w !sudo tee %<CR>

" Tab
map <C-n> :execute 'tabnew' Prompt('New tab name: ')<CR>
map <S-h> :tabprevious<CR>
map <S-l> :tabnext<CR>
map <Leader><S-h> :tabfirst<CR>
map <Leader><S-l> :tablast<CR>

" Split
map <C-j> <C-w>j
map <C-k> <C-w>k
map <C-h> <C-w>h
map <C-l> <C-w>l
map <Leader>s :execute 'split' Prompt('New buffer name: ')<CR>
map <Leader>v :execute 'vsplit' Prompt('New buffer name: ')<CR>

map <F2> :NERDTreeTabsToggle<CR>
map <F3> :TagbarToggle<CR>
map <F4> :GundoToggle<CR>
map <F5> :set invpaste paste?<CR>
map <F6> :Dispatch<CR>
map <F7> :Dispatch!<CR>
map <F8> :InstantMarkdownPreview<CR>
map <F9> :RainbowParenthesesToggle<CR>

function! Strip(input_string)
	return substitute(a:input_string, '^\s*\(.\{-}\)\s*$', '\1', '')
endfunction

function! Prompt(promptText)
	call inputsave()
	let value = input(a:promptText)
	call inputrestore()
	return Strip(value)
endfunction

if has("gui_running")
	fun! ToggleFullscreen()
		call system("wmctrl -ir " . v:windowid . " -b toggle,fullscreen")
	endf
	map <F11> :call ToggleFullscreen()<CR>
	" Fullscreen when gvim start up
	autocmd VimEnter * call ToggleFullscreen()

	" When the GUI starts, 't_vb' is reset to its default value. See :help visualbell
	autocmd GUIEnter * set vb t_vb=

	" Disable cursor flicker
	set gcr=a:block-blinkon0

	" Disable scroll bar
	set guioptions-=l
	set guioptions-=L
	set guioptions-=r
	set guioptions-=R

	" Disable menu and tool bar
	set guioptions-=m
	set guioptions-=T

	" Set gui font
	set guifont=Monospace\ 9
else
	" Check file changes outside vim when in xterm
	autocmd CursorHold,CursorHoldI,WinEnter,BufEnter * if getcmdtype() == '' | checktime | endif
endif

" confirm
" wholeword
" replace
function! Replace(confirm, wholeword, replace)
	wa
	let flag = ''
	if a:confirm
		let flag .= 'gec'
	else
		let flag .= 'ge'
	endif
	let search = ''
	if a:wholeword
		let search .= '\<' . escape(expand('<cword>'), '/\.*$^~[') . '\>'
	else
		let search .= expand('<cword>')
	endif
	let replace = escape(a:replace, '/\&~')
	execute 'argdo %s/' . search . '/' . replace . '/' . flag . '| update'
endfunction

" No hightlight search
nnoremap <Leader>nhl :nohlsearch<CR>
" default
nnoremap <Leader>R :call Replace(0, 0, input('Replace '.expand('<cword>').' with: '))<CR>
" wholeword
nnoremap <Leader>rw :call Replace(0, 1, input('Replace '.expand('<cword>').' with: '))<CR>
" confirm
nnoremap <Leader>rc :call Replace(1, 0, input('Replace '.expand('<cword>').' with: '))<CR>
" wholeword, confirm
nnoremap <Leader>rwc :call Replace(1, 1, input('Replace '.expand('<cword>').' with: '))<CR>

" Save session options
set sessionoptions="blank,buffers,globals,localoptions,tabpages,sesdir,folds,help,options,resize,winpos,winsize"

" vim-session
let g:session_lock_enabled = 1
let g:session_autosave = 'yes'
let g:session_autoload = 'yes'
let g:session_default_name = 'session'

" Backup
map <Leader>ss :execute 'SaveSession' Prompt('Session name: ')<CR>
" Restore
map <Leader>rs :execute 'OpenSession' Prompt('Session name: ')<CR>

" Auto set tag file path, when vim start
autocmd BufNewFile,BufReadPre,FileReadPre * execute 'setlocal tags=' . (!empty(FindRootDirectory()) ? FindRootDirectory() . '/' : './') . '.tags,' . &tags

" Highlight .tags file as tags file
autocmd BufNewFile,BufRead *.tags set filetype=tags

" Set NERDTree window width
let NERDTreeWinSize = 32
" Don't open NERDTreeTabs automatically when vim starts up
let g:nerdtree_tabs_open_on_gui_startup = 0
" let g:nerdtree_tabs_open_on_console_startup = 1

" Open NERDTreeTabs automatically when vim starts up if no files were specified
" autocmd StdinReadPre * let s:std_in = 1
" autocmd VimEnter * if argc() == 0 && !exists('s:std_in') | execute ':NERDTreeTabsOpen' | endif

" Close vim if the only window left open is a NERDTree
autocmd BufEnter * if (winnr('$') == 1 && exists('b:NERDTree') && b:NERDTree.isTabTree()) | q | endif

" Auto refresh NERDTree
autocmd CursorHold,CursorHoldI * call ReRender()

function! ReRender()
	if !g:NERDTree.IsOpen()
		return
	endif

	let winnr = winnr()
	set switchbuf+=useopen
	sbuf NERD*

	call b:NERDTree.root.refresh()
	call NERDTreeRender()

	" Jump back
	execute winnr . "wincmd w"
	"redraw
endfunction

" Execute Autoformat onsave
autocmd BufWrite * :Autoformat

" Enable autoindent
let g:autoformat_autoindent = 1

" Tagbar width
let tagbar_width = 32

" vim-startify
function! s:filter_header(lines) abort
	let longest_line   = max(map(copy(a:lines), 'len(v:val)'))
	let centered_lines = map(copy(a:lines),
				\ 'repeat(" ", (&columns / 2) - (longest_line / 2)) . v:val')
	return centered_lines
endfunction

let g:startify_custom_header = s:filter_header(split(system('fortune | cowsay'), '\n'))
let g:startify_bookmarks = ['~/.vimrc', '~/.bashrc']

" YouCompleteMe
if !empty(glob('~/.vim/bundle/YouCompleteMe/third_party/ycmd/cpp/ycm/.ycm_extra_conf.py'))
	let g:ycm_global_ycm_extra_conf = '~/.vim/bundle/YouCompleteMe/third_party/ycmd/cpp/ycm/.ycm_extra_conf.py'
endif

" Support Java and Ruby
let g:EclimCompletionMethod = 'omnifunc'

" Do not use syntastic to check C, C++ and Objective-C, do it by syntastic
let g:ycm_show_diagnostics_ui = 0
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
nnoremap <Leader>jd :YcmCompleter GoToDefinitionElseDeclaration<CR>
nnoremap <Leader>dc :YcmCompleter GoToDeclaration<CR>
nnoremap <Leader>ji :YcmCompleter GoToInclude<CR>
nnoremap <Leader>jim :YcmCompleter GoToImprecise<CR>

" vim-autoformat
" Generic C, C++, Objective-C style
let g:formatdef_clangformat = "'clang-format -style=\"{BasedOnStyle: LLVM, IndentWidth: 8, UseTab: Always, Language: Cpp, BreakBeforeBraces: Allman, AllowShortBlocksOnASingleLine: false, AllowShortFunctionsOnASingleLine: false, AllowShortIfStatementsOnASingleLine: false, AllowShortLoopsOnASingleLine: false, IndentCaseLabels: false, DerivePointerAlignment: false, MaxEmptyLinesToKeep: 1, ColumnLimit: 0, PointerAlignment: Left}\"'"

" Golang
let g:formatdef_goimports = '"goimports"'
let g:formatters_go = ['goimports']

" Java
let g:formatdef_astyle_java = '"astyle --mode=java --style=java -pH".(&expandtab ? "s".shiftwidth() : "t")'

" vim-go settings
let g:go_highlight_functions = 1
let g:go_highlight_methods = 1
let g:go_highlight_structs = 1
let g:go_highlight_build_constraints = 1
let g:go_fmt_fail_silently = 1
let g:go_disable_autoinstall = 1
" Disable run GoFmt on save, do it by vim-autoformat
let g:go_fmt_autosave = 0
let g:go_fmt_command = "goimports"
let g:godef_split = 2
let g:godef_same_file_in_same_window = 1

" Use Ctrl-o to jump back, see :help jumplist
nnoremap <Leader>gd :GoDef<CR>
nnoremap <Leader>gi :GoImports<CR>
nnoremap <Leader>gt :GoTest<CR>
nnoremap <Leader>gf :GoTestFunc<CR>
nnoremap <Leader>gl :GoLint<CR>
nnoremap <Leader>gv :GoVet<CR>

" vim-markdown
let g:vim_markdown_folding_disabled = 1

" vim-instant_markdown
let g:instant_markdown_slow = 1
let g:instant_markdown_autostart = 0

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

let g:easytags_opts = ['--c++-kinds=+p+l+x+c+d+e+f+g+m+n+s+t+u+v ', '--fields=+liaS', '--extra=+q']
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
let g:syntastic_error_symbol = "\xe2\x9c\x97"
let g:syntastic_style_error_symbol = "\xe2\x9c\x97"
let g:syntastic_warning_symbol = "\xef\xbc\x81"
let g:syntastic_style_warning_symbol = "\xef\xbc\x81"
let g:syntastic_always_populate_loc_list = 0
let g:syntastic_auto_loc_list = 2
let g:syntastic_check_on_open = 1
let g:syntastic_check_on_wq = 0
let g:syntastic_enable_highlighting = 1
let g:syntastic_go_checkers = ['go', 'golint', 'govet', 'errcheck']

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
let g:UltiSnipsExpandTrigger="<Leader><tab>"

" vim-EasyMotion
let g:EasyMotion_smartcase = 1

map <Leader><Leader>h <Plug>(easymotion-linebackward)
map <Leader><Leader>j <Plug>(easymotion-j)
map <Leader><Leader>k <Plug>(easymotion-k)
map <Leader><Leader>l <Plug>(easymotion-lineforward)
map <Leader><Leader>w <Plug>(easymotion-w)
map <Leader><Leader>b <Plug>(easymotion-b)
map <Leader><Leader>s <Plug>(easymotion-sn)
