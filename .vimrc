" Add below code to ~/.bashrc
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
"	vim -R -c "Ref man $*" ~/.vimrc \
"		-c "if line('$') == 1 | cquit | endif" \
"		-c "silent only" \
"		-c "setlocal nomodifiable" \
"		-c "execute 'bdelete ' . bufnr('~/.vimrc')"
"	if [ "$?" != "0" ]; then
"		echo "No manual entry for $*"
"	fi
"}
"
"dirdiff() {
"	if [ $# -ne 2 ]; then
"		echo "Invalid arguments, please pass two arguments"
"		return
"	fi
"
"	vim -c "DirDiff $*" ~/.vimrc \
"		-c "execute 'bdelete ' . bufnr('~/.vimrc')"
"}

" Install vim-plug if not present
if empty(glob($HOME . '/.vim/autoload/plug.vim'))
	silent !curl -fLo ~/.vim/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
	autocmd VimEnter * PlugInstall | source $MYVIMRC
endif

set nocompatible
filetype off

call plug#begin($HOME . '/.vim/bundle')

" Plug
Plug 'scrooloose/nerdtree' | Plug 'jistr/vim-nerdtree-tabs'
Plug 'majutsushi/tagbar'
Plug 'sjl/gundo.vim'
Plug 'vim-airline/vim-airline' | Plug 'vim-airline/vim-airline-themes'
Plug 'ryanoasis/vim-devicons'
Plug 'ctrlpvim/ctrlp.vim'
Plug 'vim-ctrlspace/vim-ctrlspace'
"Plug 'moll/vim-bbye'
Plug 'chrismccord/bclose.vim'
Plug 'terryma/vim-multiple-cursors'
Plug 'terryma/vim-expand-region'
Plug 'easymotion/vim-easymotion'
Plug 'haya14busa/incsearch.vim'
Plug 'mileszs/ack.vim'
Plug 'scrooloose/nerdcommenter'
Plug 'mhinz/vim-startify'
Plug 'Chiel92/vim-autoformat'
Plug 'junegunn/vim-easy-align'
Plug 'Yggdroot/indentLine'
Plug 'ntpeters/vim-better-whitespace'
Plug 'wesQ3/vim-windowswap'
Plug 'tpope/vim-dispatch'
Plug 'airblade/vim-rooter'
Plug 'xolox/vim-misc' | Plug 'xolox/vim-easytags'
Plug 'scrooloose/syntastic'
Plug 'Valloric/YouCompleteMe', { 'do': './install.py --clang-completer --system-libclang --gocode-completer --tern-completer' } | Plug 'rdnetto/YCM-Generator', {'branch': 'stable'}
Plug 'SirVer/ultisnips' | Plug 'honza/vim-snippets'
Plug 'tpope/vim-surround'
Plug 'tpope/vim-repeat'
Plug 'Raimondi/delimitMate'
Plug 'vim-scripts/matchit.zip'
Plug 'tpope/vim-endwise'
Plug 'docunext/closetag.vim'
Plug 'thinca/vim-ref'
Plug 'fatih/vim-go', {'for': 'go'}
Plug 'othree/yajs.vim', {'for': 'javascript'} | Plug 'pangloss/vim-javascript'
Plug 'othree/javascript-libraries-syntax.vim', {'for': 'javascript'}
Plug 'elzr/vim-json', {'for': 'json'}
Plug 'vim-ruby/vim-ruby', {'for': 'ruby'}
Plug 'tpope/vim-rails', {'for': 'ruby'}
Plug 'yuku-t/vim-ref-ri', {'for': 'ruby'}
Plug 'soh335/vim-ref-pman', {'for': 'php'}
Plug 'mattn/emmet-vim', {'for': ['html', 'css']}
Plug 'gorodinskiy/vim-coloresque', {'for': 'css'}
Plug 'godlygeek/tabular', {'for': 'markdown'} | Plug 'plasticboy/vim-markdown'
Plug 'suan/vim-instant-markdown', {'for': 'markdown'}
Plug 'sheerun/vim-polyglot'
Plug 'kshenoy/vim-signature'
Plug 'tpope/vim-fugitive' | Plug 'gregsexton/gitv'
Plug 'airblade/vim-gitgutter'
Plug 'mattn/webapi-vim' | Plug 'mattn/gist-vim'
Plug 'Valloric/ListToggle'
Plug 'will133/vim-dirdiff'
Plug 'tpope/vim-unimpaired'
Plug 'tomasr/molokai'
Plug 'kien/rainbow_parentheses.vim'
Plug 'kana/vim-textobj-user'
Plug 'kana/vim-textobj-line'
Plug 'kana/vim-textobj-entire'
Plug 'kana/vim-textobj-indent'

