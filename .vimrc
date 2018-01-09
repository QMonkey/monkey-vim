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
	let s:path = expand('/.vim/autoload/plug.vim')
	silent execute '!curl' '-fLo' $HOME . s:path '--create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'

	augroup PlugInstall
		autocmd!

		autocmd VimEnter * PlugInstall | source $MYVIMRC
	augroup END
endif
" }

" vim-plug {
" Time limit of each task in seconds
let g:plug_timeout = 300
" }

" Windows {
if has('win32') || has('win64')
	" On Windows, also use '.vim' instead of 'vimfiles'; this makes synchronization across systems easier
	set runtimepath=$HOME\.vim,$VIM\vimfiles,$VIMRUNTIME,$VIM\vimfiles\after,$HOME\.vim\after
endif
" }

call plug#begin(expand($HOME . '/.vim/bundle'))

" Plugins {
Plug 'tomasr/molokai'
Plug 'nathanaelkane/vim-indent-guides'
Plug 'itchyny/lightline.vim'
Plug 'ctrlpvim/ctrlp.vim' | Plug 'FelikZ/ctrlp-py-matcher'
Plug 'junegunn/fzf', {'dir': '~/.fzf', 'do': './install --all'}
Plug 'junegunn/fzf.vim'
Plug 'tpope/vim-obsession'
Plug 'justinmk/vim-sneak'
Plug 'wellle/targets.vim'
Plug 'svermeulen/vim-easyclip'
Plug 'Konfekt/FastFold'
Plug 'haya14busa/incsearch.vim'
Plug 'mileszs/ack.vim', {'on': ['Ack', 'AckAdd', 'AckFromSearch', 'LAck', 'LAckAdd', 'AckFile', 'AckHelp', 'LAckHelp', 'AckWindow', 'LAckWindow']}
Plug 'tpope/vim-commentary'
Plug 'Chiel92/vim-autoformat', {'on': 'Autoformat'}
Plug 'ntpeters/vim-better-whitespace'
Plug 'tpope/vim-dispatch', {'on': ['Dispatch', 'FocusDispatch', 'Make', 'Copen', 'Start', 'Spawn']}
Plug 'thinca/vim-quickrun', {'on': ['QuickRun', '<Plug>(quickrun)']}
Plug 'airblade/vim-rooter'
Plug 'ludovicchabant/vim-gutentags'
Plug 'w0rp/ale'
Plug 'Valloric/YouCompleteMe', {'do': 'python install.py --clang-completer --gocode-completer'}
			\ | Plug 'rdnetto/YCM-Generator', {'branch': 'stable', 'for': ['c', 'cpp'], 'on': 'YcmGenerateConfig'}
Plug 'SirVer/ultisnips' | Plug 'honza/vim-snippets'
Plug 'tpope/vim-fugitive' | Plug 'idanarye/vim-merginal' | Plug 'gregsexton/gitv', {'on': 'Gitv'}
Plug 'airblade/vim-gitgutter'
Plug 'tpope/vim-surround'
Plug 'tpope/vim-repeat'
Plug 'tpope/vim-eunuch', {'on': ['Remove', 'Unlink', 'Move', 'Rename', 'Chmod', 'Mkdir', 'Find', 'SudoEdit', 'SudoWrite', 'Wall']}
Plug 'brooth/far.vim'
Plug 'simeji/winresizer'
Plug 'Raimondi/delimitMate'
Plug 'kshenoy/vim-signature'
Plug 'romainl/vim-qf'
Plug 'shime/vim-livedown', {'for': 'markdown', 'on': 'LivedownPreview'}
Plug 'cespare/vim-toml', {'for': ['toml', 'markdown']}
Plug 'chr4/nginx.vim', {'for': ['nginx', 'markdown']}

if has('mac') || has('macunix')
	Plug 'rizzatti/dash.vim'
else
	Plug 'KabbAmine/zeavim.vim'
endif

if has('win32') || has('win64')
	Plug 'kkoenig/wimproved.vim', {'on': ['WCenter', 'WSetAlpha', 'WToggleFullscreen', 'WToggleClean']}
endif
" }

" Add plugins to &runtimepath
call plug#end()

" Leader {
let g:mapleader = ','
" }

" Encoding {
language message en_US.UTF-8
set langmenu=en_US.UTF-8

set encoding=utf-8
scriptencoding utf-8

" Only work in terminal vim
set termencoding=utf-8

set fileencodings=utf-8,gb18030,cp936,ucs-bom,big5,euc-jp,euc-kr,latin1
" }

" Number {
set relativenumber number

augroup RelativeNumber
	autocmd!

	" Only work for the GUI version and a few console versions
	autocmd FocusLost * :set norelativenumber number
	autocmd FocusGained * :set relativenumber

	" Use absolute line number in insert mode
	autocmd InsertEnter * :set norelativenumber number
	autocmd InsertLeave * :set relativenumber
augroup END
" }

" Show the cursor position all the time
set ruler

set showmatch

" Cursorline {
" Highlight current line
set cursorline

