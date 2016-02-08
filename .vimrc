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
"	vim -R -c "Man $*" ~/.vimrc -c "if line('$') == 1 | cquit | endif" -c "silent only" -c "setlocal nomodifiable"
"	if [ "$?" != "0" ]; then
"		echo "No manual entry for $*"
"	fi
"}

let need_setup = 0
let vundle = $HOME . '/.vim/bundle/Vundle.vim'
if exists('*mkdir') && !isdirectory(vundle)
	echo "Installing Vundle..."
	echo ""
	call mkdir($HOME . '/.vim/bundle', 'p')
	execute 'silent !git clone https://github.com/VundleVim/Vundle.vim ' . vundle
	let need_setup = 1
endif

set nocompatible
filetype off

" Set the runtime path to include Vundle and initialize
set rtp+=~/.vim/bundle/Vundle.vim
call vundle#begin()
" alternatively, pass a path where Vundle should install plugins
"call vundle#begin('~/some/path/here')

" Let Vundle manage Vundle, required
Plugin 'VundleVim/Vundle.vim'

" Plugin
Plugin 'scrooloose/nerdtree'
Plugin 'jistr/vim-nerdtree-tabs'
Plugin 'majutsushi/tagbar'
Plugin 'sjl/gundo.vim'
Plugin 'vim-airline/vim-airline'
Plugin 'vim-airline/vim-airline-themes'
Plugin 'ryanoasis/vim-devicons'
Plugin 'ctrlpvim/ctrlp.vim'
Plugin 'vim-ctrlspace/vim-ctrlspace'
Plugin 'terryma/vim-multiple-cursors'
Plugin 'easymotion/vim-easymotion'
Plugin 'mileszs/ack.vim'
Plugin 'scrooloose/nerdcommenter'
Plugin 'mhinz/vim-startify'
Plugin 'Chiel92/vim-autoformat'
Plugin 'Yggdroot/indentLine'
Plugin 'ntpeters/vim-better-whitespace'
Plugin 'wesQ3/vim-windowswap'
Plugin 'tpope/vim-dispatch'
Plugin 'airblade/vim-rooter'
Plugin 'xolox/vim-misc'
Plugin 'xolox/vim-easytags'
Plugin 'scrooloose/syntastic'
Plugin 'Valloric/YouCompleteMe'
Plugin 'SirVer/ultisnips'
Plugin 'honza/vim-snippets'
Plugin 'tpope/vim-surround'
Plugin 'Raimondi/delimitMate'
Plugin 'tpope/vim-endwise'
Plugin 'tpope/vim-ragtag'
Plugin 'docunext/closetag.vim'
Plugin 'fatih/vim-go'
Plugin 'pangloss/vim-javascript'
Plugin 'mattn/emmet-vim'
Plugin 'godlygeek/tabular'
Plugin 'plasticboy/vim-markdown'
Plugin 'suan/vim-instant-markdown'
Plugin 'sheerun/vim-polyglot'
Plugin 'tpope/vim-fugitive'
Plugin 'gregsexton/gitv'
Plugin 'airblade/vim-gitgutter'
Plugin 'tpope/vim-unimpaired'
Plugin 'tomasr/molokai'
Plugin 'kien/rainbow_parentheses.vim'

if need_setup == 1
	echo "Installing Vundles, please ignore key map error messages."
	echo ""
	execute "PluginInstall"
endif

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
" Show the cursor position all the time
set ruler

set showmatch

" Hightlight current line
set cursorline

" Search in time
set incsearch
set hlsearch
set ignorecase
set smartcase
" By default add g flag to search/replace.
set gdefault

set wildmenu
set wildmode=list:longest,full

" For regular expressions turn magic on
set magic

" Share clipboard with system (gvim -v in xterm)
set clipboard=unnamedplus

set autoindent
set smartindent

" Make "tab" insert indents instead of tabs at the beginning of a line
set smarttab
" Size of a hard tabstop
set tabstop=8
set softtabstop=8
" Size of an "indent"
set shiftwidth=8
" Never use space to replace tab
set noexpandtab

" Show tab and eof
set list listchars=tab:▸\ ,eol:¬,trail:⋅

" indentLine
" Disable, or vim will be very slow for the file which has long line
let g:indentLine_enabled = 0
let g:indentLine_char = "\xe2\x94\x8a"
let g:indentLine_leadingSpaceEnabled = 1
let g:indentLine_leadingSpaceChar = "\xc2\xb7"

