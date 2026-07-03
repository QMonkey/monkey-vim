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

	augroup Init
		autocmd!

		autocmd VimEnter * PlugInstall | source $MYVIMRC
		autocmd VimEnter * call mkdir($HOME . '/.vim/swap/', 'p') | call InitClangFormat()
	augroup END
endif

function! InitClangFormat()
	let l:clang_format = $HOME . '/.clang-format'
	if filereadable(l:clang_format)
		return
	endif
	let l:lines = [
				\ 'BasedOnStyle: LLVM',
				\ 'IndentWidth: 8',
				\ 'UseTab: Always',
				\ 'BreakBeforeBraces: Linux',
				\ 'AllowShortIfStatementsOnASingleLine: false',
				\ 'IndentCaseLabels: false'
				\ ]
	call writefile(l:lines, l:clang_format)
endfunction
" }

" vim-plug {
" Time limit of each task in seconds
let g:plug_timeout = 300
" }

call plug#begin(expand($HOME . '/.vim/bundle'))

" Plugins {
Plug 'tomasr/molokai'
Plug 'itchyny/lightline.vim'
Plug 'Yggdroot/LeaderF', {'do': ':LeaderfInstallCExtension'}
Plug 'dyng/ctrlsf.vim'
Plug 'mg979/vim-visual-multi'
Plug 'justinmk/vim-dirvish'
Plug 'tpope/vim-obsession'
Plug 'monkoose/vim9-stargate'
Plug 'wellle/targets.vim'
Plug 'michaeljsmith/vim-indent-object'
Plug 'svermeulen/vim-subversive'
Plug 'Konfekt/FastFold'
Plug 'haya14busa/vim-asterisk'
Plug 'skywind3000/asyncrun.vim'
Plug 'airblade/vim-rooter'
Plug 'ludovicchabant/vim-gutentags'
Plug 'yegappan/lsp'
Plug 'hrsh7th/vim-vsnip' | Plug 'hrsh7th/vim-vsnip-integ' | Plug 'rafamadriz/friendly-snippets'
Plug 'tpope/vim-fugitive' | Plug 'junegunn/gv.vim', {'on': 'GV'}
Plug 'airblade/vim-gitgutter'
Plug 'tpope/vim-surround'
Plug 'tpope/vim-repeat'
Plug 'cohama/lexima.vim'
Plug 'andymass/vim-matchup'
Plug 'kshenoy/vim-signature'
Plug 'tpope/vim-eunuch'
Plug 'romainl/vim-qf'
" }

" Add plugins to &runtimepath
call plug#end()

" Builtin packages {
silent! packadd! comment
silent! packadd! hlyank
silent! packadd! nohlsearch

" Enable 'Man' command
source $VIMRUNTIME/ftplugin/man.vim

" Disable netrw
let g:loaded_netrw = 1
let g:loaded_netrwPlugin = 1
" }

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
	autocmd WinEnter,InsertLeave * set relativenumber
	autocmd WinLeave,InsertEnter * set norelativenumber number
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

" Swap file directory
set directory=$HOME/.vim/swap//

" Make the jumplist behave like the tagstack
set jumpoptions+=stack

" Share vim clipboard with system clipboard
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
set listchars=tab:▸\ ,leadmultispace:│\ \ \ ,eol:¬,trail:·

" Restore cursor to previous editing position
augroup RestoreCursorPosition
	autocmd!

	autocmd BufReadPost * if line("'\"") > 1 && line("'\"") <= line("$") | execute "normal! g'\"" | endif
augroup END

" Clear jumplist on vim startup
augroup Jumplist
	autocmd!

	autocmd VimEnter * :clearjumps
augroup END

" FileType {
augroup FileTypeGroup
	autocmd!

	autocmd FileType python,markdown setlocal expandtab tabstop=4 shiftwidth=4 softtabstop=4
	autocmd FileType json,yaml setlocal expandtab tabstop=2 shiftwidth=2 softtabstop=2
	autocmd FileType javascript,typescript setlocal expandtab tabstop=2 shiftwidth=2 softtabstop=2

	autocmd BufNewFile *.sh,*.py call AutoInsertFileHead()

	" Move the quickfix window to the bottom of the window layout
	autocmd FileType qf wincmd J
augroup END

