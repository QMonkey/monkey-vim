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
	let l:path = expand('/.vim/autoload/plug.vim')
	silent execute '!curl' '-fLo' $HOME . l:path '--create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'

	augroup PlugInstall
		autocmd!

		autocmd VimEnter * PlugInstall | source $MYVIMRC
	augroup END
endif
" }

" vim-plug {
" Time limit of each task in seconds
let g:plug_timeout = 600
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
Plug 'scrooloose/nerdtree' | Plug 'jistr/vim-nerdtree-tabs'
Plug 'itchyny/lightline.vim'
Plug 'ctrlpvim/ctrlp.vim'
Plug 'vim-ctrlspace/vim-ctrlspace'
Plug 'justinmk/vim-sneak'
Plug 'wellle/targets.vim'
Plug 'michaeljsmith/vim-indent-object'
Plug 'svermeulen/vim-easyclip'
Plug 'Konfekt/FastFold'
Plug 'haya14busa/incsearch.vim'
Plug 'mileszs/ack.vim', {'on': ['Ack', 'AckAdd', 'AckFromSearch', 'LAck', 'LAckAdd', 'AckFile', 'AckHelp', 'LAckHelp', 'AckWindow', 'LAckWindow']}
Plug 'scrooloose/nerdcommenter'
Plug 'Chiel92/vim-autoformat', {'on': 'Autoformat'}
Plug 'ntpeters/vim-better-whitespace'
Plug 'tpope/vim-dispatch', {'on': ['Dispatch', 'FocusDispatch', 'Make', 'Copen', 'Start', 'Spawn']}
Plug 'thinca/vim-quickrun', {'on': ['QuickRun', '<Plug>(quickrun)']}
Plug 'airblade/vim-rooter'
Plug 'xolox/vim-misc' | Plug 'xolox/vim-easytags'
Plug 'w0rp/ale'
Plug 'Valloric/YouCompleteMe', {'do': 'python install.py --clang-completer --gocode-completer --tern-completer'}
			\ | Plug 'rdnetto/YCM-Generator', {'branch': 'stable', 'for': ['c', 'cpp'], 'on': 'YcmGenerateConfig'}
Plug 'SirVer/ultisnips' | Plug 'honza/vim-snippets'
Plug 'tpope/vim-fugitive' | Plug 'gregsexton/gitv', {'on': 'Gitv'}
Plug 'airblade/vim-gitgutter'
Plug 'tpope/vim-surround'
Plug 'tpope/vim-repeat'
Plug 'tpope/vim-eunuch', {'on': ['Remove', 'Unlink', 'Move', 'Rename', 'Chmod', 'Mkdir', 'Find', 'Locate', 'SudoEdit', 'SudoWrite', 'Wall']}
Plug 'Raimondi/delimitMate'
Plug 'kshenoy/vim-signature'
Plug 'yssl/QFEnter'
Plug 'fatih/vim-go', {'for': 'go', 'do': ':GoInstallBinaries'}
Plug 'artur-shaik/vim-javacomplete2', {'for': 'java'}
Plug 'pangloss/vim-javascript', {'for': 'javascript'}
Plug 'xolox/vim-lua-ftplugin', {'for': 'lua'}
Plug 'vim-ruby/vim-ruby', {'for': 'ruby'}
Plug 'tpope/vim-rails', {'for': 'ruby'}
Plug 'shawncplus/phpcomplete.vim', {'for': 'php'}
Plug 'shime/vim-livedown', {'for': 'markdown', 'on': 'LivedownPreview'}
Plug 'cespare/vim-toml', {'for': 'toml'}
Plug 'moskytw/nginx-contrib-vim', {'for': 'nginx'}

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

set textwidth=78

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
	autocmd FileType javascript,json,yaml,ruby setlocal expandtab tabstop=2 shiftwidth=2 softtabstop=2

	autocmd FileType php setlocal matchpairs-=<:>

	autocmd BufNewFile,BufRead .tern-project setfiletype json
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
		call append(1, '# -*- coding: utf-8 -*-')
	endif

	call BlankDown(2)
	call cursor(line('$'), 0)