augroup CursorLine
	autocmd!

	" Disable cursorline in insert mode
	autocmd InsertEnter * set nocursorline
	autocmd InsertLeave * set cursorline
augroup END
" }

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

set textwidth=0

set wrap
set breakindent

set splitright

" For mappings
set timeout
set timeoutlen=1000
" For key codes
set ttimeout
" Unnoticeable small value
set ttimeoutlen=10

" Show tab, eof and trail space
set list
let &listchars="tab:\u25b8 ,eol:\u00ac,trail:\u22c5"

" Restore cursor to previous editing position
augroup RestoreCursorPosition
	autocmd!

	autocmd BufReadPost * if line("'\"") > 1 && line("'\"") <= line("$") | execute "normal! g'\"" | endif
augroup END

" Load matchit.vim, but only if the user hasn't installed a newer version.
if !exists('g:loaded_matchit') && findfile('plugin/matchit.vim', &runtimepath) ==# ''
	runtime! macros/matchit.vim
endif

" FileType {
augroup FileTypeGroup
	autocmd!

	autocmd FileType python,markdown setlocal expandtab tabstop=4 shiftwidth=4 softtabstop=4
	autocmd FileType json,yaml setlocal expandtab tabstop=2 shiftwidth=2 softtabstop=2

	autocmd BufNewFile *.sh,*.py call AutoInsertFileHead()

	" Move the quickfix window to the bottom of the window layout
	autocmd FileType qf wincmd J
augroup END

function! AutoInsertFileHead()
	" Shell
	if &filetype ==# 'sh'
		call setline(1, '#!/bin/sh')
	endif

	" Python
	if &filetype ==# 'python'
		call setline(1, '#!/usr/bin/env python')
		call setline(2, '# -*- coding: utf-8 -*-')
	endif

	call cursor(line('$'), 0)
	call BlankDown(2)
	call cursor(line('$'), 0)
endfunc
" }

" Docset {
augroup Docset
	autocmd!

	autocmd FileType man,help setlocal nolist

	" Use man as docset for unrecognized filetype
	autocmd BufNewFile,BufRead * if empty(&filetype) | call SetUnrecognizedFileTypeReferences() | endif

	autocmd FileType * call SetReferences()
augroup END

" Enable 'Man' command
source $VIMRUNTIME/ftplugin/man.vim

function! GetCurrentWord()
	return expand('<cword>')
endfunction

function! SetUnrecognizedFileTypeReferences()
	nnoremap <silent><buffer><S-k> :execute 'Man' GetCurrentWord()<CR>
	vnoremap <silent><buffer><S-k> <ESC>:execute 'Man' GetVisualSelection()<CR>
endfunction

function! SetReferences()
	let l:filetype_references = {
				\	'c': 'Man',
				\	'sh': 'Man',
				\	'vim': 'help',
				\ }

	let l:is_reference_set = 0
	for [l:ftype, l:reference] in items(l:filetype_references)
		if &filetype != l:ftype
			continue
		endif

		let l:search = GetCurrentWord()
		execute 'nnoremap <silent><buffer><S-k> :execute "' . l:reference . '" GetCurrentWord()<CR>'

		" Enable reference in visual-mode
		execute 'vnoremap <silent><buffer><S-k> <ESC>:execute "' . l:reference . '" GetVisualSelection()<CR>'

		let l:is_reference_set = 1
	endfor

	if !l:is_reference_set
		" Default reference: dash or zeal
		if has('mac') || has('macunix')
			nnoremap <silent><buffer><S-k> :execute 'Dash' GetCurrentWord()<CR>
			vnoremap <silent><buffer><S-k> <ESC>:execute 'Dash' GetVisualSelection()<CR>
		else
			nnoremap <silent><buffer><S-k> :Zeavim<CR>
			vnoremap <silent><buffer><S-k> :Zeavim<CR>
		endif
	endif
endfunction
" }

" Inspired by http://stackoverflow.com/questions/1533565/how-to-get-visually-selected-text-in-vimscript
function! GetVisualSelection()
	let l:selection = ''
	try
		let l:a_save = @a
		normal! gv"ay
		let l:selection = @a
	finally
		let @a = l:a_save
	endtry
	return l:selection
endfunction

" zeavim.vim {
let g:zv_disable_mapping = 1

if !has('mac') && !has('macunix')
	nmap <silent><Leader><Leader>z <Plug>ZVKeyDocset
endif
" }

" dash.vim {
if has('mac') || has('macunix')
	function! DashPrompt()
		let l:dash_command = 'Dash'

		let l:ftype = Prompt('Docset: ', &filetype)
		if empty(l:ftype)
			let l:dash_command = 'Dash!'
		endif
		call Clear()

		let l:prompt_text = 'Dash (' . l:ftype . ")\n" . 'Search for: '
		let l:key = Prompt(l:prompt_text)

		execute l:dash_command l:key l:ftype
	endfunction

	nmap <silent><Leader><Leader>z :call DashPrompt()<CR>
endif
" }