if has('mac') || has('macunix')
	Plug 'rizzatti/dash.vim'
else
	Plug 'KabbAmine/zeavim.vim'
endif

" Add plugins to &runtimepath
call plug#end()

filetype plugin indent on

set number
" Show the cursor position all the time
set ruler

set showmatch

" Highlight current line
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

" For regular expressions turn magic on, and you don't need to add '\' before
" some special meaning characters.
set magic

" Share clipboard with system (gvim -v in xterm)
set clipboard=unnamedplus

set smartindent
" Indent at the same level of the previous line
set autoindent

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
let g:indentLine_char = '┊'
let g:indentLine_leadingSpaceEnabled = 1
let g:indentLine_leadingSpaceChar = '·'

" Restore cursor to previous editing position
autocmd BufReadPost * if line("'\"") > 1 && line("'\"") <= line("$") | exe "normal! g'\"" | endif

" Unrecognized filetype set to text
autocmd BufNewFile,BufRead * if empty(&filetype) | setfiletype text | endif
" Markdown file extensions
autocmd BufNewFile,BufRead *.{md,mdown,mkd,mkdn,markdown,mdwn} set filetype=markdown

autocmd FileType ref-man,ref-pydoc,ref-pman,help,godoc set nolist
autocmd FileType python,markdown setlocal expandtab tabstop=4 shiftwidth=4 softtabstop=4
autocmd FileType javascript,ruby,html,css,liquid,xml setlocal expandtab tabstop=2 shiftwidth=2 softtabstop=2

" Disable conceal in insert-mode
autocmd FileType markdown,json autocmd InsertEnter <buffer> setlocal conceallevel=2 concealcursor=
autocmd FileType markdown,json autocmd InsertLeave <buffer> setlocal conceallevel=2 concealcursor=nc

let format_filetypes = ['c', 'cpp', 'go', 'java', 'javascript', 'python', 'lua', 'ruby', 'sh', 'vim']
autocmd FileType * if index(format_filetypes, &filetype) < 0 | setlocal equalprg=cat | endif

autocmd BufNewFile *.sh,*.py call AutoInsertFileHead()
function! AutoInsertFileHead()
	" Shell
	if &filetype == 'sh'
		call setline(1, '#!/bin/sh')
	endif

	" Python
	if &filetype == 'python'
		call setline(1, '#!/usr/bin/env python')
		call append(1, '# -*- coding: utf-8 -*-')
	endif

	normal G
	normal o
	normal o
endfunc

function! GetCurrentWord()
	return expand('<cword>')
endfunction

autocmd FileType * call SetReferences()
function! SetReferences()
	let filetype_references = {
				\	'c': 'Ref man',
				\	'cpp': 'Ref man',
				\	'sh': 'Ref man',
				\	'go': 'GoDoc',
				\	'python': 'Ref pydoc',
				\	'ruby': 'Ref ri',
				\	'php': 'Ref pman',
				\	'vim': 'help',
				\ }

	let is_reference_set = 0
	for [ftype, reference] in items(filetype_references)
		if &filetype != ftype
			continue
		endif

		" vim-go have do it for you
		if ftype != 'go'
			let search = expand('<cword>')
			execute 'nnoremap <buffer><silent><S-k> :execute "' . reference . '" GetCurrentWord()<CR>'
		endif

		" Enable reference in visual-mode
		execute 'vnoremap <buffer><silent><S-k> <ESC>:execute "' . reference . '" GetVisualSelection()<CR>'

		let is_reference_set = 1
	endfor

	if !is_reference_set
		" Default reference: dash or zeal
		if has('mac') || has('macunix')
			nnoremap <buffer><silent><S-k> :execute 'Dash' GetCurrentWord()<CR>
			vnoremap <buffer><silent><S-k> <ESC>:execute 'Dash' GetVisualSelection()<CR>
		else
			nnoremap <buffer><silent><S-k> :Zeavim<CR>
			vnoremap <buffer><silent><S-k> <ESC>:ZvV<CR>
		endif
	endif
