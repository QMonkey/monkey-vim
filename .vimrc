" Notes {
" vim: set nofoldenable foldmethod=marker foldmarker={,} foldlevel=0:
"
"                                _
"          _ __ ___   ___  _ __ | | _____ _   _     __   _(_)_ __ ___
"         | '_ ` _ \ / _ \| '_ \| |/ / _ \ | | |____\ \ / / | '_ ` _ \
"         | | | | | | (_) | | | |   <  __/ |_| |_____\ V /| | | | | | |
"         |_| |_| |_|\___/|_| |_|_|\_\___|\__, |      \_/ |_|_| |_| |_|
"                                         |___/
"
"     Author: Charles Qiu
"     Email: Thinking.QMonkey@GMail.com
" }

" Init {
" Install vim-plug if not present
if empty(glob($HOME . '/.vim/autoload/plug.vim'))
	silent !curl -fLo ~/.vim/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
	autocmd VimEnter * PlugInstall | source $MYVIMRC
endif
" }

set nocompatible
filetype off

call plug#begin($HOME . '/.vim/bundle')

" Plugins {
Plug 'tomasr/molokai'
Plug 'scrooloose/nerdtree' | Plug 'jistr/vim-nerdtree-tabs'
Plug 'majutsushi/tagbar'
Plug 'vim-airline/vim-airline' | Plug 'vim-airline/vim-airline-themes'
Plug 'ctrlpvim/ctrlp.vim'
Plug 'vim-ctrlspace/vim-ctrlspace'
Plug 'moll/vim-bbye'
Plug 'easymotion/vim-easymotion'
Plug 'wellle/targets.vim'
Plug 'svermeulen/vim-easyclip'
Plug 'haya14busa/incsearch.vim'
Plug 'mileszs/ack.vim'
Plug 'scrooloose/nerdcommenter'
Plug 'Chiel92/vim-autoformat'
Plug 'junegunn/vim-easy-align'
Plug 'ntpeters/vim-better-whitespace'
Plug 'tpope/vim-dispatch'
Plug 'airblade/vim-rooter'
Plug 'xolox/vim-misc' | Plug 'xolox/vim-easytags'
Plug 'scrooloose/syntastic'
Plug 'Valloric/YouCompleteMe', {'do': './install.py --clang-completer --gocode-completer --tern-completer'} | Plug 'rdnetto/YCM-Generator', {'branch': 'stable', 'for': ['c', 'cpp']}
Plug 'SirVer/ultisnips' | Plug 'honza/vim-snippets'
Plug 'tpope/vim-fugitive' | Plug 'gregsexton/gitv'
Plug 'airblade/vim-gitgutter'
Plug 'tpope/vim-surround'
Plug 'tpope/vim-repeat'
Plug 'tpope/vim-eunuch'
Plug 'Raimondi/delimitMate'
Plug 'kshenoy/vim-signature'
Plug 'Valloric/ListToggle'
Plug 'octol/vim-cpp-enhanced-highlight', {'for': ['c', 'cpp']}
Plug 'fatih/vim-go', {'for': 'go'}
Plug 'artur-shaik/vim-javacomplete2', {'for': 'java'}
Plug 'pangloss/vim-javascript', {'for': 'javascript'}
Plug 'elzr/vim-json', {'for': 'json'}
Plug 'hdima/python-syntax', {'for': 'python'}
Plug 'xolox/vim-lua-ftplugin', {'for': 'lua'}
Plug 'vim-ruby/vim-ruby', {'for': 'ruby'}
Plug 'tpope/vim-rails', {'for': 'ruby'}
Plug 'StanAngeloff/php.vim', {'for': 'php'}
Plug 'shawncplus/phpcomplete.vim', {'for': 'php'}
Plug 'tpope/vim-markdown', {'for': 'markdown'}
Plug 'suan/vim-instant-markdown', {'for': 'markdown'}
Plug 'cespare/vim-toml', {'for': 'toml'}
Plug 'moskytw/nginx-contrib-vim', {'for': 'nginx'}

if has('mac') || has('macunix')
	Plug 'rizzatti/dash.vim'
else
	Plug 'KabbAmine/zeavim.vim'
endif
" }

" Add plugins to &runtimepath
call plug#end()

filetype plugin indent on

" Leader {
let mapleader = ','
" }

" Number {
set relativenumber number

" Only work for the GUI version and a few console versions
autocmd FocusLost * :set norelativenumber number
autocmd FocusGained * :set relativenumber