" Unrecognized filetype set to text
autocmd BufNewFile,BufRead * if &filetype == "" | setfiletype text | endif
" Markdown file extensions
autocmd BufNewFile,BufRead *.{md,mdown,mkd,mkdn,markdown,mdwn} set filetype=markdown

autocmd FileType man set nolist
autocmd FileType html,css,liquid setlocal expandtab tabstop=2 shiftwidth=2 softtabstop=2
autocmd FileType python,markdown setlocal expandtab tabstop=4 shiftwidth=4 softtabstop=4
"autocmd FileType markdown setlocal expandtab tabstop=4 shiftwidth=4 softtabstop=4 equalprg=pandoc\ -f\ markdown_github\ -t\ markdown_github\ --atx-headers

let format_filetypes = ['c', 'cpp', 'go', 'java', 'javascript', 'python', 'ruby', 'sh', 'vim']
autocmd FileType * if index(format_filetypes, &filetype) < 0 | setlocal equalprg=cat | endif

" Resize splits when the window is resized
autocmd VimResized * exe "normal! \<c-w>="

" Number of lines from vertical edge to start scrolling
set scrolloff=7
" Number of cols from horizontal edge to start scrolling
set sidescrolloff=15
" Number of cols to scroll at a time
set sidescroll=1

" Enable undo file
set undofile
" Undo files
set undodir=$HOME/.vim/undo/

" Create undo directory if directory not exists
if exists('*mkdir') && !isdirectory($HOME . "/.vim/undo")
	call mkdir($HOME . '/.vim/undo', 'p')
endif

" Disable fold on start up
set nofoldenable
set foldmethod=syntax
set foldlevel=99

language message en_US.UTF-8
set langmenu=en_US.UTF-8

" Character width. Should never be enable!
"set ambiwidth=double

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
let g:airline#extensions#tabline#enabled = 1
let g:airline#extensions#tabline#show_buffers = 0
let g:airline#extensions#tabline#show_tabs = 1
let g:airline#extensions#tabline#tab_min_count = 2
" Only show tab number
let g:airline#extensions#tabline#tab_nr_type = 1
let g:airline#extensions#tabline#show_tab_nr = 1
let g:airline#extensions#tabline#show_tab_type = 0
let g:airline#extensions#tabline#buffer_idx_mode = 1
let g:airline#extensions#tabline#fnamecollapse = 0
let g:airline#extensions#tabline#show_close_button = 0

let g:airline#extensions#ycm#enabled = 1
let g:airline#extensions#ycm#error_symbol = 'E:'
let g:airline#extensions#ycm#warning_symbol = 'W:'
let g:airline#extensions#syntastic#enabled = 1
let g:airline#extensions#tagbar#enabled = 1
let g:airline#extensions#windowswap#enabled = 1
if !exists('g:airline_symbols')
	let g:airline_symbols = {}
endif

let g:airline_left_sep = "\xee\x82\xb0"
let g:airline_left_alt_sep = "\xee\x82\xb1"
let g:airline_right_sep = "\xee\x82\xb2"
let g:airline_right_alt_sep = "\xee\x82\xb3"
let g:airline_symbols.branch = "\ue0a0"
let g:airline_symbols.readonly = "\ue0a2"
let g:airline_symbols.linenr = "\xee\x82\xa1"

nmap <leader>1 <Plug>AirlineSelectTab1
nmap <leader>2 <Plug>AirlineSelectTab2
nmap <leader>3 <Plug>AirlineSelectTab3
nmap <leader>4 <Plug>AirlineSelectTab4
nmap <leader>5 <Plug>AirlineSelectTab5
nmap <leader>6 <Plug>AirlineSelectTab6
nmap <leader>7 <Plug>AirlineSelectTab7
nmap <leader>8 <Plug>AirlineSelectTab8
nmap <leader>9 <Plug>AirlineSelectTab9
nmap <leader>- <Plug>AirlineSelectPrevTab
nmap <leader>+ <Plug>AirlineSelectNextTab

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

let rainbow_parentheses_filetypes = ['lisp', 'clojure', 'scheme']
autocmd BufNewFile,BufRead * if index(rainbow_parentheses_filetypes, &filetype) >=0 | execute 'RainbowParenthesesToggle' | endif

" Must execute 'export TERM=xterm-256color' first
colorscheme molokai
let g:molokai_original = 1
let g:rehash256 = 1
syntax enable
set regexpengine=1

" Key map
" Make Y behave like other capitals
map Y y$