endfunc
" }

" Docset {
augroup Docset
	autocmd!

	autocmd FileType man,help,nerdtree setlocal nolist

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

" Add what you want to refer
let g:zv_file_types = {
			\	'javascript': 'javascript,nodejs',
			\	'sql': 'mysql',
			\ }

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
set mouse=

" Only if there are at least two tab pages
set showtabline=1

" Always show status line
set laststatus=2

" lightline.vim {
let g:lightline = {
			\ 'colorscheme': 'powerline',
			\ 'active': {
			\   'left': [ [ 'mode', 'paste' ], [ 'gitgutter', 'fugitive', 'filename' ], ['ctrlpmark'] ],
			\   'right': [ [ 'ale', 'lineinfo' ], ['percent'], [ 'filetype', 'fileencoding', 'fileformat' ] ]
			\ },
			\ 'inactive': {
			\   'left': [ [ 'mode', 'filename' ] ],
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
			\ 'separator': { 'left': "\ue0b0", 'right': "\ue0b2" },
			\ 'subseparator': { 'left': "\ue0b1", 'right': "\ue0b3" },
			\ 'tab': {
			\   'active': [ 'filename', 'modified' ],
			\   'inactive': [ 'filename', 'modified' ],
			\ },
			\ 'tabline': {
			\   'left': [ [ 'tabs' ] ],
			\   'right': []
			\ },
			\ 'tabline_separator': { 'left': "\ue0b0", 'right': "\ue0b2" },
			\ 'tabline_subseparator': { 'left': "\ue0b1", 'right': "\ue0b3" },
			\ }

function! LightLineModified()
	return &filetype =~# 'help' ? '' : &modified ? '+' : &modifiable ? '' : '-'
endfunction

function! LightLineReadonly()
	return &filetype !~? 'help' && &readonly ? "\ue0a2" : ''
endfunction

function! LightLineFilename()
	let l:fname = expand('%:t')
	if l:fname ==# 'CtrlSpace'
		return ctrlspace#api#StatuslineModeSegment('')
	endif

	if GetWindowType() != 0
		return ''
	endif

	return l:fname ==# 'ControlP' && has_key(g:lightline, 'ctrlp_item') ? g:lightline.ctrlp_item :
				\ l:fname =~# 'NERD_tree' ? '' :
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
	let l:plugins = ['\[Plugins\]', 'NERD_tree', 'ControlP', 'CtrlSpace']

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
	if l:fname !=# 'CtrlSpace' && l:window_type != 0
		return l:window_type == 3 ? 'Preview' :
					\ l:window_type == 2 ? 'Quickfix' :
					\ l:window_type == 1 ? 'Location' : ''
	endif

	return  l:fname ==# 'ControlP' ? 'CtrlP' :
				\ l:fname ==# 'CtrlSpace' ? 'CtrlSpace' :
				\ l:fname =~# 'NERD_tree' ? 'NERDTree' :
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
let g:indent_guides_exclude_filetypes = ['diff', 'man', 'help', 'git', 'gitcommit', 'qf', 'nerdtree']
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

nnoremap <silent>q :call QuitWindow()<CR>
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

function! QuitWindow()
	if tabpagenr('$') > 1
		call Quit()
		return
	endif

	let l:max_winnr = winnr('$')
	if l:max_winnr == 1 || l:max_winnr > 3
		call Quit()
		return
	endif

	if l:max_winnr == 2 && (!exists('g:NERDTree') || !g:NERDTree.IsOpen()) || l:max_winnr > 2
		call Quit()
		return
	endif

	" If NERDTreeTabs is opend, only call quitall can save the session
	quitall
endfunction
" }

" Buffer {
nnoremap <silent><Leader>o :execute 'edit' Prompt('New buffer name: ', '', 'file')<CR>

nnoremap <silent>[b :bprevious<CR>
nnoremap <silent>]b :bnext<CR>

" Netrw style
nnoremap <silent>- :execute 'edit' expand('%:p:h')<CR>
nnoremap <silent>~ :execute 'edit' GetRootPath()<CR>

function! GetRootPath()
	let l:root_path = FindRootDirectory()
	if l:root_path ==# ''
		let l:root_path = expand('%:p:h')
	endif
	return l:root_path
endfunction
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

nnoremap <Up> <C-w>+
nnoremap <Down> <C-w>-
nnoremap <Left> <C-w>>
nnoremap <Right> <C-w><
" }

" F2 ~ F10 {
nnoremap <silent><F2> :call BetterNERDTreeTabsToggle()<CR>
nnoremap <silent><F7> :Dispatch!<CR>
nnoremap <silent><F8> :call QuickFixToggle('q', 'Copen!')<CR>
nnoremap <silent><F9> :QuickRun<CR>
nnoremap <silent><F10> :LivedownPreview<CR>

function! BetterNERDTreeTabsToggle()
	NERDTreeTabsToggle
	if exists('g:NERDTree') && g:NERDTree.IsOpen()
		silent! execute winnr('#') . 'wincmd w'
	endif
endfunction
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

nnoremap <silent><Leader>q :call QuickFixToggle('q', 'silent! botright copen 10')<CR>
nnoremap <silent><Leader>l :call QuickFixToggle('l', 'silent! lopen 10')<CR>

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

" QFEnter {
let g:qfenter_keymap = {}
let g:qfenter_keymap.open = ['<CR>']
let g:qfenter_keymap.vopen = ['i']
let g:qfenter_keymap.hopen = ['a']
let g:qfenter_keymap.topen = ['t']
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

function! GetString(prompt_text)
	call Clear()
	echon a:prompt_text

	let l:str = ''
	try
		while 1
			let l:n = getchar()
			if l:n == 27
				throw 'exit'
			endif

			if l:n == 13
				break
			endif

			let l:c = ''
			if l:n is# "\<BS>" || l:n == 8
				let l:str = strcharpart(l:str, 0, strchars(l:str)-1)
				call Clear()
				echon a:prompt_text . l:str
			else
				let l:c = nr2char(l:n)
				let l:str .= l:c
				echon l:c
			endif
		endwhile
	catch /^Vim:Interrupt$/
		throw 'exit'
	endtry

	return l:str
endfunction

" Replace {
function! Replace(mode, confirm, wholeword)
	let l:word = ''
	let l:wholeword = a:wholeword
	if a:mode ==# 'n' || a:mode ==# 'normal'
		let l:word .= GetCurrentWord()
	elseif a:mode ==# 'v' || a:mode ==# 'visual'
		let l:word .= GetVisualSelection()
		let l:wholeword = 0
	endif

	let l:search = substitute(escape(l:word, '/\.*$^~['), '\n', '\\n', 'g')
	if l:wholeword
		let l:search = '\<' . l:search . '\>'
	endif

	let l:replace = ''
	try
		let l:prompt_text = 'Replace "' . l:word . '" with: '
		let l:replace = GetString(l:prompt_text)
	catch 'exit'
		call Clear()
		echon 'Replace: Canceled'
		return
	endtry

	let l:replace = escape(l:replace, '/&~')

	let l:flag = ''
	if a:confirm
		let l:flag .= 'ec'
	else
		let l:flag .= 'e'
	endif

	execute ',$s/' . l:search . '/' . l:replace . '/' . l:flag . "| 1,'' -&& | update"
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
let g:ack_apply_qmappings = 0
let g:ack_apply_lmappings = 0

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

" nerdcommenter {
let g:NERDSpaceDelims = 1
let g:NERDRemoveExtraSpaces = 1
" }

" Session {
set sessionoptions-=options

" Backup
nnoremap <Leader>bs :execute 'CtrlSpaceSaveWorkspace' Prompt('Session name: ')<CR>
" Restore
nnoremap <Leader>rs :execute 'CtrlSpaceLoadWorkspace' Prompt('Session name: ')<CR>
" }

" ctrlp.vim {
let g:ctrlp_follow_symlinks = 1
let g:ctrlp_custom_ignore = {
			\ 'dir':  '\v[\/]\.(git|hg|svn|bzr)$',
			\ 'file': '\v\.(o|obj|so|dll|exe|pyc|pyo|swo|swp|swn)$',
			\ }

if executable('ag')
	" Use ag in CtrlP for listing files. Lightning fast and respects .gitignore
	let g:ctrlp_user_command = 'ag -l --nogroup --nocolor --smart-case -g "" %s'
	" ag is fast enough that CtrlP doesn't need to cache
	let g:ctrlp_use_caching = 0
endif

augroup CtrlP
	autocmd!

	nnoremap <silent><C-t> :CtrlPBufTag<CR>
	nnoremap <silent><C-n> :CtrlPTag<CR>
augroup END
" }

" vim-ctrlspace {
" Only work after saving workspace
let g:CtrlSpaceLoadLastWorkspaceOnStart = 1
let g:CtrlSpaceSaveWorkspaceOnSwitch = 1
let g:CtrlSpaceSaveWorkspaceOnExit = 1

let g:CtrlSpaceStatuslineFunction = 'lightline#statusline(0)'

if executable('ag')
	" Use ag to collect all files in your project directory
	let g:CtrlSpaceGlobCommand = 'ag -l --nogroup --nocolor -g ""'
endif
" }

" vim-sneak {
" Enable streak-mode
let g:sneak#streak = 1
let g:sneak#use_ic_scs = 1

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

" Do it manually, or it will cause CtrlSpace's workspace cannot save other project's file.
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

	" Auto set tag file path
	autocmd BufNewFile,BufRead * execute 'setlocal tags=' . (!empty(FindRootDirectory()) ? FindRootDirectory() . '/' : './') . '.tags,' . &tags

	" Highlight .tags file as tags file
	autocmd BufNewFile,BufRead *.tags setfiletype tags
augroup END
" }

" vim-easytags {
let g:easytags_async = 1

" Global tag file
let g:easytags_file = expand($HOME . '/.vim/.tags')

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
" }

" NERDTree {
" Set NERDTree window width
let g:NERDTreeWinSize = 32
let g:NERDTreeHijackNetrw = 1
let g:NERDTreeAutoDeleteBuffer = 1
let g:NERDTreeMinimalUI = 1
let g:NERDTreeMapOpenSplit = 'a'
let g:NERDTreeMapOpenVSplit = 'i'

" Show hidden
let g:NERDTreeShowHidden = 1
" Ignore files
let g:NERDTreeIgnore = ['\.o$', '\.obj$', '\.so$', '\.dll$', '\.exe$', '\.py[co]$', '\~$', '\.swo$', '\.swp$', '\.swn$', '^\.git$', '^\.hg$', '^\.svn$', '\.bzr$']

" Don't open NERDTreeTabs automatically when vim starts up
let g:nerdtree_tabs_open_on_gui_startup = 0
let g:nerdtree_tabs_open_on_console_startup = 0
let g:nerdtree_tabs_no_startup_for_diff = 1

" Meaningful tab captions for inactive tabs
let g:nerdtree_tabs_meaningful_tab_names = 1

" When switching into a tab, make sure that focus is on the file window, not in the NERDTree window
let g:nerdtree_tabs_focus_on_files = 1

" Synchronize view of all NERDTree windows (scroll and cursor position)
let g:nerdtree_tabs_synchronize_view = 1

" Close vim if the only window left open is a NERDTreeTabs
let g:nerdtree_tabs_autoclose = 1

" Show current file in NERDTree
nnoremap <silent><Leader>f :NERDTreeTabsFind<CR>

augroup NERDTreeRefresh
	autocmd!

	" Refresh NERDTree when enter NERDTree buffer
	autocmd BufEnter * if &filetype ==# 'nerdtree' | call Refresh() | endif
augroup END

function! Refresh()
	if !exists('g:NERDTree') || !g:NERDTree.IsOpen() || !exists('b:NERDTree')
		return
	endif

	call b:NERDTree.root.refresh()
	call b:NERDTree.root.refreshFlags()
	call NERDTreeRender()
endfunction
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
let g:ycm_goto_buffer_command = 'new-or-existing-tab'
let g:ycm_filepath_completion_use_working_dir = 1

let g:ycm_go_to_definition_filetypes = ['c', 'cpp', 'go', 'javascript', 'python']

augroup YouCompleteMeKeyMap
	autocmd!

	" Use Ctrl-o to jump back, see :help jumplist
	autocmd FileType * if index(ycm_go_to_definition_filetypes, &filetype) != -1
				\ | nnoremap <silent><buffer>gd :YcmCompleter GoToDefinition<CR>
				\ | else | nnoremap <silent><buffer>gd <C-]> | endif

	autocmd FileType python,javascript nnoremap <silent><buffer><Leader>gr :YcmCompleter GoToReferences<CR>