" Use absolute line number in insert mode
autocmd InsertEnter * :set norelativenumber number
autocmd InsertLeave * :set relativenumber
" }

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

" The ":substitute" flag 'g' is default on. This means that
" all matches in a line are substituted instead of one. When a 'g' flag
" is given to a ":substitute" command, this will toggle the substitution
" of all or one match
set gdefault

set wildmenu
set wildmode=list:longest,full

" Complete options (disable preview scratch window, longest removed to aways show menu)
set completeopt=menu,menuone

" For regular expressions turn magic on, and you don't need to add '\' before some special meaning characters.
set magic

" Share vim clipboard with system clipboard (gvim -v in xterm)
if has('unnamedplus')
	" When possible use + register for copy-paste
	set clipboard=unnamed,unnamedplus
else
	" On Mac and Windows, use * register for copy-paste
	set clipboard=unnamed
endif

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

" Restore cursor to previous editing position
autocmd BufReadPost * if line("'\"") > 1 && line("'\"") <= line("$") | execute "normal! g'\"" | endif

" FileType {
autocmd FileType python,markdown setlocal expandtab tabstop=4 shiftwidth=4 softtabstop=4
autocmd FileType javascript,json,ruby setlocal expandtab tabstop=2 shiftwidth=2 softtabstop=2
autocmd FileType php set matchpairs-=<:>
" Wait to redraw
autocmd FileType go set lazyredraw

autocmd BufNewFile *.sh,*.py call AutoInsertFileHead()
function! AutoInsertFileHead()
	" Shell
	if &filetype ==# 'sh'
		call setline(1, '#!/bin/sh')
	endif

	" Python
	if &filetype ==# 'python'
		call setline(1, '#!/usr/bin/env python')
		call append(1, '# -*- coding: utf-8 -*-')
	endif

	normal G
	normal o
	normal o
endfunc
" }

" Docset {
autocmd FileType man,help set nolist

" Enable 'Man' command
source $VIMRUNTIME/ftplugin/man.vim

function! GetCurrentWord()
	return expand('<cword>')
endfunction

" Use man as docset for unrecognized filetype
autocmd BufNewFile,BufRead * if empty(&filetype) | call SetUnrecognizedFileTypeReferences() | endif
function! SetUnrecognizedFileTypeReferences()
	nnoremap <buffer><silent><S-k> :execute 'Man' GetCurrentWord()<CR>
	vnoremap <buffer><silent><S-k> <ESC>:execute 'Man' GetVisualSelection()<CR>
endfunction

autocmd FileType * call SetReferences()
function! SetReferences()
	let filetype_references = {
				\	'c': 'Man',
				\	'sh': 'Man',
				\	'vim': 'help',
				\ }

	let is_reference_set = 0
	for [ftype, reference] in items(filetype_references)
		if &filetype != ftype
			continue
		endif

		let search = expand('<cword>')
		execute 'nnoremap <buffer><silent><S-k> :execute "' . reference . '" GetCurrentWord()<CR>'

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
" }

" Inspired by http://stackoverflow.com/questions/1533565/how-to-get-visually-selected-text-in-vimscript
function! GetVisualSelection()
	let selected = ''
	try
		let a_save = @a
		normal! gv"ay
		let selected = @a
	finally
		let @a = a_save
	endtry
	return selected
endfunction

" zeavim.vim {
let g:zv_disable_mapping = 1

" Add what you want to refer
let g:zv_file_types = {
			\	'javascript': 'javascript,nodejs',
			\	'sql': 'mysql',
			\ }

if !has('mac') && !has('macunix')
	nmap <unique><Leader><Leader>z <Plug>ZVKeyDocset
endif
" }

" dash.vim {
if has('mac') || has('macunix')
	function! DashPrompt()
		let dash_command = 'Dash'

		let ftype = Prompt('Docset: ', &filetype)
		if empty(ftype)
			let dash_command = 'Dash!'
		endif
		redraw!

		let prompt_text = 'Dash (' . ftype . ")\n" . 'Search for: '
		let key = Prompt(prompt_text)

		execute dash_command key ftype
	endfunction

	nmap <silent><Leader><Leader>z :call DashPrompt()<CR>
endif
" }

" Resize splits when the window is resized
autocmd VimResized * execute "normal! \<C-w>="

" Number of lines from vertical edge to start scrolling
set scrolloff=7

" Number of cols from horizontal edge to start scrolling
set sidescrolloff=15

" Number of cols to scroll at a time
set sidescroll=1

