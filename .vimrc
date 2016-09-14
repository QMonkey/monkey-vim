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
	let path = '/.vim/autoload/plug.vim'
	if has('win32') || has('win64')
		let path = '\.vim\autoload\plug.vim'
	endif

	silent execute '!curl' '-fLo' $HOME . path '--create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'
	autocmd VimEnter * PlugInstall | source $MYVIMRC
endif
" }

" vim-plug {
" Time limit of each task in seconds
let g:plug_timeout = 600
" }

" Windows {
if has('win32') || has('win64')
	" Use forward slash as path separator
	set shellslash

	" On Windows, also use '.vim' instead of 'vimfiles'; this makes synchronization across systems easier
	set runtimepath=$HOME/.vim,$VIM/vimfiles,$VIMRUNTIME,$HOME/.vim/after,$VIM/vimfiles/after
endif
" }

set nocompatible
filetype off

call plug#begin($HOME . '/.vim/bundle')

" Plugins {
Plug 'tomasr/molokai'
Plug 'nathanaelkane/vim-indent-guides'
Plug 'scrooloose/nerdtree' | Plug 'jistr/vim-nerdtree-tabs'
Plug 'majutsushi/tagbar'
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
Plug 'scrooloose/syntastic'
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
Plug 'QMonkey/vim-bbye', {'on': 'Bdelete'}
Plug 'octol/vim-cpp-enhanced-highlight', {'for': ['c', 'cpp']}
Plug 'fatih/vim-go', {'for': 'go'}
Plug 'artur-shaik/vim-javacomplete2', {'for': 'java'}
Plug 'pangloss/vim-javascript', {'for': 'javascript'}
Plug 'hdima/python-syntax', {'for': 'python'}
Plug 'xolox/vim-lua-ftplugin', {'for': 'lua'}
Plug 'vim-ruby/vim-ruby', {'for': 'ruby'}
Plug 'tpope/vim-rails', {'for': 'ruby'}
Plug 'StanAngeloff/php.vim', {'for': 'php'}
Plug 'shawncplus/phpcomplete.vim', {'for': 'php'}
Plug 'tpope/vim-markdown', {'for': 'markdown'}
Plug 'suan/vim-instant-markdown', {'for': 'markdown', 'on': 'InstantMarkdownPreview'}
Plug 'cespare/vim-toml', {'for': 'toml'}
Plug 'moskytw/nginx-contrib-vim', {'for': 'nginx'}

if has('mac') || has('macunix')
	Plug 'rizzatti/dash.vim'
else
	Plug 'KabbAmine/zeavim.vim'
endif

if has('win32') || has('win64')
	Plug 'kkoenig/wimproved.vim'
endif
" }

" Add plugins to &runtimepath
call plug#end()

filetype plugin indent on

" Leader {
let mapleader = ','
" }

" Encoding {
language message en_US.UTF-8
set langmenu=en_US.UTF-8

scriptencoding utf-8
set encoding=utf-8

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
if !exists('g:loaded_matchit') && findfile('plugin/matchit.vim', &rtp) ==# ''
	runtime! macros/matchit.vim
endif