function! AutoInsertFileHead()
	" Shell
	if &filetype ==# 'sh'
		call setline(1, '#!/bin/bash')
		call cursor(line('$'), 0)
		put = ''
	endif

	" Python
	if &filetype ==# 'python'
		call setline(1, '#!/usr/bin/env python3')
		call cursor(line('$'), 0)
		put = repeat(nr2char(10), 2)
	endif

	call cursor(line('$'), 0)
endfunc
" }

" Docset {
augroup Docset
	autocmd!

	autocmd FileType man,help setlocal nolist

	" Use :LspHover as the default docset
	autocmd FileType * setlocal keywordprg=:LspHover
	autocmd FileType c,man setlocal keywordprg=:Man
	autocmd FileType vim,help setlocal keywordprg=:help
augroup END
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

" Disable fold on startup
set nofoldenable
set foldmethod=syntax
set foldlevel=99

" Use indent style fold for python and yaml
augroup LanguageFold
	autocmd!

	autocmd FileType python,yaml setlocal foldmethod=indent
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

" Enable mouse in normal, visual and insert mode
set mouse=nvi

" Only if there are at least two tab pages
set showtabline=1

" Always show status line
set laststatus=2

" lightline.vim {
let g:lightline = {
			\ 'colorscheme': 'powerline',
			\ 'active': {
			\   'left': [['mode', 'paste'], ['vminfo', 'gitinfo', 'filename']],
			\   'right': [['lineinfo'], ['percent'], ['filetype', 'fileencoding', 'fileformat']]
			\ },
			\ 'inactive': {
			\   'left': [['mode', 'filename']],
			\   'right': []
			\ },
			\ 'component_function': {
			\   'gitinfo': 'LightLineGitInfo',
			\   'vminfo': 'LightLineVMInfo',
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
			\ },
			\ 'separator': {'left': '', 'right': ''},
			\ 'subseparator': {'left': '│', 'right': '│'},
			\ 'tab': {
			\   'active': ['filename', 'modified'],
			\   'inactive': ['filename', 'modified'],
			\ },
			\ 'tabline': {
			\   'left': [['tabs']],
			\   'right': []
			\ },
			\ 'tabline_separator': {'left': '', 'right': ''},
			\ 'tabline_subseparator': {'left': '│', 'right': '│'},
			\ }

function! s:LightLineModified()
	return &filetype =~# 'help' ? '' : &modified ? '+' : &modifiable ? '' : '-'
endfunction

function! s:LightLineReadonly()
	return &filetype !~? 'help' && &readonly ? '🔒' : ''
endfunction

" Cached window type: returns 0=normal, 1=location, 2=quickfix, 3=preview
" Result is stored in w:window_type to avoid recomputation within the same
" statusline refresh cycle. Invalidated on BufWinEnter/WinEnter.
function! s:GetWindowType()
	if exists('w:window_type')
		return w:window_type
	endif
	if &previewwindow
		let w:window_type = 3
	elseif &filetype is# 'qf'
		let l:cur_winnr = winnr()
		if qf#IsQfWindow(l:cur_winnr)
			let w:window_type = 2
		elseif qf#IsLocWindow(l:cur_winnr)
			let w:window_type = 1
		else
			let w:window_type = 0
		endif
	else
		let w:window_type = 0
	endif
	return w:window_type
endfunction

" Cached git file detection. Result is stored in b:is_git_file,
" invalidated on BufEnter.
function! s:IsGitFile()
	if exists('b:is_git_file')
		return b:is_git_file
	endif
	let b:is_git_file = 0
	if !exists('g:loaded_gitgutter') || !exists('g:loaded_fugitive')
		return 0
	endif
	let l:fname = expand('%:t')
	if l:fname ==# '' || l:fname =~# '\[Plugins\]'
		return 0
	endif
	if FugitiveExtractGitDir(resolve(expand('%'))) ==# ''
		return 0
	endif
	let b:is_git_file = 1
	return 1
endfunction

" Invalidate per-buffer and per-window caches
augroup LightLineCache
	autocmd!
	autocmd BufEnter * unlet! b:is_git_file
	autocmd BufWinEnter,WinEnter * unlet! w:window_type
augroup END

