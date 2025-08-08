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

call plug#begin(expand($HOME . '/.vim/bundle'))

" Plugins {
Plug 'tomasr/molokai'
Plug 'nathanaelkane/vim-indent-guides'
Plug 'itchyny/lightline.vim'
Plug 'Yggdroot/LeaderF', {'do': ':LeaderfInstallCExtension'}
Plug 'dyng/ctrlsf.vim'
Plug 'mg979/vim-visual-multi'
Plug 'justinmk/vim-dirvish'
Plug 'tpope/vim-obsession'
Plug 'justinmk/vim-sneak'
Plug 'wellle/targets.vim'
Plug 'svermeulen/vim-subversive'
Plug 'Konfekt/FastFold'
Plug 'haya14busa/is.vim'
Plug 'haya14busa/vim-asterisk'
Plug 'RRethy/vim-illuminate'
Plug 'tpope/vim-commentary'
Plug 'vim-autoformat/vim-autoformat'
Plug 'ntpeters/vim-better-whitespace'
Plug 'skywind3000/asyncrun.vim'
Plug 'airblade/vim-rooter'
Plug 'ludovicchabant/vim-gutentags'
Plug 'w0rp/ale' | Plug 'maximbaz/lightline-ale'
Plug 'prabirshrestha/vim-lsp' | Plug 'mattn/vim-lsp-settings'
Plug 'prabirshrestha/asyncomplete.vim' | Plug 'prabirshrestha/asyncomplete-lsp.vim'
Plug 'tpope/vim-fugitive' | Plug 'junegunn/gv.vim', {'on': 'GV'}
Plug 'Eliot00/git-lens.vim'
Plug 'airblade/vim-gitgutter'
Plug 'tpope/vim-surround'
Plug 'tpope/vim-repeat'
Plug 'Raimondi/delimitMate'
Plug 'kshenoy/vim-signature'
Plug 'romainl/vim-qf'
Plug 'simeji/winresizer'
Plug 'shime/vim-livedown', {'for': 'markdown', 'on': 'LivedownPreview'}

if has('mac') || has('macunix')
	Plug 'rizzatti/dash.vim'
else
	Plug 'KabbAmine/zeavim.vim'
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

	" Only display relativenumber in active normal mode buffer
	autocmd WinEnter,BufEnter,InsertLeave * set relativenumber
	autocmd WinLeave,BufLeave,InsertEnter * set norelativenumber number
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

" Show search count message when searching
set shortmess-=S shortmess+=s

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
	autocmd FileType json setlocal expandtab tabstop=2 shiftwidth=2 softtabstop=2

	autocmd BufNewFile *.sh,*.py call AutoInsertFileHead()

	" Move the quickfix window to the bottom of the window layout
	autocmd FileType qf wincmd J
augroup END

function! AutoInsertFileHead()
	" Shell
	if &filetype ==# 'sh'
		call setline(1, '#!/bin/bash')
	endif

	" Python
	if &filetype ==# 'python'
		call setline(1, '#!/usr/bin/env python3')
		call setline(2, '# -*- coding: utf-8 -*-')
	endif

	call cursor(line('$'), 0)
	put = repeat(nr2char(10), 2)
	call cursor(line('$'), 0)
endfunc
" }

" Docset {
augroup Docset
	autocmd!

	autocmd FileType man,help setlocal nolist

	" Use man as docset for unrecognized filetype
	autocmd BufNewFile,BufRead * if empty(&filetype) | call SetUnrecognizedFileTypeDoc() | endif

	autocmd FileType * call SetDoc()
augroup END

" Enable 'Man' command
source $VIMRUNTIME/ftplugin/man.vim

function! GetCurrentWord()
	return expand('<cword>')
endfunction

function! SetUnrecognizedFileTypeDoc()
	nnoremap <silent><buffer><S-k> :execute 'Man' GetCurrentWord()<CR>
	vnoremap <silent><buffer><S-k> <ESC>:execute 'Man' GetVisualSelection()<CR>
endfunction