" Disable fold on start up
set nofoldenable
set foldmethod=syntax
set foldlevel=99

" Use indent style fold for python
autocmd FileType python setlocal foldmethod=indent

language message en_US.UTF-8
set langmenu=en_US.UTF-8

" Character width. Should never be enable!
"set ambiwidth=double

scriptencoding utf-8
set encoding=utf-8
set fileencodings=utf-8,gb18030,cp936,ucs-bom,big5,euc-jp,euc-kr,latin1

" Only work in terminal vim
set termencoding=utf-8

" Use both Unix, DOS and Mac file formats, but favor the Unix one for new files
set fileformats=unix,dos,mac

" Configure backspace so it acts as it should act
set backspace=indent,eol,start

" Allow switching away from a changed buffer without saving
set hidden

" Auto reload file changes outside vim
set autoread

" No error bells
set noerrorbells
set novisualbell
set t_vb=

" Disable mouse
set mouse=

" Always show status line
set laststatus=2

" vim-airline {
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

" Use powerline fonts
let g:airline_powerline_fonts = 1
" }

" Enable 256 color for vim
set t_Co=256

" Inspired by http://sunaku.github.io/vim-256color-bce.html
if &term =~ '256color'
	" Disable Background Color Erase (BCE) so that color schemes
	" render properly when inside 256-color tmux and GNU screen.
	" See also http://snk.tuxfamily.org/log/vim-256color-bce.html
	set t_ut=
endif

" molokai {
" Should before colorscheme
syntax on

" Should before colorscheme, too
let g:molokai_original = 1
let g:rehash256 = 1

colorscheme molokai
" }

" Key map {
" Make Y behave like other capitals
nnoremap Y y$

" Improve up/down movement on wrapped lines
noremap j gj
noremap k gk

" Keep text selected after manual indentation
vnoremap < <gv
vnoremap > >gv

noremap ; :

" Remap U to <C-r> for easier redo
nnoremap U <C-r>

" Better comand-line editing
cnoremap <C-j> <Down>
cnoremap <C-k> <Up>
cnoremap <C-a> <Home>
cnoremap <C-e> <End>

" Delete current row
inoremap <C-d> <ESC>ddi

nnoremap <silent> q :call CloseWindow()<CR>

function! CloseWindow()
	if tabpagenr('$') > 1
		quit
		return
	endif

	let last_winnr = winnr('$')
	if last_winnr == 1 || last_winnr > 3
		quit
		return
	endif

	if last_winnr == 2 && (!exists('g:NERDTree') || !g:NERDTree.IsOpen())
		quit
		return
	endif

	if last_winnr == 3
		if !exists('g:NERDTree') || !g:NERDTree.IsOpen()
			quit
			return
		endif

		let tagbar_winnr = bufwinnr('__Tagbar__')
		if tagbar_winnr < 0
			quit
			return
		endif
	endif

	" If NERDTreeTabs is opend, only call quitall can save the session
	quitall
endfunction
" }

" Buffer {
nnoremap <silent> <Leader>d :Bdelete<CR>
nnoremap <silent><Leader>o :execute 'edit' Prompt('New buffer name: ', expand('%'), 'file')<CR>
" }

" Tab {
nnoremap <silent><Leader>t :execute 'tabnew' Prompt('New tab name: ', expand('%'), 'file')<CR>
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
" }

" Split {
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-h> <C-w>h
nnoremap <C-l> <C-w>l
nnoremap <silent><Leader>s :execute 'new' Prompt('New split name: ', expand('%'), 'file')<CR>
nnoremap <silent><Leader>v :execute 'vnew' Prompt('New vsplit name: ', expand('%'), 'file')<CR>

nnoremap <C-up> <C-w>+
nnoremap <C-down> <C-w>-
nnoremap <C-left> <C-w>>
nnoremap <C-right> <C-w><
" }

" F2 ~ F10 {
nnoremap <silent><F2> :NERDTreeTabsToggle<CR>
nnoremap <silent><F3> :TagbarToggle<CR>
nnoremap <silent><F7> :Dispatch!<CR>
nnoremap <silent><F8> :call DispatchQListToggle()<CR>
nnoremap <silent><F9> :InstantMarkdownPreview<CR>

set pastetoggle=<F5>

" Disbale paste mode when leaving insert mode
autocmd InsertLeave * set nopaste
" }

" Zoom {
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
" }

" incsearch.vim {
map / <Plug>(incsearch-forward)
map ? <Plug>(incsearch-backward)
map g/ <Plug>(incsearch-stay)