" Combined git status component: gutter summary + branch name.
" Replaces LightLineGitGutter & LightLineFugitive; avoids calling
" s:GetWindowType() / s:IsGitFile() / FugitiveExtractGitDir() twice.
function! LightLineGitInfo()
	if s:GetWindowType() != 0
		return ''
	endif
	if !s:IsGitFile()
		return ''
	endif
	let l:parts = []
	try
		let l:s = GitGutterGetHunkSummary()
		call add(l:parts, printf('+%d ~%d -%d', l:s[0], l:s[1], l:s[2]))
	catch
	endtry
	try
		if getftype(expand('%')) ==# 'link'
			call FugitiveDetect(resolve(expand('%')))
		endif
		let l:branch = FugitiveHead()
		if l:branch !=# ''
			call add(l:parts, "⎇ " . l:branch)
		endif
	catch
	endtry
	return join(l:parts, ' ')
endfunction

function! LightLineFilename()
	if s:GetWindowType() != 0
		return ''
	endif
	let l:ro = s:LightLineReadonly()
	let l:mod = s:LightLineModified()
	let l:fname = expand('%:t')
	if l:fname ==# ''
		let l:fname = '[No Name]'
	endif
	return join(filter([l:ro, l:fname, l:mod], 'v:val !=# ""'), ' ')
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
	let l:window_type = s:GetWindowType()
	if l:window_type != 0
		return l:window_type == 3 ? 'Preview' :
					\ l:window_type == 2 ? 'Quickfix' :
					\ l:window_type == 1 ? 'Location' : ''
	endif

	if exists('b:VM_Selection') && !empty(b:VM_Selection)
		return 'VM'
	endif

	return winwidth(0) > 60 ? lightline#mode() : ''
endfunction
" }

" vim-visual-multi lightline integration {
highlight VM_Mode cterm=bold ctermfg=232 ctermbg=141 gui=bold guifg=#1a1b26 guibg=#bb9af7
highlight VM_Info ctermfg=141 ctermbg=236 guifg=#bb9af7 guibg=#3b3f54

function! LightLineVMInfo()
	if s:GetWindowType() != 0
		return ''
	endif
	if !exists('b:VM_Selection') || empty(b:VM_Selection)
		return ''
	endif
	let l:vm = VMInfos()
	if empty(l:vm)
		return ''
	endif
	let l:result = l:vm.ratio
	if !empty(@/)
		let l:result .= '  /' . @/
	endif
	return l:result
endfunction