function! SetDoc()
	let l:filetype_docs = {
				\	'c': 'Man',
				\	'sh': 'BashHelp',
				\	'go': 'GoDoc',
				\	'python': 'PyDoc',
				\	'vim': 'help',
				\ }

	let l:is_doc_set = 0
	for [l:ftype, l:doc] in items(l:filetype_docs)
		if &filetype !=# l:ftype
			continue
		endif

		let l:search = GetCurrentWord()
		execute 'nnoremap <silent><buffer><S-k> :execute "' . l:doc . '" GetCurrentWord()<CR>'

		" Enable doc in visual-mode
		execute 'vnoremap <silent><buffer><S-k> <ESC>:execute "' . l:doc . '" GetVisualSelection()<CR>'

		let l:is_doc_set = 1
	endfor

	if !l:is_doc_set && &filetype !=# 'dirvish'
		" Default doc: dash or zeal
		if has('mac') || has('macunix')
			nnoremap <silent><buffer><S-k> :execute 'Dash' GetCurrentWord()<CR>
			vnoremap <silent><buffer><S-k> <ESC>:execute 'Dash' GetVisualSelection()<CR>
		else
			nnoremap <silent><buffer><S-k> :Zeavim<CR>
			vnoremap <silent><buffer><S-k> :ZeavimV<CR>
		endif
	endif
endfunction

function! ViewDoc(commands, name)
	let l:buf_name = expand("$HOME/__doc__")
	if bufloaded(l:buf_name)
		let l:buf_is_new = 0
		if bufname('%') !=# l:buf_name
			execute 'silent sbuffer ' . bufnr(l:buf_name)
		endif
	else
		let l:buf_is_new = 1
		execute 'silent split ' . l:buf_name
	endif

	setlocal modifiable
	setlocal noswapfile
	setlocal buftype=nofile
	setlocal bufhidden=delete
	setlocal nofoldenable
	setlocal nonumber
	setlocal norelativenumber
	setlocal nolist
	setlocal nobuflisted
	setlocal filetype=man

	for l:command in a:commands
		let l:cmd = l:command['cmd']
		let l:err_msg = l:command['err_msg']
		if !empty(l:err_msg)
			let l:cmd = printf('if (%s | grep "%s"); then exit 1; else %s; fi', l:cmd, l:err_msg, l:cmd)
			let l:cmd = printf("bash -c '%s'", l:cmd)
		endif

		silent keepjumps %delete _
		execute  'silent read !' . l:cmd
		normal 1G
		silent keepjumps 0delete _

		if v:shell_error == 0
			break
		endif
	endfor

	if v:shell_error != 0
		if l:buf_is_new
			execute 'silent bdelete!'
		else
			normal u
			setlocal nomodified
			setlocal nomodifiable
		endif
		redraw
		echohl WarningMsg | echo 'No documentation found for ' . a:name | echohl None
	else
		setlocal nomodified
		setlocal nomodifiable
	endif
endfunction

command! -nargs=1 BashHelp :call ViewDoc([{'cmd': 'bash -c "help <args>"', 'err_msg': ''}, {'cmd': 'man -S 1,8 <args>', 'err_msg': ''}], '<args>')
command! -nargs=1 PyDoc :call ViewDoc([{'cmd': 'python3 -m pydoc <args>', 'err_msg': 'No Python documentation found'}], '<args>')
command! -nargs=1 GoDoc :call ViewDoc([{'cmd': 'go doc -cmd -all <args>', 'err_msg': ''}], '<args>')
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
function! ResizeAllTab()
	let l:cur_tab = tabpagenr()
	silent! execute 'tabdo wincmd ='
	silent! execute 'tabnext ' . l:cur_tab
endfunction