augroup END

nnoremap <silent><Leader>jt :YcmCompleter GoTo<CR>
nnoremap <silent><Leader>jd :YcmCompleter GoToDeclaration<CR>
" }

" Enable omni completion
augroup Omnifunc
	autocmd!

	autocmd FileType javascript setlocal omnifunc=javascriptcomplete#CompleteJS
	autocmd FileType java setlocal omnifunc=javacomplete#Complete
	autocmd FileType python setlocal omnifunc=pythoncomplete#Complete
	autocmd FileType ruby setlocal omnifunc=rubycomplete#Complete
	autocmd FileType php setlocal omnifunc=phpcomplete#CompletePHP
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
" Execute Autoformat onsave
augroup AutoFormat
	autocmd!

	autocmd FileType c,cpp,go,java,javascript,json,python,lua,ruby,php,markdown,sh,vim autocmd BufWrite <buffer> :Autoformat
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

	autocmd FileType quickrun nnoremap <buffer><silent>q :call QuitWindow()<CR>
augroup END
" }

" vim-go {
let g:go_highlight_types = 0
let g:go_highlight_functions = 0
let g:go_highlight_methods = 1
let g:go_highlight_build_constraints = 1
let g:go_highlight_generate_tags = 1
let g:go_highlight_space_tab_error = 0
let g:go_highlight_trailing_whitespace_error = 0
let g:go_fmt_fail_silently = 1
let g:go_disable_autoinstall = 1
" Disable run GoFmt on save, do it by vim-autoformat
let g:go_fmt_autosave = 0
let g:go_dispatch_enabled = 1
let g:go_fmt_command = 'goimports'
let g:go_doc_keywordprg_enabled = 0
let g:go_def_mapping_enabled = 0
let g:go_list_type = 'quickfix'
let g:go_def_reuse_buffer = 1