" FileType {
augroup FileTypeGroup
	autocmd!

	autocmd FileType python,markdown setlocal expandtab tabstop=4 shiftwidth=4 softtabstop=4
	autocmd FileType javascript,json,ruby setlocal expandtab tabstop=2 shiftwidth=2 softtabstop=2

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

	normal G
	normal o
	normal o
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
		execute 'nnoremap <silent><buffer><S-k> :execute "' . reference . '" GetCurrentWord()<CR>'

		" Enable reference in visual-mode
		execute 'vnoremap <silent><buffer><S-k> <ESC>:execute "' . reference . '" GetVisualSelection()<CR>'

		let is_reference_set = 1
	endfor

	if !is_reference_set
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
	let selection = ''
	try
		let a_save = @a
		normal! gv"ay
		let selection = @a
	finally
		let @a = a_save
	endtry
	return selection
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
		let dash_command = 'Dash'

		let ftype = Prompt('Docset: ', &filetype)
		if empty(ftype)
			let dash_command = 'Dash!'
		endif
		call Clear()

		let prompt_text = 'Dash (' . ftype . ")\n" . 'Search for: '
		let key = Prompt(prompt_text)

		execute dash_command key ftype
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
			\   'right': [ [ 'syntastic', 'lineinfo' ], ['percent'], [ 'filetype', 'fileencoding', 'fileformat' ] ]
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
			\   'syntastic': 'SyntasticStatuslineFlag',
			\ },
			\ 'component_type': {
			\   'syntastic': 'error',
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
	return &filetype =~ 'help' ? '' : &modified ? '+' : &modifiable ? '' : '-'
endfunction

function! LightLineReadonly()
	return &filetype !~? 'help' && &readonly ? "\ue0a2" : ''
endfunction

function! LightLineFilename()
	let fname = expand('%:t')
	if fname ==# 'CtrlSpace'
		return ctrlspace#api#StatuslineModeSegment('')
	endif

	if GetWindowType() != 0
		return ''
	endif

	return fname == 'ControlP' && has_key(g:lightline, 'ctrlp_item') ? g:lightline.ctrlp_item :
				\ fname == '__Tagbar__' ? '' :
				\ fname =~ 'NERD_tree' ? '' :
				\ ('' != LightLineReadonly() ? LightLineReadonly() . ' ' : '') .
				\ ('' != fname ? fname : '[No Name]') .
				\ ('' != LightLineModified() ? ' ' . LightLineModified() : '')
endfunction

function! GetBufferListOutputAsOneString()
	let buffer_list = ''
	redir =>> buffer_list
	ls
	redir END
	return buffer_list
endfunction

function! IsLocationListBuffer()
	if &filetype != 'qf'
		return 0
	endif

	silent let buffer_list = GetBufferListOutputAsOneString()

	let l:quickfix_match = matchlist(buffer_list,
				\ '\n\s*\(\d\+\)[^\n]*Quickfix List')
	if empty(l:quickfix_match)
		return 1
	endif
	let quickfix_bufnr = l:quickfix_match[1]
	return quickfix_bufnr == bufnr('%') ? 0 : 1
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

	let fname = expand('%:t')
	let plugins = ['\[Plugins\]', 'NERD_tree', 'Tagbar', 'ControlP', 'CtrlSpace']

	if fname ==# ''
		return 0
	endif

	for plugin in plugins
		if fname =~ plugin
			return 0
		endif
	endfor

	let git_dir = fugitive#extract_git_dir(expand('%'))
	if git_dir ==# ''
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

	let summary = GitGutterGetHunkSummary()
	return printf('+%d ~%d -%d', summary[0], summary[1], summary[2])
endfunction

function! LightLineFugitive()
	if GetWindowType() != 0
		return ''
	endif

	if !IsGitFile()
		return ''
	endif

	try
		let mark = "\ue0a0 "
		let branch = fugitive#head()
		return branch !=# '' ? mark.branch : ''
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
	return winwidth(0) > 70 ? printf("%3d%%", (100 * line('.') / line('$'))) : ''
endfunction

function! LightLineLineInfo()
	return winwidth(0) > 70 ? printf("%3d/%-d :%-2d", line('.'), line('$'), col('.')) : ''
endfunction

function! LightLineMode()
	let fname = expand('%:t')
	let window_type = GetWindowType()
	if fname !=# 'CtrlSpace' && window_type != 0
		return window_type == 3 ? 'Preview' :
					\ window_type == 2 ? 'Quickfix' :
					\ window_type == 1 ? 'Location' : ''
	endif

	return fname == '__Tagbar__' ? 'Tagbar' :
				\ fname == 'ControlP' ? 'CtrlP' :
				\ fname == 'CtrlSpace' ? 'CtrlSpace' :
				\ fname =~ 'NERD_tree' ? 'NERDTree' :
				\ winwidth(0) > 60 ? lightline#mode() : ''
endfunction

function! CtrlPMark()
	if expand('%:t') =~ 'ControlP' && has_key(g:lightline, 'ctrlp_item')
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

let g:tagbar_status_func = 'TagbarStatusFunc'

function! TagbarStatusFunc(current, sort, fname, ...) abort
	let g:lightline.fname = a:fname
	return lightline#statusline(0)
endfunction

augroup AutoSyntastic
	autocmd!

	autocmd BufReadPost,BufWritePost * if &filetype isnot# 'go' | call s:syntastic() | endif
augroup END

function! s:syntastic()
	SyntasticCheck
	call lightline#update()
endfunction
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

" vim-indent-guides {
let g:indent_guides_enable_on_vim_startup = 1
let g:indent_guides_start_level = 2
let g:indent_guides_guide_size = 1
let g:indent_guides_tab_guides = 0
let g:indent_guides_exclude_filetypes = ['diff', 'man', 'help', 'git', 'gitcommit', 'qf', 'nerdtree', 'tagbar']
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
	put!=repeat(nr2char(10), a:count)
	']+1
	silent! call repeat#set("\<Plug>BlankUp", a:count)
endfunction

function! BlankDown(count)
	put =repeat(nr2char(10), a:count)
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
	let last_winnr = winnr('#')
	let window_type = GetWindowType()

	quit

	if window_type == 2
		silent! execute last_winnr . 'wincmd w'
	endif
endfunction

function! QuitWindow()
	if tabpagenr('$') > 1
		call Quit()
		return
	endif

	let max_winnr = winnr('$')
	if max_winnr == 1 || max_winnr > 3
		call Quit()
		return
	endif

	if max_winnr == 2 && (!exists('g:NERDTree') || !g:NERDTree.IsOpen())
		call Quit()
		return
	endif

	if max_winnr == 3
		if !exists('g:NERDTree') || !g:NERDTree.IsOpen()
			call Quit()
			return
		endif

		let tagbar_winnr = bufwinnr('__Tagbar__')
		if tagbar_winnr < 0
			call Quit()
			return
		endif
	endif

	" If NERDTreeTabs is opend, only call quitall can save the session
	quitall
endfunction
" }

" Buffer {
nnoremap <silent><Leader>d :Bdelete<CR>
nnoremap <silent><Leader>o :execute 'edit' Prompt('New buffer name: ', '', 'file')<CR>

nnoremap <silent>[b :bprevious<CR>
nnoremap <silent>]b :bnext<CR>

" Netrw style
nnoremap <silent>- :execute 'edit' expand('%:p:h')<CR>
nnoremap <silent>~ :execute 'edit' GetRootPath()<CR>

function! GetRootPath()
	let root_path = FindRootDirectory()
	if root_path ==# ''
		let root_path = expand('%:p:h')
	endif
	return root_path
endfunction
" }

" Tab {
nnoremap <silent><Leader>t :execute 'tabnew' Prompt('New tab name: ', '', 'file')<CR>
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
nnoremap <silent><Leader>s :execute 'new' Prompt('New split name: ', '', 'file')<CR>
nnoremap <silent><Leader>v :execute 'vnew' Prompt('New vsplit name: ', '', 'file')<CR>

nnoremap <Up> <C-w>+
nnoremap <Down> <C-w>-
nnoremap <Left> <C-w>>
nnoremap <Right> <C-w><
" }

" F2 ~ F10 {
nnoremap <silent><F2> :call BetterNERDTreeTabsToggle()<CR>
nnoremap <silent><F3> :TagbarToggle<CR>
nnoremap <silent><F7> :Dispatch!<CR>
nnoremap <silent><F8> :call QListToggle('Copen!')<CR>
nnoremap <silent><F9> :QuickRun<CR>
nnoremap <silent><F10> :InstantMarkdownPreview<CR>

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
	let selection = GetVisualSelection()
	let @/ = '\V' . substitute(escape(selection, '\'), '\n', '\\n', 'g')
endfunction
" }

" No highlight search
nnoremap <silent><Leader>/ :nohlsearch<CR>

" QuickFix {
function! QListToggle(cmd)
	let ftype = &filetype
	let last_winnr = winnr('#')
	let buffer_count_before = BufferCount()
	silent! cclose

	if BufferCount() == buffer_count_before
		execute a:cmd
	else
		if ftype is 'qf'
			silent! execute last_winnr . 'wincmd w'
		endif
	endif
endfunction

function! LListToggle(cmd)
	let buffer_count_before = BufferCount()
	silent! lclose

	if BufferCount() == buffer_count_before
		execute a:cmd
	endif
endfunction

function! BufferCount()
	return len(filter(range(1, bufnr('$')), 'buflisted(v:val)'))
endfunction

let list_height = 10
nnoremap <silent><Leader>q :call QListToggle('silent! botright copen '. list_height)<CR>
nnoremap <silent><Leader>l :call LListToggle('silent! lopen '. list_height)<CR>
" }

" QFEnter {
let g:qfenter_open_map = ['<CR>']
let g:qfenter_vopen_map = ['v']
let g:qfenter_hopen_map = ['s']
let g:qfenter_topen_map = ['t']
" }

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

	let search = substitute(escape(word, '/\.*$^~['), '\n', '\\n', 'g')
	if wholeword
		let search = '\<' . search . '\>'
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

	execute ',$s/' . search . '/' . replace . '/' . flag . "| silent 1,'' -&& | update"
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
			\ 'file': '\v\.(o|obj|so|dll|exe|pyc|pyo|swo|swp)$',
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

if executable("ag")
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
"let g:rooter_use_lcd = 1

" Do it manually, or it will cause CtrlSpace's workspace cannot save other project's file.
let g:rooter_manual_only = 1

nnoremap <silent><Leader>cd :Rooter<CR>
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
" }

" NERDTree {
" Set NERDTree window width
let g:NERDTreeWinSize = 32
let g:NERDTreeHijackNetrw = 1
let NERDTreeAutoDeleteBuffer = 1
let NERDTreeMinimalUI = 1
let g:NERDTreeMapOpenSplit = 's'
let g:NERDTreeMapOpenVSplit = 'v'

" Show hidden
let NERDTreeShowHidden = 1
" Ignore files
let NERDTreeIgnore = ['\.o$', '\.obj$', '\.so$', '\.dll$', '\.exe$', '\.py[co]$', '\~$', '\.swo$', '\.swp$', '^\.git$', '^\.hg$', '^\.svn$', '\.bzr$']

" Don't open NERDTreeTabs automatically when vim starts up
let g:nerdtree_tabs_open_on_gui_startup = 0
let g:nerdtree_tabs_open_on_console_startup = 0

" Don't synchronize view of all NERDTree windows (scroll and cursor position)
let g:nerdtree_tabs_synchronize_view = 0

" Close vim if the only window left open is a NERDTreeTabs
let g:nerdtree_tabs_autoclose = 1

" Show current file in NERDTree
nnoremap <silent><Leader>f :NERDTreeFind<CR>

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

" Tagbar {
let g:tagbar_width = 32
let g:tagbar_compact = 1
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
	let g:ycm_global_ycm_extra_conf = $HOME . '/.vim/bundle/YouCompleteMe/third_party/ycmd/cpp/ycm/.ycm_extra_conf.py'
endif

" Do not use YouCompleteMe to check C, C++ and Objective-C, do it by syntastic
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

let ycm_go_to_definition_filetypes = ['c', 'cpp', 'go', 'javascript', 'python']

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

" Syntastic {
let g:syntastic_loc_list_height = 10
let g:syntastic_error_symbol = "\u2716"
let g:syntastic_style_error_symbol = "\u2716"
let g:syntastic_warning_symbol = '!'
let g:syntastic_style_warning_symbol = '!'
let g:syntastic_always_populate_loc_list = 0
let g:syntastic_auto_loc_list = 0
let g:syntastic_check_on_open = 1
let g:syntastic_check_on_wq = 0
let g:syntastic_enable_highlighting = 1
let g:syntastic_go_checkers = ['golint', 'govet', 'errcheck']
let g:syntastic_python_checkers = ['pyflakes']
let g:syntastic_mode_map = {'mode': 'passive'}

nnoremap <silent><Leader>e :call LListToggle('Errors')<CR>
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
let g:godef_split = 2
let g:godef_same_file_in_same_window = 1
let g:go_def_mapping_enabled = 0
let g:go_list_type = "quickfix"

augroup GolangKeymap
	autocmd!

	" Use Ctrl-o to jump back, see :help jumplist
	autocmd FileType go nmap <silent><buffer>gd <Plug>(go-def)
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

" vim-instant_markdown {
let g:instant_markdown_slow = 1
let g:instant_markdown_autostart = 0
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