augroup AutoResize
	autocmd!

	autocmd VimResized * call ResizeAllTab()
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
			\   'left': [['mode', 'paste'], ['gitgutter', 'fugitive', 'filename']],
			\   'right': [['linter_ok', 'linter_warnings', 'linter_errors', 'linter_checking', 'lineinfo'], ['percent'], ['filetype', 'fileencoding', 'fileformat']]
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
			\ },
			\ 'component_expand': {
			\   'tabs': 'lightline#tabs',
			\   'linter_checking': 'lightline#ale#checking',
			\   'linter_errors': 'lightline#ale#errors',
			\   'linter_warnings': 'lightline#ale#warnings',
			\   'linter_ok': 'lightline#ale#ok',
			\ },
			\ 'component_type': {
			\   'linter_checking': 'left',
			\   'linter_errors': 'error',
			\   'linter_warnings': 'warning',
			\   'linter_ok': 'left',
			\ },
			\ 'separator': {'left': "\ue0b0", 'right': "\ue0b2"},
			\ 'subseparator': {'left': "\ue0b1", 'right': "\ue0b3"},
			\ 'tab': {
			\   'active': ['filename', 'modified'],
			\   'inactive': ['filename', 'modified'],
			\ },
			\ 'tabline': {
			\   'left': [['tabs']],
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
	return  ('' !=# LightLineReadonly() ? LightLineReadonly() . ' ' : '') .
				\ ('' !=# l:fname ? l:fname : '[No Name]') .
				\ ('' !=# LightLineModified() ? ' ' . LightLineModified() : '')
endfunction

function! GetWindowType()
	if &previewwindow
		return 3
	endif

	if &filetype is# 'qf'
		let l:cur_winnr = winnr()
		if qf#IsQfWindow(l:cur_winnr)
			return 2
		elseif qf#IsLocWindow(l:cur_winnr)
			return 1
		endif
	endif

	return 0
endfunction

function! IsGitFile()
	if !exists('g:loaded_gitgutter') || !exists('g:loaded_fugitive')
		return 0
	endif

	let l:fname = expand('%:t')
	let l:plugins = ['\[Plugins\]']

	if l:fname ==# ''
		return 0
	endif

	for l:plugin in l:plugins
		if l:fname =~# l:plugin
			return 0
		endif
	endfor

	let l:git_dir = FugitiveExtractGitDir(resolve(expand('%')))
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
			call FugitiveDetect(resolve(expand('%')))
		endif
		let l:mark = "\ue0a0 "
		let l:branch = FugitiveHead()
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

	return winwidth(0) > 60 ? lightline#mode() : ''
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

" F1 ~ F10 {
nmap <F1> <Plug>CtrlSFPrompt
nnoremap <silent><F2> :CtrlSFToggle<CR>
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

" vim-dirvish {
let g:loaded_netrw = 1
let g:loaded_netrwPlugin = 1

nnoremap <silent>- :execute 'Dirvish' expand('%:p:h')<CR>
nnoremap <silent>~ :execute 'Dirvish' GetHomePath()<CR>

function! GetRootPath()
	let l:root_path = FindRootDirectory()
	if l:root_path ==# ''
		let l:root_path = expand('%:p:h')
	endif
	return l:root_path
endfunction

function! GetHomePath()
	let l:root_path = FindRootDirectory()
	if l:root_path ==# ''
		let l:root_path = expand('~')
	endif
	return l:root_path
endfunction

augroup ProjectDrawer
	autocmd!

	autocmd FileType dirvish silent! unmap <buffer>a
	autocmd FileType dirvish silent! unmap <buffer>A
	autocmd FileType dirvish silent! unmap <buffer>i
	autocmd FileType dirvish silent! unmap <buffer>I
	autocmd FileType dirvish silent! unmap <buffer>o
	autocmd FileType dirvish silent! unmap <buffer>O

	autocmd FileType dirvish noremap - <plug>(dirvish_up)
	autocmd FileType dirvish noremap <silent><buffer>o :call dirvish#open('edit', 0)<CR>
	autocmd FileType dirvish noremap <silent><buffer>a :call dirvish#open('split', 0)<CR>
	autocmd FileType dirvish noremap <silent><buffer>i :call dirvish#open('vsplit', 0)<CR>
	autocmd FileType dirvish noremap <silent><buffer>t :call dirvish#open('tabedit', 0)<CR>
augroup END
" }

" is.vim {
map *  <Plug>(asterisk-z*)<Plug>(is-nohl-1)
map g* <Plug>(asterisk-gz*)<Plug>(is-nohl-1)
map #  <Plug>(asterisk-z#)<Plug>(is-nohl-1)
map g# <Plug>(asterisk-gz#)<Plug>(is-nohl-1)
" }

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

nnoremap <silent><Leader>q :call QuickFixToggle('q', 'silent! botright copen 10')<CR>
nnoremap <silent><Leader>l :call QuickFixToggle('l', 'silent! lopen 10')<CR>
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

" Session {
set sessionoptions-=blank sessionoptions-=options sessionoptions-=folds sessionoptions-=terminal

" Backup
nnoremap <Leader>bs :execute 'Obsession' expand(GetRootPath() . '/.session.vim')<CR>
" Remove
nnoremap <Leader>rs :Obsession!<CR>

augroup RestoreSession
	autocmd!

	autocmd VimEnter * nested if argc() == 0 && filereadable(expand(GetRootPath() . '/.session.vim')) | execute 'source' expand(GetRootPath() . '/.session.vim') | endif
augroup END
" }

" LeaderF {
let g:Lf_PythonVersion = 3
let g:Lf_ShortcutF = '<C-p>'
let g:Lf_ShortcutB = '<C-m>'
let g:Lf_WindowPosition = 'bottom'
let g:Lf_ShowDevIcons = 0
let g:Lf_StlColorscheme = 'powerline'
let g:Lf_StlSeparator = {'left': "\ue0b0", 'right': "\ue0b2"}
let g:Lf_PreviewResult = {
			\ 'File': 0,
			\ 'Buffer': 0,
			\ 'Mru': 0,
			\ 'Tag': 0,
			\ 'BufTag': 0,
			\ 'Function': 0,
			\ 'Line': 0,
			\ 'Colorscheme': 1,
			\ 'Rg': 0,
			\ 'Gtags': 0
			\}

augroup LeaderF
	autocmd!

	nmap <silent><C-w> :LeaderfWindow<CR>
	nmap <silent><C-t> :LeaderfBufTag<CR>
	nmap <silent><C-y> :LeaderfFunction<CR>
	nmap <silent><C-e> :LeaderfLine<CR>
augroup END
" }

" ctrlsf.vim {
let g:ctrlsf_confirm_save = 0
let g:ctrlsf_extra_backend_args = {
			\ 'rg': '--hidden',
			\ 'ag': '--hidden',
			\ }
let g:ctrlsf_ignore_dir = ['.git', '.hg', '.svn', '.bzr']

nmap <silent><Leader>a <Plug>CtrlSFCwordExec
vmap <silent><Leader>a <Plug>CtrlSFVwordExec
" }

" vim-visual-multi {
" let g:VM_set_statusline = 0
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

" vim-subversive {
nmap s <plug>(SubversiveSubstitute)
xmap s <plug>(SubversiveSubstitute)
nmap ss <plug>(SubversiveSubstituteLine)
nmap S <plug>(SubversiveSubstituteToEndOfLine)
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

" git-lens.vim {
vim9cmd g:GIT_LENS_ENABLED = true
vim9cmd g:GIT_LENS_CONFIG = {
	blame_delay: 200,
}
" }

" vim-signature {
" Highlight mark a-zA-Z
highlight SignatureMarkText cterm=bold ctermfg=154 gui=bold guifg=#A6E22E

" Highlight marker !@#$%^&*()
highlight SignatureMarkerText term=bold cterm=bold ctermfg=197 gui=bold guifg=#F92672

let g:SignatureMarkTextHLDynamic = 1
let g:SignatureMarkerTextHLDynamic = 1
" }

" vim-lsp {
" Do it by ale
let g:lsp_diagnostics_enabled = 0
let g:lsp_document_code_action_signs_enabled = 0
let g:lsp_completion_documentation_enabled = 1
let g:lsp_preview_autoclose = 0

function! OnLspBufferEnabled()
	setlocal signcolumn=yes
	setlocal omnifunc=lsp#complete
	if exists('+tagfunc')
		setlocal tagfunc=lsp#tagfunc
	endif

	nnoremap <silent><buffer>gd <plug>(lsp-definition)
	nnoremap <silent><buffer>gc <plug>(lsp-declaration)
	nnoremap <silent><buffer>gt <plug>(lsp-type-definition)
	nnoremap <silent><buffer>gi <plug>(lsp-implementation)
	nnoremap <silent><buffer>gr <plug>(lsp-references)
	nnoremap <silent><buffer>gh <plug>(lsp-hover)

	nnoremap <silent><buffer><Leader>gd <plug>(lsp-peek-definition)
	nnoremap <silent><buffer><Leader>gc <plug>(lsp-peek-declaration)
	nnoremap <silent><buffer><Leader>gt <plug>(lsp-peek-type-definition)
	nnoremap <silent><buffer><Leader>gi <plug>(lsp-peek-implementation)

	nnoremap <silent><buffer><Leader>rn <plug>(lsp-rename)
	" nnoremap <buffer><expr><C-u> lsp#scroll(-7)
	" nnoremap <buffer><expr><C-d> lsp#scroll(+7)
endfunction

augroup LspInstall
	autocmd!

	autocmd User lsp_buffer_enabled call OnLspBufferEnabled()
augroup END
" }

" ale {
let g:ale_sign_column_always = 0
let g:ale_sign_error = 'E>'
let g:ale_sign_warning = 'W>'
let g:ale_echo_msg_error_str = 'Error'
let g:ale_echo_msg_warning_str = 'Warning'
let g:ale_echo_msg_format = '[%linter%] %s'
let g:ale_statusline_format = ['%d error(s)', '%d warning(s)', '']
let g:airline#extensions#ale#enabled = 0
let g:ale_lsp_show_message_severity = 'warning'
let g:ale_lint_on_insert_leave = 0
let g:ale_lint_on_enter = 1
let g:ale_lint_on_save = 1
let g:ale_lint_on_text_changed = 0
let g:ale_set_loclist = 1
let g:ale_set_quickfix = 0
let g:ale_open_list = 0
let g:ale_keep_list_window_open = 0
let g:ale_completion_enabled = 0
" }

" lightline-ale {
let g:lightline#ale#indicator_checking = 'Linting...'
let g:lightline#ale#indicator_warnings = 'Warning: '
let g:lightline#ale#indicator_errors = 'Errors: '
let g:lightline#ale#indicator_ok = 'OK'
" }

" vim-autoformat {
" Execute Autoformat onsave
augroup AutoFormat
	autocmd!

	autocmd BufWritePre * :Autoformat
	" autocmd BufWritePre * :LspDocumentFormat
augroup END

" Disable autoindent
let g:autoformat_autoindent = 0

" Disable auto retab
let g:autoformat_retab = 0

" Disable auto remove trailing spaces
let g:autoformat_remove_trailing_spaces = 0

" Generic C, C++, Objective-C style
" A style similar to the Linux Kernel Coding Style
" Linux Kernel Coding Style: https://www.kernel.org/doc/Documentation/CodingStyle
let g:formatdef_clangformat = "'clang-format -style=\"{BasedOnStyle: LLVM, IndentWidth: 8, UseTab: Always, BreakBeforeBraces: Linux, AllowShortIfStatementsOnASingleLine: false, IndentCaseLabels: false}\"'"

" Golang
let g:formatters_go = ['goimports', 'gofumpt']
let g:run_all_formatters_go = 1

" Markdown
let g:formatdef_remark_markdown = "\"remark --silent --no-color --setting 'fences: true, listItemIndent: \\\"1\\\"'\""
" }

" vim-better-whitespace {
let g:better_whitespace_filetypes_blacklist = ['diff', 'git', 'gitcommit', 'qf', 'help']

nnoremap <silent><Leader><Space> :StripWhitespace<CR>
" }

" asyncrun.vim {
let g:asyncrun_exit = 'echohl WarningMsg | echo "AsyncRun finished!" | echohl None'

nnoremap <F4> :AsyncRun<Space>

" Asynchronous Make command
command! -bang -nargs=* -complete=file Make AsyncRun -program=make @ <args>
" }

" vim-markdown {
" tpope/vim-markdown
" Don't need to install these if you are running a recent version of Vim
let g:markdown_syntax_conceal = 0
let g:markdown_minlines = 100
let g:markdown_fenced_languages = ['c', 'cpp', 'go', 'python', 'lua', 'bash=sh', 'vim', 'sql', 'json']
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