" Improve up/down movement on wrapped lines
nnoremap j gj
nnoremap k gk

nnoremap ; :

" Remap U to <C-r> for easier redo
nnoremap U <C-r>

" Keep search pattern at the center of the screen.
nnoremap <silent> n nzz
nnoremap <silent> N Nzz
nnoremap <silent> * *zz
nnoremap <silent> # #zz
nnoremap <silent> g* g*zz
nnoremap <silent> g# g#zz

" Better comand-line editing
cnoremap <C-j> <t_kd>
cnoremap <C-k> <t_ku>
cnoremap <C-a> <Home>
cnoremap <C-e> <End>

" ESC map
map <C-c> <ESC>

noremap q :q<CR>
noremap bd :MBEbd<CR>

noremap <Leader>sw :w !sudo tee > /dev/null %<CR>

" Tab
map <C-t> :execute 'tabnew' Prompt('New tab name: ')<CR>
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

noremap <c-up> <c-w>+
noremap <c-down> <c-w>-
noremap <c-left> <c-w>>
noremap <c-right> <c-w><

map <F2> :NERDTreeTabsToggle<CR>
map <F3> :TagbarToggle<CR>
map <F4> :GundoToggle<CR>
" Vim lets you toggle any option with
" :set inv{option}
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
	set guicursor=a:block-blinkon0

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
nnoremap <Leader>/ :nohlsearch<CR>
" default
nnoremap <Leader>R :call Replace(0, 0, input('Replace '.expand('<cword>').' with: '))<CR>
" wholeword
nnoremap <Leader>rw :call Replace(0, 1, input('Replace '.expand('<cword>').' with: '))<CR>
" confirm
nnoremap <Leader>rc :call Replace(1, 0, input('Replace '.expand('<cword>').' with: '))<CR>
" wholeword, confirm
nnoremap <Leader>rwc :call Replace(1, 1, input('Replace '.expand('<cword>').' with: '))<CR>

" Save session options
set sessionoptions="blank,buffers,folds,globals,help,localoptions,options,resize,sesdir,tabpages,winpos,winsize"

" Backup
map <Leader>ss :execute 'CtrlSpaceSaveWorkspace' Prompt('Session name: ')<CR>
" Restore
map <Leader>rs :execute 'CtrlSpaceLoadWorkspace' Prompt('Session name: ')<CR>

" Auto set tag file path
autocmd BufNewFile,BufRead * execute 'setlocal tags=' . (!empty(FindRootDirectory()) ? FindRootDirectory() . '/' : './') . '.tags,' . &tags

" Highlight .tags file as tags file
autocmd BufNewFile,BufRead *.tags set filetype=tags

" Set NERDTree window width
let NERDTreeWinSize = 32
" Don't open NERDTreeTabs automatically when vim starts up
let g:nerdtree_tabs_open_on_gui_startup = 0
let g:nerdtree_tabs_open_on_console_startup = 0

" Open NERDTreeTabs automatically when vim starts up if no files were specified
"autocmd StdinReadPre * let s:std_in = 1
"autocmd VimEnter * if argc() == 0 && !exists('s:std_in') | execute ':NERDTreeTabsOpen' | endif

" Close vim if the only window left open is a NERDTreeTabs
let g:nerdtree_tabs_autoclose = 1

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

" vim-better-whitespace
let g:better_whitespace_filetypes_blacklist = []

map <Leader><Space> :StripWhitespace<CR>

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
" A style similar to the Linux Kernel style
let g:formatdef_clangformat = "'clang-format -style=\"{BasedOnStyle: LLVM, IndentWidth: 8, UseTab: Always, BreakBeforeBraces: Linux, AllowShortIfStatementsOnASingleLine: false, IndentCaseLabels: false}\"'"

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

" CtrlSpace
let g:CtrlSpaceLoadLastWorkspaceOnStart = 1
let g:CtrlSpaceSaveWorkspaceOnSwitch = 1
let g:CtrlSpaceSaveWorkspaceOnExit = 1

" vim-easytags
let g:easytags_async = 1

" Disable recurse, do it manually by :UpdateTags -R
" let g:easytags_autorecurse = 1

" Global tag file
let g:easytags_file = $HOME . '/.vim/.tags'

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
let g:syntastic_loc_list_height = 10
let g:syntastic_error_symbol = "\xe2\x9c\x96"
let g:syntastic_style_error_symbol = "\xe2\x9c\x96"
let g:syntastic_warning_symbol = "!"
let g:syntastic_style_warning_symbol = "!"
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