let s:saved_normal_left = []
function! s:VM_Enter()
	let s:saved_normal_left = copy(g:lightline#colorscheme#powerline#palette.normal.left[0])
	let g:lightline#colorscheme#powerline#palette.normal.left[0] = ['#1a1b26', '#bb9af7', 232, 141, 'bold']
	call lightline#highlight()
	call lightline#update()
endfunction

function! s:VM_Leave()
	if !empty(s:saved_normal_left)
		let g:lightline#colorscheme#powerline#palette.normal.left[0] = s:saved_normal_left
		let s:saved_normal_left = []
	endif
	call lightline#highlight()
	call lightline#update()
endfunction

augroup VMLightLine
	autocmd!
	autocmd User visual_multi_start silent call s:VM_Enter()
	autocmd User visual_multi_exit  silent call s:VM_Leave()
augroup END
" }

" Color support {
" Use true color when the terminal supports it
if has('termguicolors')
	set termguicolors
endif

if &termguicolors
" True color: Vim renders GUI colors (guifg/guibg) directly
else
	" Fallback: 256-color mode for terminals without true color support
	set t_Co=256

	" Disable Background Color Erase (BCE) so that color schemes
	" render properly when inside 256-color tmux and GNU screen.
	" See http://snk.tuxfamily.org/log/vim-256color-bce.html
	if &term =~# '256color'
		set t_ut=
	endif
endif
" }

" molokai {
" Should be set before :colorscheme
let g:molokai_original = 1
if !&termguicolors
	" Rehash 256-color palette for better approximation of GUI colors.
	" Not needed when termguicolors is on, since true GUI colors are used.
	let g:rehash256 = 1
endif

set background=dark
colorscheme molokai
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

" Better insert mode moving and editing
inoremap <C-p> <Up>
inoremap <C-n> <Down>
inoremap <C-b> <Left>
inoremap <C-f> <Right>
inoremap <C-a> <Home>
inoremap <C-e> <End>
inoremap <C-h> <BackSpace>
inoremap <C-d> <Del>

" Better command mode moving and editing
cnoremap <C-p> <Up>
cnoremap <C-n> <Down>
cnoremap <C-b> <Left>
cnoremap <C-f> <Right>
cnoremap <C-a> <Home>
cnoremap <C-e> <End>
cnoremap <C-h> <BackSpace>
cnoremap <C-d> <Del>

nnoremap <silent>q :call Quit()<CR>
nnoremap <silent><S-q> :quitall<CR>

nnoremap t q
vnoremap t q

function! Quit()
	let l:last_winnr = winnr('#')
	let l:window_type = s:GetWindowType()

	quit

	if l:window_type == 1 || l:window_type == 2
		if win_id2win(win_getid(l:last_winnr))
			silent! execute l:last_winnr . 'wincmd w'
		endif
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
nnoremap <silent>con :nohl<CR>
nnoremap <silent><Leader><Space> :%s/\s\+$//e<CR>:nohl<CR>
" <Leader><Leader><Space>: strip trailing whitespace + \r (DOS newline)
nnoremap <silent><Leader><Leader><Space> :%s/\s\+$//e<CR>:%s/\r$//e<CR>:nohl<CR>

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
nnoremap <silent>- :execute 'Dirvish' expand('%:p:h')<CR>
nnoremap <silent>~ :execute 'Dirvish' GetProjectOrHome()<CR>

function! GetFileroot()
	let l:root = FindRootDirectory()
	if l:root ==# ''
		let l:root = expand('%:p:h')
	endif
	return l:root
endfunction

function! GetProjectOrHome()
	let l:root = FindRootDirectory()
	return l:root !=# '' ? l:root : expand('~')
endfunction

augroup SplitExplorer
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

" vim-asterisk {
map *  <Plug>(asterisk-z*)
map g* <Plug>(asterisk-gz*)
map #  <Plug>(asterisk-z#)
map g# <Plug>(asterisk-gz#)
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
	let l:value = call('Prompt', [a:prompt_text] + a:000)
	if l:value ==# ''
		let l:value = '%'
	endif
	return l:value
endfunction

" Session {
set sessionoptions-=blank sessionoptions-=options sessionoptions-=folds sessionoptions-=terminal

function! GetSessionFileInfo()
	let l:session_dir = expand($HOME . '/.cache/sessions/')
	let l:session_filename = l:session_dir . substitute(trim(GetFileroot(), '/', 1), '/', '-', 'g') . '-session.vim'
	return [l:session_dir, l:session_filename]
endfunction

function! BackupSession()
	let l:session_info = GetSessionFileInfo()
	let l:session_dir = l:session_info[0]
	let l:session_filename = l:session_info[1]
	call mkdir(l:session_dir, 'p')
	execute 'Obsession' l:session_filename
endfunction

function! RestoreSession()
	let l:session_info = GetSessionFileInfo()
	let l:session_filename = l:session_info[1]
	if argc() == 0 && filereadable(l:session_filename)
		execute 'source' l:session_filename
	endif
endfunction

" Backup
nnoremap <Leader>bs :call BackupSession()<CR>
" Remove
nnoremap <Leader>rs :Obsession!<CR>

augroup Session
	autocmd!

	autocmd VimEnter * nested call RestoreSession()
augroup END
" }

" LeaderF {
let g:Lf_PythonVersion = 3
let g:Lf_ShortcutF = '<C-p>'
let g:Lf_ShortcutB = '<C-m>'
let g:Lf_WindowPosition = 'popup'
let g:Lf_ShowDevIcons = 0
let g:Lf_StlColorscheme = 'powerline'
let g:Lf_StlSeparator = {'left': '', 'right': ''}
let g:Lf_Ctags = 'ctags --fields=+liaS --extras=+q --langmap=c:.c.h,vim:.vim.vimrc'
" Suppress qualified tags in function/buftag views so each function
" appears exactly once (--extras=+q in g:Lf_Ctags would otherwise emit
" both "helper" and "main.helper" for every Go function).
let g:Lf_CtagsFuncOpts = {
			\ 'go': '--go-kinds=f --extras=-q',
			\}
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
let g:VM_maps = {}
let g:VM_maps['Select Operator'] = 'gs'
let g:VM_set_statusline = 0
let g:VM_silent_exit = 1
" }

" vim9-stargate {
let g:stargate_name = 'QMonkey'

" For 1 character to search before showing hints
noremap f <Cmd>call stargate#OKvim(1)<CR>
" For 2 consecutive characters to search
noremap F <Cmd>call stargate#OKvim(2)<CR>

highlight StargateFocus ctermfg=101 guifg=#958C6A
highlight StargateDesaturate ctermfg=238 guifg=#49423F
highlight StargateError ctermfg=167 guifg=#D35B4B
highlight StargateLabels ctermfg=179 ctermbg=234 guifg=#CAA247 guibg=#171E2C
highlight StargateErrorLabels ctermfg=179 ctermbg=52 guifg=#CAA247 guibg=#551414
highlight StargateMain cterm=bold ctermfg=199 gui=bold guifg=#F2119C
highlight StargateSecondary cterm=bold ctermfg=49 gui=bold guifg=#11EB9C
highlight StargateShip ctermfg=233 ctermbg=234 guifg=#111111 guibg=#CAA247
highlight StargateVIM9000 cterm=bold ctermfg=233 ctermbg=139 gui=bold guifg=#111111 guibg=#B2809F
highlight StargateMessage ctermfg=143 guifg=#A5B844
highlight StargateErrorMessage ctermfg=167 guifg=#E36659
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
let g:rooter_patterns = ['.root', '.git', '.hg', '.svn', '.bzr', '_darcs', '_FOSSIL_', '.fslckout']
let g:rooter_silent_chdir = 1
let g:rooter_change_directory_for_non_project_files = 'current'
let g:rooter_resolve_links = 1
let g:rooter_manual_only = 1

nnoremap <silent><Leader>cr :Rooter<CR>

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
let g:gutentags_modules = ['ctags']
let g:gutentags_project_root = ['.root', '.git', '.hg', '.svn', '.bzr', '_darcs', '_FOSSIL_', '.fslckout']
let g:gutentags_cache_dir = expand($HOME . '/.cache/tags')
let g:gutentags_ctags_tagfile = '.tags'
let g:gutentags_ctags_auto_set_tags = 1
let g:gutentags_ctags_extra_args = [
			\ '--fields=+liaS',
			\ '--extras=+q',
			\ '--langmap=c:.c.h,vim:.vim.vimrc',
			\ '--c-kinds=+p',
			\ '--c++-kinds=+p',
			\ '--python-kinds=+i',
			\]
let g:gutentags_generate_on_missing = 1
let g:gutentags_generate_on_new = 0
let g:gutentags_generate_on_write = 1
let g:gutentags_background_update = 1
let g:gutentags_resolve_symlinks = 1
let g:gutentags_define_advanced_commands = 1
" }

" lexima.vim {
" Default rules handle (), [], {}, "", '', ``, and triple-quote pairs.
" Backspace inside an empty pair deletes both characters.
augroup Lexima
	autocmd!

	" Don't pair double quotes in vim files (vim uses " as comment leader)
	autocmd FileType vim call lexima#add_rule(#{
				\   char: '"',
				\   input: '"',
				\   input_after: '',
				\   filetype: ['vim'],
				\ })