augroup GolangKeymap
	autocmd!

	" Use Ctrl-o to jump back, see :help jumplist
	autocmd FileType go nmap <silent><buffer>gd <Plug>(go-def-tab)
	autocmd FileType go nmap <silent><buffer><Leader>gb <Plug>(go-build)
	autocmd FileType go nmap <silent><buffer><Leader>gi <Plug>(go-install)
	autocmd FileType go nmap <silent><buffer><Leader>gr <Plug>(go-referrers)
	autocmd FileType go nmap <silent><buffer><Leader>gt <Plug>(go-test)
	autocmd FileType go nmap <silent><buffer><Leader>gf <Plug>(go-test-func)
	autocmd FileType go nmap <silent><buffer><Leader>ga <Plug>(go-alternate-edit)
augroup END
" }

" vim-javascript {
let g:javascript_plugin_jsdoc = 1
let g:javascript_plugin_ngdoc = 1
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

" vim-ruby {
let g:rubycomplete_buffer_loading = 1
let g:rubycomplete_classes_in_global = 1
let g:rubycomplete_rails = 1
let g:rubycomplete_load_gemfile = 1
" }

" vim-markdown {
" tpope/vim-markdown
" Don't need to install these if you are running a recent version of Vim
let g:markdown_syntax_conceal = 0
let g:markdown_fenced_languages = ['c', 'cpp', 'go', 'java', 'javascript', 'json', 'python', 'lua', 'ruby', 'php', 'bash=sh', 'vim', 'html', 'css']
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