" Resize splits when the window is resized
augroup AutoResize
	autocmd!

	autocmd VimResized * execute "normal! \<C-w>="
augroup END

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
augroup PythonFold
	autocmd!

	autocmd FileType python setlocal foldmethod=indent
augroup END

" Character width. Should never be enable!
"set ambiwidth=double

" Use both Unix, DOS and Mac file formats, but favor the Unix one for new files
set fileformats=unix,dos,mac

" Configure backspace so it acts as it should act
set backspace=indent,eol,start

" Allow switching away from a changed buffer without saving
set hidden

" Auto reload file changes outside vim
set autoread

" No bells
set belloff=all

" Disable mouse
set mouse=a

" Only if there are at least two tab pages
set showtabline=1

" Always show status line
set laststatus=2

" lightline.vim {
let g:lightline = {
			\ 'colorscheme': 'powerline',
			\ 'active': {
			\   'left': [['mode', 'paste'], ['gitgutter', 'fugitive', 'filename'], ['ctrlpmark']],
			\   'right': [['ale', 'lineinfo'], ['percent'], ['filetype', 'fileencoding', 'fileformat']]
			\ },
			\ 'inactive': {
			\   'left': [['mode', 'filename']],
			\   'right': []
			\ },
			\ 'component_function': {
			\   'gitgutter': 'LightLineGitGutter',
			\   'fugitive': 'LightLineFugitive',
			\   'filename': 'LightLineFilename',
			\   'fileformat': 'LightLineFileformat',
			\   'filetype': 'LightLineFiletype',
			\   'fileencoding': 'LightLineFileencoding',
			\   'percent': 'LightLinePercent',
			\   'lineinfo': 'LightLineLineInfo',
			\   'mode': 'LightLineMode',
			\   'ctrlpmark': 'CtrlPMark',
			\ },
			\ 'component_expand': {
			\   'tabs': 'lightline#tabs',
			\   'ale': 'ALEGetStatusLine',
			\ },
			\ 'component_type': {
			\   'ale': 'error',
			\ },
			\ 'separator': {'left': "\ue0b0", 'right': "\ue0b2"},
			\ 'subseparator': {'left': "\ue0b1", 'right': "\ue0b3"},
			\ 'tab': {
			\   'active': [ 'filename', 'modified' ],
			\   'inactive': [ 'filename', 'modified' ],
			\ },
			\ 'tabline': {
			\   'left': [ [ 'tabs' ] ],
			\   'right': []
			\ },
			\ 'tabline_separator': {'left': "\ue0b0", 'right': "\ue0b2"},
			\ 'tabline_subseparator': {'left': "\ue0b1", 'right': "\ue0b3"},
			\ }

function! LightLineModified()
	return &filetype =~# 'help' ? '' : &modified ? '+' : &modifiable ? '' : '-'
endfunction

function! LightLineReadonly()
	return &filetype !~? 'help' && &readonly ? "\ue0a2" : ''
endfunction