augroup END
" }

" vim-signature {
" Highlight mark a-zA-Z
highlight SignatureMarkText cterm=bold ctermfg=154 gui=bold guifg=#A6E22E

" Highlight marker !@#$%^&*()
highlight SignatureMarkerText term=bold cterm=bold ctermfg=197 gui=bold guifg=#F92672

let g:SignatureMarkTextHLDynamic = 1
let g:SignatureMarkerTextHLDynamic = 1
" }

" lsp {
function! OnLspSetup()
	let l:lspOpts = #{
				\   aleSupport: v:false,
				\   autoComplete: v:true,
				\   autoHighlight: v:true,
				\   autoHighlightDiags: v:true,
				\   autoPopulateDiags: v:false,
				\   completionMatcher: 'case',
				\   completionMatcherValue: 1,
				\   completionTextEdit: v:false,
				\   diagVirtualTextAlign: 'after',
				\   diagVirtualTextWrap: 'truncate',
				\   diagSignErrorText: 'E>',
				\   diagSignHintText: 'H>',
				\   diagSignInfoText: 'I>',
				\   diagSignWarningText: 'W>',
				\   echoSignature: v:false,
				\   hideDisabledCodeActions: v:false,
				\   highlightDiagInline: v:true,
				\   hoverInPreview: v:false,
				\   ignoreMissingServer: v:false,
				\   keepFocusInDiags: v:true,
				\   keepFocusInReferences: v:true,
				\   noNewlineInCompletion: v:false,
				\   omniComplete: v:false,
				\   outlineOnRight: v:false,
				\   outlineWinSize: 20,
				\   popupBorder: v:true,
				\   popupBorderHighlight: 'Title',
				\   popupBorderHighlightPeek: 'Special',
				\   popupBorderSignatureHelp: v:false,
				\   popupHighlightSignatureHelp: 'Pmenu',
				\   popupHighlight: 'Normal',
				\   semanticHighlight: v:true,
				\   showDiagInBalloon: v:true,
				\   showDiagInPopup: v:true,
				\   showDiagOnStatusLine: v:true,
				\   showDiagWithSign: v:true,
				\   showDiagWithVirtualText: v:true,
				\   showInlayHints: v:false,
				\   showSignature: v:true,
				\   snippetSupport: v:true,
				\   ultisnipsSupport: v:false,
				\   useBufferCompletion: v:false,
				\   usePopupInCodeAction: v:false,
				\   useQuickfixForLocations: v:false,
				\   vsnipSupport: v:true,
				\   bufferCompletionTimeout: 100,
				\   customCompletionKinds: v:false,
				\   completionKinds: {},
				\   filterCompletionDuplicates: v:false,
				\   condensedCompletionMenu: v:false,
				\ }

	let l:lspServers = [#{
				\  name: 'clangd',
				\  filetype: ['c', 'cpp'],
				\  path: 'clangd',
				\  args: [
				\    '--background-index',
				\    '--clang-tidy',
				\    '--all-scopes-completion=true',
				\    '--completion-style=detailed',
				\    '--function-arg-placeholders=true',
				\    '--header-insertion=iwyu',
				\    '--header-insertion-decorators'
				\  ]
				\ },
				\#{name: 'rust-analyzer',
				\   filetype: ['rust'],
				\   path: 'rust-analyzer',
				\   args: [],
				\   workspaceConfig: {
				\     'rust-analyzer': {
				\       'checkOnSave': {
				\         'command': 'clippy',
				\       },
				\       'procMacro': {
				\         'enable': v:true,
				\       },
				\       'cargo': {
				\         'allFeatures': v:true,
				\       },
				\     },
				\   },
				\ },
				\#{name: 'gopls',
				\   filetype: ['go', 'gomod', 'gowork', 'gotmpl'],
				\   path: 'gopls',
				\   args: ['serve'],
				\   rootSearch: ['go.work', 'go.mod'],
				\   workspaceConfig: {
				\     'gopls': {
				\       'analyses': {
				\         'nilness': v:true,
				\         'unusedparams': v:true,
				\         'unusedwrite': v:true,
				\         'useany': v:true,
				\       },
				\       'hoverKind': 'FullDocumentation',
				\       'gofumpt': v:true,
				\       'completeUnimported': v:true,
				\       'staticcheck': v:true,
				\       'usePlaceholders': v:true,
				\       'completionDocumentation': v:true,
				\       'codelenses': {
				\         'generate': v:true,
				\         'test': v:true,
				\         'run_vulncheck_exp': v:true,
				\       },
				\       'hints': {
				\         'assignVariableTypes': v:true,
				\         'compositeLiteralFields': v:true,
				\         'compositeLiteralTypes': v:true,
				\         'constantValues': v:true,
				\         'functionTypeParameters': v:true,
				\         'parameterNames': v:true,
				\         'rangeVariableTypes': v:true,
				\       },
				\     },
				\   }
				\ },
				\#{name: 'typescript-language-server',
				\   filetype: ['javascript', 'typescript'],
				\   path: 'typescript-language-server',
				\   args: ['--stdio'],
				\ },
				\ #{name: 'pylsp',
				\   filetype: 'python',
				\   path: 'pylsp',
				\   args: [],
				\   workspaceConfig: {
				\     'pylsp': {
				\       'plugins': {
				\         'pylint': {
				\           'enabled': v:false
				\         },
				\         'rope_autoimport': {
				\           'enabled': v:true,
				\           'completions': {
				\             'enabled': v:true
				\           },
				\           'code_actions': {
				\             'enabled': v:true
				\           }
				\         },
				\       }
				\     }
				\   },
				\ },
				\#{name: 'lua-language-server',
				\   filetype: 'lua',
				\   path: 'lua-language-server',
				\   args: [],
				\ },
				\#{name: 'bash-language-server',
				\   filetype: 'sh',
				\   path: 'bash-language-server',
				\   args: ['start']
				\ },
				\#{name: 'vim-language-server',
				\   filetype: 'vim',
				\   path: 'vim-language-server',
				\   args: ['--stdio']
				\ },
				\#{name: 'marksman',
				\   filetype: ['markdown'],
				\   path: 'marksman',
				\   args: ['server']
				\ },
				\#{name: 'yaml-language-server',
				\   filetype: ['yaml'],
				\   path: 'yaml-language-server',
				\   args: ['--stdio'],
				\ },
				\#{name: 'vscode-json-language-server',
				\   filetype: ['json'],
				\   path: 'vscode-json-language-server',
				\   args: ['--stdio']
				\ }
				\]

	call LspOptionsSet(l:lspOpts)
	call LspAddServer(l:lspServers)