endfunction

" Inspired by https://github.com/idanarye/vim-vebugger/blob/master/autoload/vebugger/util.vim#L2
function! GetVisualSelection()
	let [lnum1, col1] = getpos("'<")[1:2]
	let [lnum2, col2] = getpos("'>")[1:2]
	let lines = getline(lnum1, lnum2)
	let lines[-1] = lines[-1][: col2 - (&selection == 'inclusive' ? 1 : 2)]
	let lines[0] = lines[0][col1 - 1:]
	return join(lines, "\n")
endfunction

" zeavim.vim
let g:zv_disable_mapping = 1
" Add what you want to refer
let g:zv_file_types = {
			\	'cpp': 'c++,boost',
			\	'javascript': 'javascript,nodejs',
			\	'sql': 'mysql',
			\ }

if has('mac') || has('macunix')
	function! DashPrompt()
		let dash_command = 'Dash'

		let ftype = Prompt('Docset: ')
		if empty(ftype)
			let dash_command = 'Dash!'
		endif
		redraw!

		let prompt_text = 'Dash (' . ftype . ")\n" . 'Search for: '
		let key = Prompt(prompt_text)

		execute dash_command key ftype
	endfunction

	nmap <silent><Leader><Leader>z :call DashPrompt()<CR>
else
	nmap <silent><Leader><Leader>z <Plug>ZVKeyDocset
endif

" Resize splits when the window is resized
autocmd VimResized * execute "normal! \<C-w>="

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

" Allow switching away from a changed buffer without saving
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
let g:airline#extensions#tabline#show_buffers = 1
let g:airline#extensions#tabline#buffer_min_count = 0
let g:airline#extensions#tabline#show_tabs = 1
let g:airline#extensions#tabline#tab_min_count = 0
let g:airline#extensions#tabline#exclude_preview = 1
" Only show tab number
let g:airline#extensions#tabline#tab_nr_type = 1
let g:airline#extensions#tabline#show_tab_nr = 0
let g:airline#extensions#tabline#show_tab_type = 0
let g:airline#extensions#tabline#buffer_idx_mode = 1
let g:airline#extensions#tabline#fnamecollapse = 0
let g:airline#extensions#tabline#show_close_button = 0

let g:airline#extensions#ycm#enabled = 1
let g:airline#extensions#ycm#error_symbol = 'E:'
let g:airline#extensions#ycm#warning_symbol = 'W:'
let g:airline#extensions#syntastic#enabled = 1
let g:airline#extensions#tagbar#enabled = 1
let g:airline#extensions#ctrlspace#enabled = 1
let g:airline#extensions#windowswap#enabled = 1

let g:airline_powerline_fonts = 1
if !exists('g:airline_symbols')
	let g:airline_symbols = {}
endif

let g:airline_left_sep = ''
let g:airline_left_alt_sep = ''
let g:airline_right_sep = ''
let g:airline_right_alt_sep = ''
let g:airline_symbols.branch = ''
let g:airline_symbols.readonly = ''
let g:airline_symbols.linenr = ''

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
autocmd BufNewFile,BufRead * if index(rainbow_parentheses_filetypes, &filetype) >= 0 | execute 'RainbowParenthesesToggle' | endif

set t_Co=256
colorscheme molokai
let g:molokai_original = 1
let g:rehash256 = 1

" Enable syntax highlight
"syntax enable
syntax on

set regexpengine=1

" Key map
" Make Y behave like other capitals
noremap Y y$

" Improve up/down movement on wrapped lines
noremap j gj
noremap k gk