function! LightLineFilename()
	if GetWindowType() != 0
		return ''
	endif

	let l:fname = expand('%:t')
	return l:fname ==# 'ControlP' && has_key(g:lightline, 'ctrlp_item') ? g:lightline.ctrlp_item :
				\ ('' !=# LightLineReadonly() ? LightLineReadonly() . ' ' : '') .
				\ ('' !=# l:fname ? l:fname : '[No Name]') .
				\ ('' !=# LightLineModified() ? ' ' . LightLineModified() : '')
endfunction

function! GetBufferListOutputAsOneString()
	let l:buffer_list = ''
	redir =>> l:buffer_list
	ls
	redir END
	return l:buffer_list
endfunction

function! IsLocationListBuffer()
	if &filetype !=# 'qf'
		return 0
	endif

	silent let l:buffer_list = GetBufferListOutputAsOneString()

	let l:quickfix_match = matchlist(l:buffer_list,
				\ '\n\s*\(\d\+\)[^\n]*Quickfix')
	if empty(l:quickfix_match)
		return 1
	endif
	let l:quickfix_bufnr = l:quickfix_match[1]
	return l:quickfix_bufnr == bufnr('%') ? 0 : 1
endfunction

function! GetWindowType()
	if &previewwindow
		return 3
	endif

	if &filetype is# 'qf'
		if !IsLocationListBuffer()
			return 2
		endif

		return 1
	endif

	return 0
endfunction

function! IsGitFile()
	if !exists('g:loaded_gitgutter') || !exists('g:loaded_fugitive')
		return 0
	endif

	let l:fname = expand('%:t')
	let l:plugins = ['\[Plugins\]', 'ControlP']

	if l:fname ==# ''
		return 0
	endif

	for l:plugin in l:plugins
		if l:fname =~# l:plugin
			return 0
		endif
	endfor

	let l:git_dir = fugitive#extract_git_dir(resolve(expand('%')))
	if l:git_dir ==# ''
		return 0
	endif

	return 1
endfunction

function! LightLineGitGutter()
	if GetWindowType() != 0
		return ''
	endif

	if !IsGitFile()
		return ''
	endif

	let l:summary = GitGutterGetHunkSummary()
	return printf('+%d ~%d -%d', l:summary[0], l:summary[1], l:summary[2])
endfunction

function! LightLineFugitive()
	if GetWindowType() != 0
		return ''
	endif

	if !IsGitFile()
		return ''
	endif

	try
		if getftype(expand('%')) ==# 'link'
			call fugitive#detect(resolve(expand('%')))
		endif
		let l:mark = "\ue0a0 "
		let l:branch = fugitive#head()
		return l:branch !=# '' ? l:mark.branch : ''
	catch
	endtry
	return ''
endfunction

function! LightLineFileformat()
	return winwidth(0) > 70 ? &fileformat : ''
endfunction

function! LightLineFiletype()
	return winwidth(0) > 70 ? (&filetype !=# '' ? &filetype : 'unknown') : ''
endfunction

function! LightLineFileencoding()
	return winwidth(0) > 70 ? (&fileencoding !=# '' ? &fileencoding : &encoding) : ''
endfunction

function! LightLinePercent()
	return winwidth(0) > 70 ? printf('%3d%%', (100 * line('.') / line('$'))) : ''
endfunction

function! LightLineLineInfo()
	return winwidth(0) > 70 ? printf('%3d/%-d :%-2d', line('.'), line('$'), col('.')) : ''
endfunction

function! LightLineMode()
	let l:fname = expand('%:t')
	let l:window_type = GetWindowType()
	if l:window_type != 0
		return l:window_type == 3 ? 'Preview' :
					\ l:window_type == 2 ? 'Quickfix' :
					\ l:window_type == 1 ? 'Location' : ''
	endif

	return  l:fname ==# 'ControlP' ? 'CtrlP' :
				\ winwidth(0) > 60 ? lightline#mode() : ''
endfunction

function! CtrlPMark()
	if expand('%:t') =~# 'ControlP' && has_key(g:lightline, 'ctrlp_item')
		call lightline#link('iR'[g:lightline.ctrlp_regex])
		return lightline#concatenate([g:lightline.ctrlp_prev, g:lightline.ctrlp_item
					\ , g:lightline.ctrlp_next], 0)
	else
		return ''
	endif
endfunction

let g:ctrlp_status_func = {
			\ 'main': 'CtrlPStatusFunc_1',
			\ 'prog': 'CtrlPStatusFunc_2',
			\ }

function! CtrlPStatusFunc_1(focus, byfname, regex, prev, item, next, marked)
	let g:lightline.ctrlp_regex = a:regex
	let g:lightline.ctrlp_prev = a:prev
	let g:lightline.ctrlp_item = a:item
	let g:lightline.ctrlp_next = a:next
	return lightline#statusline(0)
endfunction

function! CtrlPStatusFunc_2(str)
	return lightline#statusline(0)
endfunction

augroup AfterALELint
	autocmd!
	autocmd User ALELint call lightline#update()
augroup END
" }

" Enable 256 color for vim
set t_Co=256

" Inspired by http://sunaku.github.io/vim-256color-bce.html
if &term =~# '256color'
	" Disable Background Color Erase (BCE) so that color schemes
	" render properly when inside 256-color tmux and GNU screen.
	" See also http://snk.tuxfamily.org/log/vim-256color-bce.html
	set t_ut=
endif

" molokai {
" Should before colorscheme, do it by vim-plug
" syntax on

" Should before colorscheme, too
let g:molokai_original = 1
let g:rehash256 = 1

colorscheme molokai
" }

" vim-indent-guides {
let g:indent_guides_enable_on_vim_startup = 1
let g:indent_guides_start_level = 2
let g:indent_guides_guide_size = 1
let g:indent_guides_tab_guides = 0
let g:indent_guides_exclude_filetypes = ['diff', 'man', 'help', 'git', 'gitcommit', 'qf']
" }

" Key map {
" Make Y behave like other capitals
nnoremap Y y$

" Improve up/down movement on wrapped lines
noremap j gj
noremap k gk

" Jump to start and end of line using the home row keys
noremap H ^
noremap L $

" Keep text selected after manual indentation
vnoremap < <gv
vnoremap > >gv

noremap ; :

" Remap U to <C-r> for easier redo
nnoremap U <C-r>

" Save file with root permission
cnoreabbrev W SudoWrite

" Quickly add empty lines
nmap <silent>[<Space> <Plug>BlankUp
nmap <silent>]<Space> <Plug>BlankDown

nnoremap <silent> <Plug>BlankUp   :<C-U>call BlankUp(v:count1)<CR>
nnoremap <silent> <Plug>BlankDown :<C-U>call BlankDown(v:count1)<CR>

function! BlankUp(count)
	put! = repeat(nr2char(10), a:count)
	']+1
	silent! call repeat#set("\<Plug>BlankUp", a:count)
endfunction

function! BlankDown(count)
	put = repeat(nr2char(10), a:count)
	'[-1
	silent! call repeat#set("\<Plug>BlankDown", a:count)
endfunction

" Better comand-line editing
cnoremap <C-j> <Down>
cnoremap <C-k> <Up>
cnoremap <C-a> <Home>
cnoremap <C-e> <End>

" Delete current row
inoremap <C-d> <ESC>ddi
inoremap <C-k> <ESC>Da

nnoremap <silent>q :call Quit()<CR>
nnoremap <silent><S-q> :quitall<CR>

noremap t q

function! Quit()
	let l:last_winnr = winnr('#')
	let l:window_type = GetWindowType()

	quit

	if l:window_type == 1 || l:window_type == 2
		silent! execute l:last_winnr . 'wincmd w'
	endif
endfunction
" }

" Buffer {
nnoremap <silent><Leader>o :execute 'edit' Prompt('New buffer name: ', '', 'file')<CR>

nnoremap <silent>[b :bprevious<CR>
nnoremap <silent>]b :bnext<CR>
" }

" Tab {
nnoremap <silent><Leader>t :execute 'tabnew' PathPrompt('New tab name: ', '', 'file')<CR>
nnoremap <silent>[t :tabprevious<CR>
nnoremap <silent>]t :tabnext<CR>
nnoremap <Leader>1 1gt
nnoremap <Leader>2 2gt
nnoremap <Leader>3 3gt
nnoremap <Leader>4 4gt
nnoremap <Leader>5 5gt
nnoremap <Leader>6 6gt
nnoremap <Leader>7 7gt
nnoremap <Leader>8 8gt
nnoremap <Leader>9 9gt
nnoremap <Leader>[ :tabfirst<CR>
nnoremap <Leader>] :tablast<CR>
" }

" Split {
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-h> <C-w>h
nnoremap <C-l> <C-w>l
nnoremap <silent><Leader>s :execute 'split' PathPrompt('New split name: ', '', 'file')<CR>
nnoremap <silent><Leader>v :execute 'vsplit' PathPrompt('New vsplit name: ', '', 'file')<CR>
" }

" F2 ~ F10 {
nnoremap <silent><F2> :MerginalToggle<CR>
nnoremap <silent><F4> :CtrlPClearAllCaches<CR>
nnoremap <silent><F7> :Dispatch!<CR>
nnoremap <silent><F8> :call QuickFixToggle('q', 'Copen!')<CR>
nnoremap <silent><F9> :QuickRun<CR>
nnoremap <silent><F10> :LivedownPreview<CR>
" }

" Toggle {
nnoremap <silent>cod :<C-R>=&diff ? 'diffoff' : 'diffthis'<CR><CR>
nnoremap <silent>cop :set invpaste<CR>
nnoremap <silent>col :set invlist<CR>

" Disbale paste mode when leaving insert mode
augroup PasteMode
	autocmd!

	autocmd InsertLeave * setlocal nopaste
augroup END
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

" netrw {
let g:netrw_banner = 0

nnoremap <silent>- :execute 'edit' expand('%:p:h')<CR>
nnoremap <silent>~ :execute 'edit' GetRootPath()<CR>

function! GetRootPath()
	let l:root_path = FindRootDirectory()
	if l:root_path ==# ''
		let l:root_path = expand('%:p:h')
	endif
	return l:root_path
endfunction

augroup ProjectDrawer
	autocmd!

	autocmd FileType netrw nnoremap <silent><buffer>~ :execute 'edit' GetRootPath()<CR>
augroup END
" }

" incsearch.vim {
map / <Plug>(incsearch-forward)
map ? <Plug>(incsearch-backward)
map g/ <Plug>(incsearch-stay)

let g:incsearch#auto_nohlsearch = 1

map n <Plug>(incsearch-nohl-n)
map N <Plug>(incsearch-nohl-N)
nmap # <Plug>(incsearch-nohl-*)
nmap * <Plug>(incsearch-nohl-#)
map g* <Plug>(incsearch-nohl-g#)
map g# <Plug>(incsearch-nohl-g*)

vmap # :<C-u>call VisualSetSearchContent()<CR>//<CR>
vmap * :<C-u>call VisualSetSearchContent()<CR>??<CR>

function! VisualSetSearchContent()
	let l:selection = GetVisualSelection()
	let @/ = '\V' . substitute(escape(l:selection, '\'), '\n', '\\n', 'g')
endfunction
" }

" No highlight search
nnoremap <silent><Leader>/ :nohlsearch<CR>

" QuickFix {
function! QuickFixToggle(type, cmd)
	let l:ftype = &filetype
	let l:last_winnr = winnr('#')
	let l:buffer_count_before = BufferCount()
	if a:type ==# 'quickfix' || a:type ==# 'q'
		silent! cclose
	elseif a:type ==# 'location' || a:type ==# 'l'
		silent! lclose
	endif

	if BufferCount() == l:buffer_count_before
		execute a:cmd
	else
		if l:ftype is# 'qf'
			silent! execute l:last_winnr . 'wincmd w'
		endif
	endif
endfunction

function! BufferCount()
	return len(tabpagebuflist())
endfunction

" nnoremap <silent><Leader>q :call QuickFixToggle('q', 'silent! botright copen 10')<CR>
" nnoremap <silent><Leader>l :call QuickFixToggle('l', 'silent! lopen 10')<CR>

if has('win32') || has('win64')
	function QuickfixConv()
		let l:qflist = getqflist()
		for l:i in l:qflist
			let l:i.text = iconv(l:i.text, 'cp936', 'utf-8')
		endfor
		call setqflist(l:qflist)
	endfunction

	augroup QuickfixEncodingConv
		autocmd!

		autocmd QuickfixCmdPost * call QuickfixConv()
	augroup END
endif
" }

" vim-qf {
let g:qf_mapping_ack_style = 1
let g:qf_window_bottom = 1
let g:qf_loclist_window_bottom = 1
let g:qf_auto_resize = 1
let g:qf_max_height = 10
let g:qf_auto_open_quickfix = 0
let g:qf_auto_open_loclist = 0
let g:qf_auto_quit = 1

nmap <Leader>q <Plug>qf_qf_toggle
nmap <Leader>l <Plug>qf_loc_toggle
" }

" QFEnter {
let g:qfenter_keymap = {}
let g:qfenter_keymap.open = ['<CR>']
let g:qfenter_keymap.vopen = ['i']
let g:qfenter_keymap.hopen = ['a']
let g:qfenter_keymap.topen = ['t']
" }

" far.vim {
let g:far#auto_write_replaced_buffers = 1
let g:far#repl_devider = "  \xe2\x9e\x9d  "
let g:far#multiline_sign = "\xe2\xac\x8e"
let g:far#cut_text_sign = "\xe2\x80\xa6"
let g:far#collapse_sign = '-'
let g:far#expand_sign = '+'
" }

" winresizer {
let g:winresizer_gui_enable = 0
let g:winresizer_start_key = '<F3>'
" }

function! Strip(input_string)
	return substitute(a:input_string, '^\s*\(.\{-}\)\s*$', '\1', '')
endfunction

" Prompt({prompt_text} [, {default_value} [, {completion_type}]])
" More completion_type, please refer :h command-completion
function! Prompt(prompt_text, ...)
	call inputsave()
	let l:value = ''
	if a:0 == 0
		let l:value = input(a:prompt_text)
	elseif a:0 == 1
		let l:value = input(a:prompt_text, a:1)
	else
		let l:value = input(a:prompt_text, a:1, a:2)
	endif
	call inputrestore()
	return Strip(l:value)
endfunction

function! PathPrompt(prompt_text, ...)
	let l:value = ''
	if a:0 == 0
		let l:value = Prompt(a:prompt_text)
	elseif a:0 == 1
		let l:value = Prompt(a:prompt_text, a:1)
	else
		let l:value = Prompt(a:prompt_text, a:1, a:2)
	endif

	if l:value ==# ''
		let l:value = '%'
	endif
	return l:value
endfunction

function! Clear()
	echon "\r\r"
	echon ''
endfunction

" ack.vim {
let g:ack_apply_qmappings = 0
let g:ack_apply_lmappings = 0
let g:ackpreview = 0

if executable('ag')
	let g:ackprg = 'ag --hidden --nogroup --nocolor --column --smart-case --ignore-dir={.git,.hg,.svn,.bzr}'
elseif executable('ack') || executable('ack-grep')
	let g:ack_default_options = ' -s -H --nocolor --nogroup --nopager --column --smart-case --ignore-dir={.git,.hg,.svn,.bzr}'
endif

nnoremap <silent><Leader>a :execute 'Ack!' GetCurrentWord()<CR>
vnoremap <silent><Leader>a <ESC>:execute 'Ack!' GetAckSelection()<CR>

function! GetAckSelection()
	return printf('"%s"', fnameescape(GetVisualSelection()))
endfunction
" }

" Session {
set sessionoptions-=blank sessionoptions-=options sessionoptions-=folds

" Backup
nnoremap <Leader>bs :execute 'Obsession' expand(GetRootPath() . '/.session.vim')<CR>
" Remove
nnoremap <Leader>rs :Obsession!<CR>

augroup RestoreSession
	autocmd!

	autocmd VimEnter * nested if argc() == 0 && filereadable(expand(GetRootPath() . '/.session.vim')) | execute 'source' expand(GetRootPath() . '/.session.vim') | endif
augroup END
" }

" fzf.vim {
let g:fzf_layout = {'down': '~30%'}

augroup Fzf
	autocmd!

	nmap <silent><C-m> :BCommits<CR>
	nmap <silent><C-w> :Windows<CR>
augroup END
" }

" ctrlp.vim {
let g:ctrlp_map = '<c-p>'
let g:ctrlp_follow_symlinks = 1
let g:ctrlp_use_caching = 1
let g:ctrlp_clear_cache_on_exit = 0
let g:ctrlp_max_files = 0
let g:ctrlp_show_hidden = 1
let g:ctrlp_custom_ignore = {
			\ 'dir':  '\v[\/]\.(git|hg|svn|bzr)$',
			\ 'file': '\v\.(o|obj|so|dll|exe|pyc|pyo|swo|swp|swn)$',
			\ }

let g:ctrlp_match_func = {'match': 'pymatcher#PyMatch'}
let g:ctrlp_match_current_file = 1
let g:ctrlp_match_window = 'bottom,order:btt,min:1,max:15,results:15'
let g:ctrlp_prompt_mappings = {
			\ 'PrtClearCache()': ['<F5>'],
			\ 'PrtDeleteEnt()': ['<c-d>'],
			\ }

augroup CtrlP
	autocmd!

	nmap <silent><C-t> :CtrlPBufTag<CR>
	nmap <silent><C-n> :CtrlPBuffer<CR>
augroup END
" }

" vim-sneak {
" Enable streak-mode
let g:sneak#streak = 1
let g:sneak#use_ic_scs = 1
let g:sneak#target_labels = ';sfadlgwterhiounpqv/SFADLGWTERHIOUNPQV?0'

" Disable default map for s and S
map <Plug>(go_away_sneak_s) <Plug>Sneak_s
map <Plug>(go_away_sneak_S) <Plug>Sneak_S

map <Plug>(go_away_sneak_next) <Plug>SneakNext
map <Plug>(go_away_sneak_previous) <Plug>SneakPrevious

" 2-character sneak
map f <Plug>(SneakStreak)
map F <Plug>(SneakStreakBackward)
" }

" vim-easyclip {
let g:EasyClipUseYankDefaults = 0
let g:EasyClipUseCutDefaults = 0
let g:EasyClipUsePasteDefaults = 0
let g:EasyClipEnableBlackHoleRedirect = 0
let g:EasyClipUsePasteToggleDefaults = 0
let g:EasyClipUseSubstituteDefaults = 1
" }

" FastFold {
" Only update fold after type zx or zX
let g:fastfold_fold_command_suffixes = ['x', 'X', 'a', 'A']
let g:fastfold_fold_movement_commands = []
" }

" vim-rooter {
let g:rooter_silent_chdir = 1
let g:rooter_change_directory_for_non_project_files = 'current'
let g:rooter_resolve_links = 1
"let g:rooter_use_lcd = 1

let g:rooter_manual_only = 1

nnoremap <silent><Leader>cd :Rooter<CR>

augroup ChangeRoot
	autocmd!

	" Change the working directory on vim startup
	autocmd VimEnter * :Rooter
augroup END
" }

" Ctags {
augroup Ctags
	autocmd!

	" Highlight .tags file as tags file
	autocmd BufNewFile,BufRead *.tags setfiletype tags
augroup END
" }

" vim-gutentags {
let g:gutentags_ctags_tagfile = '.tags'
let g:gutentags_ctags_auto_set_tags = 1
let g:gutentags_generate_on_missing = 1
let g:gutentags_generate_on_new = 0
let g:gutentags_generate_on_write = 1
let g:gutentags_background_update = 1
let g:gutentags_resolve_symlinks = 1
let g:gutentags_define_advanced_commands = 1
let g:gutentags_ctags_extra_args = [
			\ '--fields=+liaS',
			\ '--extra=+q',
			\ '--recurse=no',
			\ '--langmap=c:.c.h,vim:.vim.vimrc',
			\ '--c-kinds=+p',
			\ '--c++-kinds=+p',
			\ '--python-kinds=+i',
			\]
" }

" Gitv {
" Disable ctrl key map due to the conflict
let g:Gitv_DoNotMapCtrlKey = 1
" }

" vim-signature {
" Highlight mark a-zA-Z
highlight SignatureMarkText cterm=bold ctermfg=154 gui=bold guifg=#A6E22E

" Highlight marker !@#$%^&*()
highlight SignatureMarkerText term=bold cterm=bold ctermfg=197 gui=bold guifg=#F92672

let g:SignatureMarkTextHLDynamic = 1
let g:SignatureMarkerTextHLDynamic = 1
" }

" YouCompleteMe {
if !empty(glob($HOME . '/.vim/bundle/YouCompleteMe/third_party/ycmd/cpp/ycm/.ycm_extra_conf.py'))
	let g:ycm_global_ycm_extra_conf = expand($HOME . '/.vim/bundle/YouCompleteMe/third_party/ycmd/cpp/ycm/.ycm_extra_conf.py')
endif

" Do not use YouCompleteMe to check C, C++ and Objective-C, do it by ale
let g:ycm_show_diagnostics_ui = 0
let g:ycm_complete_in_comments = 1
let g:ycm_complete_in_strings = 1
let g:ycm_use_ultisnips_completer = 1
let g:ycm_collect_identifiers_from_comments_and_strings = 1
let g:ycm_collect_identifiers_from_tags_files = 1
let g:ycm_seed_identifiers_with_syntax = 1
let g:ycm_autoclose_preview_window_after_insertion = 1
let g:ycm_goto_buffer_command = 'new-tab'
let g:ycm_filepath_completion_use_working_dir = 1

let g:ycm_go_to_definition_filetypes = ['c', 'cpp', 'go', 'python']

augroup YouCompleteMeKeyMap
	autocmd!

	" Use Ctrl-o to jump back, see :help jumplist
	autocmd FileType c,cpp,go,python nnoremap <silent><buffer>gd :YcmCompleter GoToDefinition<CR>
	autocmd FileType c,cpp,go,python nnoremap <silent><buffer>gt :YcmCompleter GoTo<CR>
	autocmd FileType c,cpp,go,python nnoremap <silent><buffer><Leader>jd :YcmCompleter GoToDeclaration<CR>
	autocmd FileType * if index(g:ycm_go_to_definition_filetypes, &filetype) == -1 | nnoremap <silent><buffer>gd <C-]> | endif

	autocmd FileType python nnoremap <silent><buffer><Leader>gr :YcmCompleter GoToReferences<CR>
augroup END

" }

" Enable omni completion
augroup Omnifunc
	autocmd!

	autocmd FileType python setlocal omnifunc=pythoncomplete#Complete
augroup END

" Ultisnips {
let g:UltiSnipsExpandTrigger='<Leader><tab>'
" }

" ale {
let g:ale_sign_column_always = 0
let g:ale_sign_error = "\u2716"
let g:ale_sign_warning = '!'
let g:ale_echo_msg_error_str = 'Error'
let g:ale_echo_msg_warning_str = 'Warning'
let g:ale_echo_msg_format = '[%linter%] %s'
let g:ale_statusline_format = ['%d error(s)', '%d warning(s)', '']
let g:ale_lint_on_enter = 1
let g:ale_lint_on_save = 1
let g:ale_lint_on_text_changed = 0
let g:ale_set_loclist = 1
let g:ale_set_quickfix = 0
let g:ale_open_list = 0
let g:ale_keep_list_window_open = 0
" }

" vim-autoformat {
nnoremap <silent>coa :call ToggleAutoformat()<CR>

function! ToggleAutoformat()
	if !exists('b:autoformat_autoindent')
		let b:autoformat_autoindent = 1
	endif
	let b:autoformat_autoindent = xor(b:autoformat_autoindent, 1)

	if b:autoformat_autoindent == 1
		echo 'Autoformat: Enabled'
	else
		echo 'Autoformat: Disabled'
	endif
endfunction

" Execute Autoformat onsave
augroup AutoFormat
	autocmd!

	autocmd FileType c,cpp,go,python,lua,markdown,json,nginx,sh,vim autocmd BufWrite <buffer> :Autoformat
augroup END

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

" Markdown
let g:formatdef_remark_markdown = "\"remark --silent --no-color --setting 'fences: true, listItemIndent: \\\"1\\\"'\""
" }

" vim-better-whitespace {
let g:better_whitespace_filetypes_blacklist = ['diff', 'git', 'gitcommit', 'qf', 'help']

nnoremap <silent><Leader><Space> :StripWhitespace<CR>
" }

" vim-quickrun {
let g:quickrun_no_default_key_mappings = 1

map <Leader>ru <Plug>(quickrun)

augroup QuickRunRemap
	autocmd!

	autocmd FileType quickrun nnoremap <buffer><silent>q :call Quit()<CR>
augroup END
" }

" vim-markdown {
" tpope/vim-markdown
" Don't need to install these if you are running a recent version of Vim
let g:markdown_syntax_conceal = 0
let g:markdown_minlines = 100
let g:markdown_fenced_languages = ['c', 'cpp', 'go', 'python', 'lua', 'bash=sh', 'vim', 'json', 'toml', 'nginx']
" }

" Terminal {
if !has('gui_running')
	augroup CheckFileChanges
		autocmd!

		" Check file changes outside vim when in xterm
		autocmd CursorHold,CursorHoldI,BufEnter,WinEnter * if getcmdtype() ==# '' | checktime | endif
	augroup END
endif
" }

" GUI {
if has('gui_running')
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
	if has('gui_gtk')
		set guifont=Monospace\ 9
	elseif has('gui_macvim')
		set guifont=Hack:h12
	elseif has('gui_win32')
		set guifont=Hack:h10
	endif

	if has('gui_win32')
		" Use directx as a text renderer on Windows
		set renderoptions=type:directx
	endif

	function! MaximizeWindow()
		if has('gui_win32')
			simalt ~x
		elseif has('gui_macvim')
			" Make gvim tallest and widest as possible
			set lines=999
			set columns=9999
		else
			call system('wmctrl -ir ' . v:windowid . ' -b add,maximized_horz,maximized_vert')
		endif
	endfunction

	augroup Maximize
		autocmd!

		" Maximize window on gvim start up
		autocmd GUIEnter * call MaximizeWindow()
	augroup END

	function! ToggleFullscreen()
		if has('gui_win32')
			WToggleFullscreen
		elseif has('gui_macvim')
			set invfullscreen
		else
			call system('wmctrl -ir ' . v:windowid . ' -b toggle,fullscreen')
		endif
	endfunction

	nnoremap <silent><F11> :call ToggleFullscreen()<CR>
endif
" }