endfunction

function! OnLspAttached()
	setlocal formatexpr=lsp#lsp#FormatExpr()

	nnoremap <silent><buffer>gh :LspHover<CR>

	nnoremap <silent><buffer>gd :LspGotoDefinition<CR>
	nnoremap <silent><buffer>gc :LspGotoDeclaration<CR>
	nnoremap <silent><buffer>gt :LspGotoTypeDef<CR>
	nnoremap <silent><buffer>gi :LspGotoImpl<CR>
	nnoremap <silent><buffer>gr :LspShowReferences<CR>

	nnoremap <silent><buffer><Leader>gd :LspPeekDefinition<CR>
	nnoremap <silent><buffer><Leader>gc :LspPeekDeclaration<CR>
	nnoremap <silent><buffer><Leader>gt :LspPeekTypeDef<CR>
	nnoremap <silent><buffer><Leader>gi :LspPeekImpl<CR>
	nnoremap <silent><buffer><Leader>gr :LspPeekReferences<CR>

	nnoremap <silent><buffer>[d :LspDiagPrevWrap<CR>
	nnoremap <silent><buffer>]d :LspDiagNextWrap<CR>
	nnoremap <silent><buffer>[D :LspDiag first<CR>
	nnoremap <silent><buffer>]D :LspDiag last<CR>
	nnoremap <silent><buffer><Leader>gh :LspDiag! current<CR>

	nnoremap <silent><buffer><Leader>rn :LspRename<CR>