" Keep text selected after manual indentation
vnoremap < <gv
vnoremap > >gv

noremap ; :

" Remap U to <C-r> for easier redo
noremap U <C-r>

" Better comand-line editing
cnoremap <C-j> <t_kd>
cnoremap <C-k> <t_ku>
cnoremap <C-a> <Home>
cnoremap <C-e> <End>

" ESC map
noremap <C-c> <ESC>
inoremap <C-c> <ESC>

nnoremap <silent> q :q<CR>
"nnoremap <silent> bd :Bdelete<CR>
nnoremap <silent> bd :Bclose<CR>

" w!! to sudo & write a file
cnoremap w!! w !sudo tee > /dev/null %

" Tab
nnoremap <silent><C-t> :execute 'tabnew' Prompt('New tab name: ')<CR>
nnoremap <silent><S-h> :tabprevious<CR>
nnoremap <silent><S-l> :tabnext<CR>
nnoremap <Leader>1 1gt
nnoremap <Leader>2 2gt
nnoremap <Leader>3 3gt
nnoremap <Leader>4 4gt
nnoremap <Leader>5 5gt
nnoremap <Leader>6 6gt
nnoremap <Leader>7 7gt
nnoremap <Leader>8 8gt
nnoremap <Leader>9 9gt
nnoremap <silent><Leader>[ :tabfirst<CR>
nnoremap <silent><Leader>] :tablast<CR>

" Split
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-h> <C-w>h
nnoremap <C-l> <C-w>l
nnoremap <silent><Leader>s :execute 'split' Prompt('New buffer name: ')<CR>
nnoremap <silent><Leader>v :execute 'vsplit' Prompt('New buffer name: ')<CR>

nnoremap <C-up> <C-w>+
nnoremap <C-down> <C-w>-
nnoremap <C-left> <C-w>>
nnoremap <C-right> <C-w><

" Zoom/Restore window
function! ZoomToggle()
	if exists('t:zoomed') && t:zoomed
		execute t:zoom_winrestcmd
		let t:zoomed = 0
	else
		let t:zoom_winrestcmd = winrestcmd()
		resize
		vertical resize
		let t:zoomed = 1
	endif
endfunction
nnoremap <silent><Leader>z :call ZoomToggle()<CR>

" incsearch.vim
map /  <Plug>(incsearch-forward)
map ?  <Plug>(incsearch-backward)
map g/ <Plug>(incsearch-stay)