let g:incsearch#auto_nohlsearch = 1

map n <Plug>(incsearch-nohl-n)
map N <Plug>(incsearch-nohl-N)
map # <Plug>(incsearch-nohl-*)
map * <Plug>(incsearch-nohl-#)
map g* <Plug>(incsearch-nohl-g*)
map g# <Plug>(incsearch-nohl-g#)
" }

" No highlight search
nnoremap <silent><Leader>/ :nohlsearch<CR>

function! Strip(input_string)
	return substitute(a:input_string, '^\s*\(.\{-}\)\s*$', '\1', '')
endfunction

" Prompt({prompt_text} [, {default_value} [, {completion_type}]])
" More completion_type, please refer :h command-completion
function! Prompt(prompt_text, ...)
	call inputsave()
	let value = ''
	if a:0 == 0
		let value = input(a:prompt_text)
	elseif a:0 == 1
		let value = input(a:prompt_text, a:1)
	else
		let value = input(a:prompt_text, a:1, a:2)
	endif
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

function! Clear()
	echon "\r\r"
	echon ''
endfunction

function! GetString(prompt_text)
	call Clear()
	echon a:prompt_text

	let str = ''
	try
		while 1
			let n = getchar()
			if n == 27
				throw 'exit'
			endif

			if n == 13
				break
			endif

			let c = ''
			if n is# "\<BS>" || n == 8
				let str = strpart(str, 0, strlen(str)-1)
				call Clear()
				echon a:prompt_text . str
			else
				let c = nr2char(n)
				let str .= c
				echon c
			endif
		endwhile
	catch /^Vim:Interrupt$/
		throw 'exit'
	endtry

	return str
endfunction

" Replace {
function! Replace(mode, confirm, wholeword)
	let word = ''
	let wholeword = a:wholeword
	if a:mode ==# 'n' || a:mode ==# 'normal'
		let word .= expand('<cword>')
	elseif a:mode ==# 'v' || a:mode ==# 'visual'
		let word .= GetVisualSelection()
		let wholeword = 0
	endif

	let search = ''
	if wholeword
		let search .= '\<' . escape(word, '/\.*$^~[') . '\>'
	else
		let search .= escape(word, '/\.*$^~[')
	endif

	let replace = ''
	try
		let prompt_text = 'Replace "' . word . '" with: '
		let replace = GetString(prompt_text)
	catch 'exit'
		call Clear()
		echon 'Replace: Canceled'
		return
	endtry

	let replace = escape(replace, '/\&~')

	let flag = ''
	if a:confirm
		let flag .= 'ec'
	else
		let flag .= 'e'
	endif

	execute ',$s/' . search . '/' . replace . '/' . flag . "|1,'' -&& | update"
endfunction

" Replace in normal mode
" Default
nnoremap <Leader>R :call Replace('n', 0, 0)<CR>
" Wholeword
nnoremap <Leader>rw :call Replace('n', 0, 1)<CR>
" Confirm
nnoremap <Leader>rc :call Replace('n', 1, 0)<CR>
" Wholeword, confirm
nnoremap <Leader>rcw :call Replace('n', 1, 1)<CR>

" Replace in visual mode
" Default
vnoremap <Leader>R :call Replace('v', 0, 0)<CR>
" Confirm
vnoremap <Leader>rc :call Replace('v', 1, 0)<CR>
" }

" ack.vim {
"let g:ack_use_dispatch = 1

if executable('ag')
	let g:ackprg = 'ag --hidden --nogroup --nocolor --column --smart-case --ignore-dir={.git,.hg,.svn,.bzr}'
elseif executable('ack') || executable('ack-grep')
	let g:ack_default_options = ' -s -H --nocolor --nogroup --nopager --column --smart-case --ignore-dir={.git,.hg,.svn,.bzr}'
endif
" }

" Session {
" Save session options
set sessionoptions="blank,buffers,folds,globals,help,localoptions,options,resize,sesdir,tabpages,winpos,winsize"

" Backup
nnoremap <Leader>bs :execute 'CtrlSpaceSaveWorkspace' Prompt('Session name: ')<CR>
" Restore
nnoremap <Leader>rs :execute 'CtrlSpaceLoadWorkspace' Prompt('Session name: ')<CR>
" }

" CtrlP {
let g:ctrlp_follow_symlinks = 1
let g:ctrlp_custom_ignore = {
			\ 'dir':  '\v[\/]\.(git|hg|svn|bzr)$',
			\ 'file': '\v\.(o|obj|so|dll|exe|pyc|pyo|swo|swp)$',
			\ }
if executable( 'ag' )
	" Use ag in CtrlP for listing files. Lightning fast and respects .gitignore
	let g:ctrlp_user_command = 'ag %s -l --nogroup --nocolor --smart-case -g ""'
	" ag is fast enough that CtrlP doesn't need to cache
	let g:ctrlp_use_caching = 0
endif
" }

" CtrlSpace {
" Only work after saving workspace
let g:CtrlSpaceLoadLastWorkspaceOnStart = 1
let g:CtrlSpaceSaveWorkspaceOnSwitch = 1
let g:CtrlSpaceSaveWorkspaceOnExit = 1

let g:CtrlSpaceStatuslineFunction = 'airline#extensions#ctrlspace#statusline()'
" }

" vim-EasyMotion {
let g:EasyMotion_smartcase = 1
" }

" vim-easyclip {
let g:EasyClipUseYankDefaults = 0
let g:EasyClipUseCutDefaults = 0
let g:EasyClipUsePasteDefaults = 0
let g:EasyClipEnableBlackHoleRedirect = 0
let g:EasyClipUsePasteToggleDefaults = 0
let g:EasyClipUseSubstituteDefaults = 1
" }

" vim-rooter {
let g:rooter_silent_chdir = 1
"let g:rooter_use_lcd = 1

" Do it manually, or it will cause CtrlSpace's workspace cannot save other project's file.
let g:rooter_manual_only = 1
" }

" Ctags {
" Auto set tag file path
autocmd BufNewFile,BufRead * execute 'setlocal tags=' . (!empty(FindRootDirectory()) ? FindRootDirectory() . '/' : './') . '.tags,' . &tags

" Highlight .tags file as tags file
autocmd BufNewFile,BufRead *.tags set filetype=tags
" }

" vim-easytags {
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
" }

" NERDTree {
" Set NERDTree window width
let NERDTreeWinSize = 32
let g:NERDTreeAutoDeleteBuffer = 1

" Show hidden
let NERDTreeShowHidden = 1
" Ignore files
let NERDTreeIgnore=['\.o$', '\.obj$', '\.so$', '\.dll$', '\.exe$', '\.py[co]$', '\~$', '\.swo$', '\.swp$', '^\.git$', '^\.hg$', '^\.svn$', '\.bzr$']

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
endfunction
" }

" Tagbar {
" Tagbar width
let tagbar_width = 32
" }

" Gitv {
" Disable ctrl key map due to the conflict
let g:Gitv_DoNotMapCtrlKey = 1
" }

" YouCompleteMe {
if !empty(glob('~/.vim/bundle/YouCompleteMe/third_party/ycmd/cpp/ycm/.ycm_extra_conf.py'))
	let g:ycm_global_ycm_extra_conf = '~/.vim/bundle/YouCompleteMe/third_party/ycmd/cpp/ycm/.ycm_extra_conf.py'
endif

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
" }

" Enable omni completion
autocmd FileType javascript setlocal omnifunc=javascriptcomplete#CompleteJS
autocmd FileType python setlocal omnifunc=pythoncomplete#Complete
autocmd FileType xml setlocal omnifunc=xmlcomplete#CompleteTags
autocmd FileType ruby setlocal omnifunc=rubycomplete#Complete
autocmd FileType php setlocal omnifunc=phpcomplete#CompletePHP
autocmd FileType sql setlocal omnifunc=sqlcomplete#Complete
autocmd FileType java setlocal omnifunc=javacomplete#Complete

" Ultisnips {
let g:UltiSnipsExpandTrigger='<Leader><tab>'
" }

" Syntastic {
let g:syntastic_loc_list_height = 10
let g:syntastic_error_symbol = '✖'
let g:syntastic_style_error_symbol = '✖'
let g:syntastic_warning_symbol = '!'
let g:syntastic_style_warning_symbol = '!'
let g:syntastic_always_populate_loc_list = 0
let g:syntastic_auto_loc_list = 0
let g:syntastic_check_on_open = 1
let g:syntastic_check_on_wq = 0
let g:syntastic_enable_highlighting = 1
let g:syntastic_go_checkers = ['golint', 'govet', 'errcheck']
let g:syntastic_mode_map = {'mode': 'active', 'passive_filetypes': ['go']}

function! ToggleErrors()
	let old_last_winnr = winnr('$')
	lclose
	if old_last_winnr == winnr('$')
		" Nothing was closed, open syntastic_error location panel
		Errors
	endif
endfunction

nnoremap <silent><Leader>e :call ToggleErrors()<CR>
" }

" vim-autoformat {
" Execute Autoformat onsave
autocmd FileType c,cpp,go,java,javascript,json,python,lua,ruby,php,markdown,sh,vim autocmd BufWrite <buffer> :Autoformat

" Enable autoindent
let g:autoformat_autoindent = 1

" Enable auto retab
let g:autoformat_retab = 1

" Enable auto remove trailing spaces
let g:autoformat_remove_trailing_spaces = 1

" Generic C, C++, Objective-C style
" A style similar to the Linux Kernel Coding Style
" Linux Kernel Coding Style: https://www.kernel.org/doc/Documentation/CodingStyle
let g:formatdef_clangformat = "'clang-format -style=\"{BasedOnStyle: LLVM, IndentWidth: 8, UseTab: Always, BreakBeforeBraces: Linux, AllowShortIfStatementsOnASingleLine: false, IndentCaseLabels: false}\"'"

" Golang
let g:formatters_go = ['goimports']

" Python
let g:formatter_yapf_style = 'pep8'
let g:formatters_python = ['yapf']

" Markdown
let g:formatdef_remark_markdown = "\"remark --silent --no-color --setting 'fences: true, listItemIndent: \\\"1\\\"'\""
" }

" vim-easy-align {
" Start interactive EasyAlign in visual mode (e.g. vipga)
xmap ga <Plug>(EasyAlign)
" Start interactive EasyAlign for a motion/text object (e.g. gaip)
nmap ga <Plug>(EasyAlign)
" }

" vim-better-whitespace {
let g:better_whitespace_filetypes_blacklist = []

nnoremap <silent><Leader><Space> :StripWhitespace<CR>
" }

" vim-go {
let g:go_highlight_functions = 1
let g:go_highlight_methods = 1
let g:go_highlight_structs = 1
let g:go_highlight_interfaces = 1
let g:go_highlight_build_constraints = 1
let g:go_fmt_fail_silently = 1
let g:go_disable_autoinstall = 1
" Disable run GoFmt on save, do it by vim-autoformat
let g:go_fmt_autosave = 0
let g:go_dispatch_enabled = 1
let g:go_fmt_command = 'goimports'
let g:go_doc_keywordprg_enabled = 0
let g:godef_split = 2
let g:godef_same_file_in_same_window = 1

" Use Ctrl-o to jump back, see :help jumplist
autocmd FileType go nmap <silent><Leader>gc :GoRun %<CR>
autocmd FileType go nmap <silent><Leader>gb <Plug>(go-build)
autocmd FileType go nmap <silent><Leader>gi <Plug>(go-install)
autocmd FileType go nmap <silent><Leader>gr <Plug>(go-referrers)
autocmd FileType go nmap <silent><Leader>gt <Plug>(go-test)
autocmd FileType go nmap <silent><Leader>gf <Plug>(go-test-func)
autocmd FileType go nmap <silent><Leader>ga <Plug>(go-alternate-edit)
" }

" vim-javacomplete2 {
autocmd FileType java autocmd BufWrite <buffer> execute 'silent JCimportsAddMissing' | execute 'JCimportsRemoveUnused'
" }

" vim-json {
let g:vim_json_syntax_conceal = 0
" }

" python-syntax {
let python_highlight_all = 1
" }

" vim-lua-ftplugin {
let g:lua_check_syntax = 0
let g:lua_check_globals = 0
let g:lua_complete_keywords = 1
let g:lua_complete_globals = 1
let g:lua_complete_library = 1
let g:lua_complete_dynamic = 1
let g:lua_complete_omni = 1
let g:lua_define_completion_mappings = 0
" }

" vim-markdown {
let g:vim_markdown_folding_disabled = 1
let g:markdown_syntax_conceal = 0
" }

" vim-markdown {
" tpope/vim-markdown
" Don't need to install these if you are running a recent version of Vim
let g:markdown_fenced_languages = ['c', 'cpp', 'java', 'javascript', 'python', 'ruby', 'php', 'html', 'css', 'vim', 'bash=sh']
" }

" vim-instant_markdown {
let g:instant_markdown_slow = 1
let g:instant_markdown_autostart = 0
" }

" Terminal {
if !has('gui_running')
	" Check file changes outside vim when in xterm
	autocmd CursorHold,CursorHoldI,WinEnter,BufEnter * if getcmdtype() ==# '' | checktime | endif
endif
" }

" GUI {
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
endif
" }