endfunction

augroup Lsp
	autocmd!

	autocmd User LspSetup call OnLspSetup()
	autocmd User LspAttached call OnLspAttached()
	autocmd BufWritePre * if exists(':LspFormat') | LspFormat | endif
augroup END
" }

" vim-vsnip {
" Expand
imap <expr> <C-j> vsnip#expandable() ? '<Plug>(vsnip-expand)' : '<C-j>'
smap <expr> <C-j> vsnip#expandable() ? '<Plug>(vsnip-expand)' : '<C-j>'

" Expand or jump
imap <expr> <C-l> vsnip#available(1) ? '<Plug>(vsnip-expand-or-jump)' : '<C-l>'
smap <expr> <C-l> vsnip#available(1) ? '<Plug>(vsnip-expand-or-jump)' : '<C-l>'

" Jump forward or backward
imap <expr> <Tab> vsnip#jumpable(1) ? '<Plug>(vsnip-jump-next)' : '<Tab>'
smap <expr> <Tab> vsnip#jumpable(1) ? '<Plug>(vsnip-jump-next)' : '<Tab>'
imap <expr> <S-Tab> vsnip#jumpable(-1) ? '<Plug>(vsnip-jump-prev)' : '<S-Tab>'
smap <expr> <S-Tab> vsnip#jumpable(-1) ? '<Plug>(vsnip-jump-prev)' : '<S-Tab>'
" }

" asyncrun.vim {
let g:asyncrun_exit = 'silent! botright copen 10 | cbottom'

" Asynchronous Make command
command! -bang -nargs=* -complete=file Make AsyncRun -program=make @ <args>

nnoremap <F3> :Make<Space>
nnoremap <F4> :AsyncRun<Space>
" }

" vim-markdown {
" tpope/vim-markdown
" Don't need to install these if you are running a recent version of Vim
let g:markdown_syntax_conceal = 0
let g:markdown_minlines = 100
let g:markdown_fenced_languages = ['c', 'cpp', 'rust', 'go', 'javascript', 'typescript', 'python', 'lua', 'bash=sh', 'vim', 'sql', 'yaml', 'json']
" }

" Terminal {
if !has('gui_running')
	augroup CheckFileChanges
		autocmd!

		" Check file changes outside vim (terminal/TTY/kmscon)
		autocmd CursorHold,WinEnter,FocusGained * if getcmdtype() ==# '' | checktime | endif
	augroup END
endif
" }