" Auto nohlsearch
let g:incsearch#auto_nohlsearch = 1
" Keep search pattern at the center of the screen.
map n  <Plug>(incsearch-nohl-n)zz
map N  <Plug>(incsearch-nohl-N)zz
map *  <Plug>(incsearch-nohl-#)zz
map #  <Plug>(incsearch-nohl-*)zz
map g* <Plug>(incsearch-nohl-g*)zz
map g# <Plug>(incsearch-nohl-g#)zz

" No highlight search
nnoremap <silent><Leader>/ :nohlsearch<CR>

nnoremap <silent><F2> :NERDTreeTabsToggle<CR>
nnoremap <silent><F3> :TagbarToggle<CR>
nnoremap <silent><F4> :GundoToggle<CR>
" Vim lets you toggle any option with
" :set inv{option}
nnoremap <silent><F5> :set invpaste paste?<CR>
nnoremap <silent><F6> :Dispatch<CR>
nnoremap <silent><F7> :Dispatch!<CR>
nnoremap <silent><F8> :call DispatchQListToggle()<CR>
nnoremap <silent><F9> :InstantMarkdownPreview<CR>
nnoremap <silent><F10> :RainbowParenthesesToggle<CR>

function! Strip(input_string)
	return substitute(a:input_string, '^\s*\(.\{-}\)\s*$', '\1', '')
endfunction

function! Prompt(prompt_text)
	call inputsave()
	let value = input(a:prompt_text)
	call inputrestore()
	return Strip(value)
endfunction

function! DispatchQListToggle()
	let buffer_count_before = BufferCount()
	silent! cclose

	if BufferCount() == buffer_count_before
		Copen!
	endif
endfunction

function! BufferCount()
	return len(filter(range(1, bufnr('$')), 'buflisted(v:val)'))
endfunction

if has('gui_running')
	function! ToggleFullscreen()
		call system('wmctrl -ir ' . v:windowid . ' -b toggle,fullscreen')
	endfunction

	nnoremap <silent><F11> :call ToggleFullscreen()<CR>
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

" Replace
function! Replace(mode, confirm, wholeword)
	let word = ''
	let wholeword = a:wholeword
	if a:mode == 'n' || a:mode == 'normal'
		let word .= expand('<cword>')
	elseif a:mode == 'v' || a:mode == 'visual'
		let word .= GetVisualSelection()
		let wholeword = 0
	endif

	let search = ''
	if wholeword
		let search .= '\<' . escape(word, '/\.*$^~[') . '\>'
	else
		let search .= escape(word, '/\.*$^~[')
	endif


	let replace = Prompt('Replace "' . word . '" with: ')
	let replace = escape(replace, '/\&~')

	let flag = ''
	if a:confirm
		let flag .= 'gec'
	else
		let flag .= 'ge'
	endif

	execute '%s/' . search . '/' . replace . '/' . flag . '| update'
endfunction

" Replace in normal mode
" Default
nnoremap <Leader>R :call Replace('n', 0, 0)<CR>
" Wholeword
nnoremap <Leader>rw :call Replace('n', 0, 1)<CR>
" Confirm
nnoremap <Leader>rc :call Replace('n', 1, 0)<CR>
" Wholeword, confirm
nnoremap <Leader>rwc :call Replace('n', 1, 1)<CR>

" Replace in visual mode
" Default
vnoremap <Leader>R :call Replace('v', 0, 0)<CR>
" Confirm
vnoremap <Leader>rc :call Replace('v', 1, 0)<CR>

" Save session options
set sessionoptions="blank,buffers,folds,globals,help,localoptions,options,resize,sesdir,tabpages,winpos,winsize"

" Backup
nnoremap <Leader>ss :execute 'CtrlSpaceSaveWorkspace' Prompt('Session name: ')<CR>
" Restore
nnoremap <Leader>rs :execute 'CtrlSpaceLoadWorkspace' Prompt('Session name: ')<CR>

" Auto set tag file path
autocmd BufNewFile,BufRead * execute 'setlocal tags=' . (!empty(FindRootDirectory()) ? FindRootDirectory() . '/' : './') . '.tags,' . &tags

" Highlight .tags file as tags file
autocmd BufNewFile,BufRead *.tags set filetype=tags

" Set NERDTree window width
let NERDTreeWinSize = 32

" Show hidden
let NERDTreeShowHidden = 1
" Ignore files
let NERDTreeIgnore=['\.o$', '\.obj$', '\.py[co]$', '\~$', '\.swo$', '\.swp$', '^\.git$', '^\.hg$', '^\.svn$', '\.bzr$']

" Don't open NERDTreeTabs automatically when vim starts up
let g:nerdtree_tabs_open_on_gui_startup = 0
let g:nerdtree_tabs_open_on_console_startup = 0

" Close vim if the only window left open is a NERDTreeTabs
let g:nerdtree_tabs_autoclose = 1

" Auto refresh NERDTree
autocmd CursorHold,CursorHoldI * call Refresh()

" Inspired by https://github.com/Xuyuanp/nerdtree-git-plugin
function! Refresh()
	if !exists('g:NERDTree') || !g:NERDTree.IsOpen()
		return
	endif

	let winnr = winnr()

	call g:NERDTree.CursorToTreeWin()
	call b:NERDTree.root.refresh()
	call b:NERDTree.root.refreshFlags()
	call NERDTreeRender()

	" Jump back
	execute winnr . 'wincmd w'
	"redraw
endfunction

" Execute Autoformat onsave
autocmd BufWrite * :Autoformat

" Disable autoindent, do it manually by gg=G
let g:autoformat_autoindent = 0

" vim-easy-align
" Start interactive EasyAlign in visual mode (e.g. vipga)
xmap ga <Plug>(EasyAlign)
" Start interactive EasyAlign for a motion/text object (e.g. gaip)
nmap ga <Plug>(EasyAlign)

" vim-better-whitespace
let g:better_whitespace_filetypes_blacklist = []

nnoremap <silent><Leader><Space> :StripWhitespace<CR>

" Tagbar width
let tagbar_width = 32

" Gitv
" Disable ctrl key map due to the conflict
let g:Gitv_DoNotMapCtrlKey = 1

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
nnoremap <silent>gd :YcmCompleter GoToDefinition<CR>
nnoremap <silent><Leader>jd :YcmCompleter GoToDeclaration<CR>
nnoremap <silent><Leader>ji :YcmCompleter GoToInclude<CR>

" vim-autoformat
" Generic C, C++, Objective-C style
" A style similar to the Linux Kernel style
let g:formatdef_clangformat = "'clang-format -style=\"{BasedOnStyle: LLVM, IndentWidth: 8, UseTab: Always, BreakBeforeBraces: Linux, AllowShortIfStatementsOnASingleLine: false, IndentCaseLabels: false}\"'"

" Golang
let g:formatdef_goimports = '"goimports"'

" vim-go settings
let g:go_highlight_functions = 1
let g:go_highlight_methods = 1
let g:go_highlight_structs = 1
let g:go_highlight_build_constraints = 1
let g:go_fmt_fail_silently = 1
let g:go_disable_autoinstall = 1
" Disable run GoFmt on save, do it by vim-autoformat
let g:go_fmt_autosave = 0
let g:go_fmt_command = 'goimports'
let g:godef_split = 2
let g:godef_same_file_in_same_window = 1

" Use Ctrl-o to jump back, see :help jumplist
autocmd FileType go nnoremap <silent><Leader>gi :GoImports<CR>
autocmd FileType go nnoremap <silent><Leader>gt :GoTest<CR>
autocmd FileType go nnoremap <silent><Leader>gf :GoTestFunc<CR>

" javascript-libraries-syntax.vim
let g:used_javascript_libs = 'jquery'

" vim-markdown
let g:vim_markdown_folding_disabled = 1

" vim-instant_markdown
let g:instant_markdown_slow = 1
let g:instant_markdown_autostart = 0

" CtrlP runtime path, vim-plug do it for you
"set runtimepath^=~/.vim/bundle/ctrlp.vim

" CtrlSpace
let g:CtrlSpaceLoadLastWorkspaceOnStart = 1
let g:CtrlSpaceSaveWorkspaceOnSwitch = 1
let g:CtrlSpaceSaveWorkspaceOnExit = 1
let g:CtrlSpaceStatuslineFunction = 'airline#extensions#ctrlspace#statusline()'

" ack.vim
if executable('ag')
	let g:ackprg = 'ag --hidden --nogroup --nocolor --column --smart-case'
elseif executable('ack') || executable('ack-grep')
	let g:ack_default_options = ' -s -H --nocolor --nogroup --column --smart-case'
endif

" vim-easytags
let g:easytags_async = 1

" Disable recurse, do it manually by :UpdateTags -R
" let g:easytags_autorecurse = 1

" Global tag file
let g:easytags_file = $HOME . '/.vim/.tags'

let g:easytags_opts = ['--fields=+liaS', '--extra=+q']
let g:easytags_languages = {
			\	'c': {
			\		'args': ['--c-kinds=+p+l+x+c+d+e+f+g+m+n+s+t+u+v']
			\	},
			\	'cpp': {
			\		'args': ['--c++-kinds=+p+l+x+c+d+e+f+g+m+n+s+t+u+v']
			\	}
			\ }
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
let g:syntastic_error_symbol = '✖'
let g:syntastic_style_error_symbol = '✖'
let g:syntastic_warning_symbol = '!'
let g:syntastic_style_warning_symbol = '!'
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
nnoremap <silent><Leader>e :call ToggleErrors()<CR>

" Emmet
" Enable all function in all mode.
let g:user_emmet_mode = 'a'

" Ultisnips
let g:UltiSnipsExpandTrigger='<Leader><tab>'

" vim-EasyMotion
let g:EasyMotion_smartcase = 1
