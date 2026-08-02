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
" Require Vim 9.0+, not Neovim
if v:version < 900 || has('nvim')
	echohl Error
	echo "monkey-vim requires Vim 9.0 or later. Neovim is not supported."
	echohl None
	finish
endif

" Install vim-plug if not present
if empty(glob($HOME . '/.vim/autoload/plug.vim'))
	let s:path = expand('/.vim/autoload/plug.vim')
	silent execute '!curl' '-fLo' $HOME . s:path '--create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'

	augroup Init
		autocmd!
		autocmd VimEnter * PlugInstall | source $MYVIMRC
		autocmd VimEnter * call mkdir($HOME . '/.vim/swap/', 'p')
		autocmd VimEnter * echohl Title | echo 'monkey-vim is ready! Run :PlugStatus to verify plugins.' | echohl None
	augroup END
endif
" }

" vim-plug {
" Time limit of each task in seconds
let g:plug_timeout = 300
" }

call plug#begin(expand($HOME . '/.vim/bundle'))

" Plugins {
Plug 'sainnhe/sonokai'
Plug 'itchyny/lightline.vim'

Plug 'junegunn/fzf', {'do': {-> fzf#install()}} | Plug 'junegunn/fzf.vim'
Plug 'dyng/ctrlsf.vim'
Plug 'airblade/vim-rooter'
Plug 'ludovicchabant/vim-gutentags'
Plug 'tpope/vim-fugitive' | Plug 'junegunn/gv.vim', {'on': 'GV'}
Plug 'airblade/vim-gitgutter'

Plug 'monkoose/vim9-stargate'
Plug 'svermeulen/vim-subversive'
Plug 'haya14busa/vim-asterisk'
Plug 'mg979/vim-visual-multi'
Plug 'Konfekt/FastFold'

Plug 'wellle/targets.vim'
Plug 'michaeljsmith/vim-indent-object'
Plug 'tpope/vim-surround'
Plug 'tpope/vim-repeat'

Plug 'cohama/lexima.vim'
Plug 'andymass/vim-matchup'
Plug 'tpope/vim-eunuch'

Plug 'yegappan/lsp'
Plug 'hrsh7th/vim-vsnip' | Plug 'hrsh7th/vim-vsnip-integ' | Plug 'rafamadriz/friendly-snippets'

Plug 'justinmk/vim-dirvish'
Plug 'kshenoy/vim-signature'
Plug 'tpope/vim-obsession'
Plug 'romainl/vim-qf'
Plug 'ubaldot/vim9-conversion-aid'
" }

call plug#end()

" Builtin packages {
silent! packadd! comment
silent! packadd! hlyank

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

set ruler

" Cursorline {
set cursorline

augroup CursorLine
	autocmd!
	" Disable cursorline in insert mode
	autocmd InsertEnter * set nocursorline
	autocmd InsertLeave * set cursorline
augroup END
" }

" Search {
set incsearch
set hlsearch
set ignorecase
set smartcase

augroup Hlsearch
	autocmd!
	autocmd InsertEnter * if v:hlsearch | call feedkeys("\<Cmd>nohlsearch\<CR>", 'm') | endif
augroup END
" }

" Show search count message when searching
set shortmess-=S shortmess+=s

set showmatch

" The ":substitute" flag 'g' is default on. This means that
" all matches in a line are substituted instead of one. When a 'g' flag
" is given to a ":substitute" command, this will toggle the substitution
" of all or one match
set gdefault

set wildmenu
set wildmode=list:longest,full

" Complete options (disable preview scratch window, longest removed to aways show menu)
set completeopt=menu,menuone

set magic

set directory=$HOME/.vim/swap//

" Make the jumplist behave like the tagstack
set jumpoptions+=stack

" Share vim clipboard with system clipboard
if has('unnamedplus') && (!empty($DISPLAY) || !empty($WAYLAND_DISPLAY) || has('mac'))
	" When possible use + register for copy-paste
	set clipboard=unnamed,unnamedplus
elseif !empty($DISPLAY) || !empty($WAYLAND_DISPLAY) || has('mac')
	" Use * register for copy-paste (X11 without +clipboard, or Mac)
	set clipboard=unnamed
endif

set smartindent

set autoindent

set smarttab

set tabstop=4
set softtabstop=4

set shiftwidth=4

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
set updatetime=300

set list
set listchars=tab:▸\ ,leadmultispace:│\ \ \ ,eol:¬,trail:·

" FileType {
augroup FileTypeGroup
	autocmd!
	" Space indent, 4-width: Rust, Python, Markdown
	autocmd FileType rust,python,markdown setlocal expandtab tabstop=4 shiftwidth=4 softtabstop=4
	" Space indent, 2-width: JavaScript, TypeScript, Lua, YAML, JSON
	autocmd FileType javascript,typescript,lua,yaml,json setlocal expandtab tabstop=2 shiftwidth=2 softtabstop=2

	autocmd BufNewFile *.sh,*.py call AutoInsertFileHead()

	" Move the quickfix window to the bottom of the window layout
	autocmd FileType qf wincmd J
augroup END

def AutoInsertFileHead()
	# Shell
	if &filetype ==# 'sh'
		setline(1, '#!/usr/bin/env bash')
		cursor(line('$'), 0)
		put = ''
	endif

	# Python
	if &filetype ==# 'python'
		setline(1, '#!/usr/bin/env python3')
		cursor(line('$'), 0)
		put = repeat(nr2char(10), 2)
	endif

	cursor(line('$'), 0)
enddef
" }

" Docset {
augroup Docset
	autocmd!
	autocmd FileType man,help setlocal nolist

	" Use :LspHover as the default docset
	autocmd FileType * setlocal keywordprg=:LspHover
	autocmd FileType c,man setlocal keywordprg=:Man
	autocmd FileType c let $MANSECT = '2:3:1:4:5:6:7:8:9'
	autocmd FileType vim,help setlocal keywordprg=:help
augroup END
" }

" Resize splits when the window is resized
def ResizeAllTab()
	var cur_tab = tabpagenr()
	silent! execute 'tabdo wincmd = '
	silent! execute 'tabnext ' .. cur_tab
enddef

augroup AutoResize
	autocmd!
	autocmd VimResized * call ResizeAllTab()
augroup END

set scrolloff=7

set sidescrolloff=15

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

set fileformats=unix,dos,mac

set backspace=indent,eol,start

set hidden

set autoread

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

set belloff=all

set mouse=nvi

set showtabline=1

set laststatus=2

" lightline.vim {
vim9cmd g:lightline = {
		'colorscheme': 'sonokai',
		'active': {
			'left': [['mode', 'paste'], ['gitinfo', 'filename']],
			'right': [['lineinfo'], ['percent'], ['searchinfo', 'filetype', 'fileencoding', 'fileformat']]
		},
		'inactive': {
			'left': [['mode', 'filename']],
			'right': []
		},
		'component_function': {
			'gitinfo': 'LightLineGitInfo',
			'searchinfo': 'LightLineSearchOrVM',
			'filename': 'LightLineFilename',
			'fileformat': 'LightLineFileformat',
			'filetype': 'LightLineFiletype',
			'fileencoding': 'LightLineFileencoding',
			'percent': 'LightLinePercent',
			'lineinfo': 'LightLineLineInfo',
			'mode': 'LightLineMode',
		},
		'component_expand': {
			'tabs': 'lightline#tabs',
		},
		'separator': {'left': '', 'right': ''},
		'subseparator': {'left': '│', 'right': '│'},
		'tab': {
			'active': ['filename', 'modified'],
			'inactive': ['filename', 'modified'],
		},
		'tabline': {
			'left': [['tabs']],
			'right': []
		},
		'tabline_separator': {'left': '', 'right': ''},
		'tabline_subseparator': {'left': '│', 'right': '│'},
	}

def s:LightLineModified(): string
	return &filetype =~# 'help' ? '' : &modified ? '+' : &modifiable ? '' : '-'
enddef

def s:LightLineReadonly(): string
	return &filetype !~? 'help' && &readonly ? '🔒' : ''
enddef

" Cached window type: returns 0=normal, 1=location, 2=quickfix, 3=preview
" Result is stored in w:window_type to avoid recomputation within the same
" statusline refresh cycle. Invalidated on BufWinEnter/WinEnter.
def s:GetWindowType(): number
	if exists('w:window_type')
		return w:window_type
	endif
	if &previewwindow
		w:window_type = 3
	elseif &filetype ==# 'qf'
		var cur_winnr = winnr()
		if qf#IsQfWindow(cur_winnr)
			w:window_type = 2
		elseif qf#IsLocWindow(cur_winnr)
			w:window_type = 1
		else
			w:window_type = 0
		endif
	else
		w:window_type = 0
	endif
	return w:window_type
enddef

" Cached git file detection. Result is stored in b:is_git_file,
" invalidated on BufEnter.
def s:IsGitFile(): number
	if exists('b:is_git_file')
		return b:is_git_file
	endif
	b:is_git_file = 0
	if !exists('g:loaded_gitgutter') || !exists('g:loaded_fugitive')
		return 0
	endif
	var fname = expand('%:t')
	if fname == '' || fname =~# '\[Plugins\]'
		return 0
	endif
	if g:FugitiveExtractGitDir(resolve(expand('%'))) == ''
		return 0
	endif
	b:is_git_file = 1
	return 1
enddef

" Invalidate per-buffer and per-window caches
augroup LightLineCache
	autocmd!
	autocmd BufEnter * unlet! b:is_git_file
	autocmd BufWinEnter,WinEnter * unlet! w:window_type
augroup END

" Combined git status component: gutter summary + branch name.
" Replaces LightLineGitGutter & LightLineFugitive; avoids calling
" s:GetWindowType() / s:IsGitFile() / FugitiveExtractGitDir() twice.
def LightLineGitInfo(): string
	if s:GetWindowType() != 0
		return ''
	endif
	if !s:IsGitFile()
		return ''
	endif
	var l_parts = []
	try
		var s_summary = g:GitGutterGetHunkSummary()
		add(l_parts, printf('+%d ~%d -%d', s_summary[0], s_summary[1], s_summary[2]))
	catch
	endtry
	try
		if getftype(expand('%')) ==# 'link'
			g:FugitiveDetect(resolve(expand('%')))
		endif
		var branch = g:FugitiveHead()
		if branch != ''
			add(l_parts, '⎇ ' .. branch)
		endif
	catch
	endtry
	return join(l_parts, ' ')
enddef

def LightLineFilename(): string
	if s:GetWindowType() != 0
		return ''
	endif
	var ro = s:LightLineReadonly()
	var mod = s:LightLineModified()
	var fname = expand('%:t')
	if fname == ''
		fname = '[No Name]'
	endif
	return join(filter([ro, fname, mod], 'v:val != ""'), ' ')
enddef

def LightLineFileformat(): string
	return winwidth(0) > 70 ? &fileformat : ''
enddef

def LightLineFiletype(): string
	return winwidth(0) > 70 ? (&filetype != '' ? &filetype : 'unknown') : ''
enddef

def LightLineFileencoding(): string
	return winwidth(0) > 70 ? (&fileencoding != '' ? &fileencoding : &encoding) : ''
enddef

def LightLinePercent(): string
	return winwidth(0) > 70 ? printf('%3d%%', (100 * line('.') / line('$'))) : ''
enddef

def LightLineLineInfo(): string
	return winwidth(0) > 70 ? printf('%3d/%-d : %-2d', line('.'), line('$'), col('.')) : ''
enddef

def LightLineSearchOrVM(): string
	if s:GetWindowType() != 0
		return ''
	endif
	if exists('b:VM_Selection') && !empty(b:VM_Selection)
		var vm = g:VMInfos()
		if !empty(vm)
			var result = vm.ratio
			if !empty(@/)
				result ..= '  /' .. @/
			endif
			return result
		endif
		return ''
	endif
	if !v:hlsearch || @/ == ''
		return ''
	endif
	var count = searchcount()
	if count.total == 0
		return ''
	endif
	if count.incomplete == 1
		return printf('[?/??]')
	endif
	return printf('[%d/%d]', count.current, count.total)
enddef

def LightLineMode(): string
	var window_type = s:GetWindowType()
	if window_type != 0
		return window_type == 3 ? 'Preview' :
			 window_type == 2 ? 'Quickfix' :
			 window_type == 1 ? 'Location' : ''
	endif

	if exists('b:VM_Selection') && !empty(b:VM_Selection)
		return 'V-MULTI'
	endif

	return winwidth(0) > 60 ? lightline#mode() : ''
enddef
" }

" vim-visual-multi lightline integration {
highlight VM_Mode cterm=bold ctermfg=232 ctermbg=141 gui=bold guifg=#1a1b26 guibg=#bb9af7
highlight VM_Info ctermfg=141 ctermbg=236 guifg=#bb9af7 guibg=#3b3f54

let s:saved_normal_left = []
def s:VM_Enter()
	var pal = get(g:, 'lightline#colorscheme#sonokai#palette')
	s:saved_normal_left = copy(pal.normal.left[0])
	pal.normal.left[0] = ['#1a1b26', '#bb9af7', 232, 141, 'bold']
	lightline#highlight()
	lightline#update()
enddef

def s:VM_Leave()
	if !empty(s:saved_normal_left)
		var pal = get(g:, 'lightline#colorscheme#sonokai#palette')
		pal.normal.left[0] = s:saved_normal_left
		s:saved_normal_left = []
	endif
	lightline#highlight()
	lightline#update()
enddef

augroup VMLightLine
	autocmd!
	autocmd User visual_multi_start silent call s:VM_Enter()
	autocmd User visual_multi_exit  silent call s:VM_Leave()
augroup END
" }

" Color support {
" Use true color when the terminal supports it
if has('termguicolors')
	" True color: Vim renders GUI colors (guifg/guibg) directly
	set termguicolors
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

" sonokai {
" Should be set before :colorscheme
let g:sonokai_style = 'andromeda'
let g:sonokai_better_performance = 1
let g:sonokai_diagnostic_text_highlight = 1
let g:sonokai_diagnostic_virtual_text = 'colored'
let g:sonokai_dim_inactive_windows = 1

set background=dark
colorscheme sonokai

" sonokai explicitly defines MatchParenCur/MatchWord,
" which blocks vim-matchup's hi def link. Re-link them.
highlight! link MatchParen Search
highlight! link MatchParenCur Search
highlight! link MatchWord Search
highlight! link MatchWordCur Search
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

def s:SendExitToAllTerminals()
	for buf in getbufinfo()
		if get(buf, 'buftype') ==# 'terminal' && term_getstatus(buf.bufnr) =~# 'running'
			term_sendkeys(buf.bufnr, "exit\<CR>")
		endif
	endfor
enddef

def s:IsAuxiliaryWindow(winnr: number): number
	var bufnr = winbufnr(winnr)
	if bufnr == -1
		return 1
	endif
	if getwinvar(winnr, '&previewwindow')
		return 1
	endif
	if getbufvar(bufnr, '&buftype') ==# 'quickfix'
		return 1
	endif
	if getbufvar(bufnr, '&buftype') ==# 'help'
		return 1
	endif
	if getbufvar(bufnr, '&buftype') ==# 'terminal'
		return 1
	endif
	if getbufvar(bufnr, '&buftype') ==# 'nofile' && getbufvar(bufnr, '&filetype') ==# 'man'
		return 1
	endif
	if getbufvar(bufnr, '&buftype') ==# 'nofile' && bufname(bufnr) ==# '' && !getbufvar(bufnr, '&modified')
		return 1
	endif
	return 0
enddef

def s:FocusToValidWindow()
	if !s:IsAuxiliaryWindow(winnr())
		return
	endif
	for info in getwininfo()
		if !s:IsAuxiliaryWindow(info.winnr)
			win_gotoid(info.winid)
			return
		endif
	endfor
enddef

def s:CloseFugitiveDiff(): number
	if !&diff
		return 0
	endif
	for wn in range(1, winnr('$'))
		var buf = winbufnr(wn)
		var name = bufname(buf)
		var bt = getbufvar(buf, '&buftype')
		if name =~# '^fugitive:' || name =~# '^gitgutter:' || (empty(name) && bt ==# 'nofile')
			execute wn .. 'wincmd w'
			quit
			return 1
		endif
	endfor
	return 0
enddef

def QuitAll()
	s:SendExitToAllTerminals()
	silent! confirm quitall!
enddef

def Quit()
	if s:CloseFugitiveDiff()
		return
	endif

	if &buftype ==# 'terminal' && term_getstatus(bufnr()) =~# 'running'
		term_sendkeys(bufnr(), "exit\<CR>")
	endif

	var will_be_only_aux = 1
	var has_other_window = 0
	var cur = win_getid()
	for info in getwininfo()
		if info.winid == cur
			continue
		endif
		has_other_window = 1
		if !s:IsAuxiliaryWindow(info.winnr)
			will_be_only_aux = 0
			break
		endif
	endfor

	if !has_other_window || will_be_only_aux
		g:QuitAll()
	else
		quit
		s:FocusToValidWindow()
	endif
enddef

nnoremap <silent> q :call Quit()<CR>
nnoremap <silent> <S-q> :call QuitAll()<CR>

nnoremap t q
vnoremap t q
" }

" Terminal {
def TerminalToggle()
	if exists('t:terminal_bufnr') && bufexists(t:terminal_bufnr) && term_getstatus(t:terminal_bufnr) =~# 'running'
		var winid = bufwinid(t:terminal_bufnr)
		if winid != -1
			win_execute(winid, 'hide')
		else
			execute 'botright sbuffer ' .. t:terminal_bufnr
			feedkeys("i", 't')
		endif
	else
		botright terminal
		t:terminal_bufnr = bufnr('%')
	endif
enddef

nnoremap <F3> :botright terminal<Space>
nnoremap <silent> <F4> :call TerminalToggle()<CR>
tnoremap <silent> <F4> <C-\><C-n>:call TerminalToggle()<CR>
" }

def OpenPrompt(prompt: string, cmd: string)
	var name = s:Strip(input(prompt, '', 'file'))
	if name !=# ''
		execute cmd .. ' ' .. fnameescape(name)
	endif
enddef

def s:Strip(input_string: string): string
	return substitute(input_string, '^\s*\(.\{-}\)\s*$', '\1', '')
enddef

" Buffer {
nnoremap <silent><Leader>o :call OpenPrompt('New buffer name: ', 'edit')<CR>

nnoremap <silent>[b :bprevious<CR>
nnoremap <silent>]b :bnext<CR>
" }

" Tab {
nnoremap <silent><Leader>t :call OpenPrompt('New tab name: ', 'tabnew')<CR>
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
nnoremap <silent><Leader>s :call OpenPrompt('New split name: ', 'split')<CR>
nnoremap <silent><Leader>v :call OpenPrompt('New vsplit name: ', 'vsplit')<CR>
" }

" F1 ~ F10 {
nmap <F1> <Plug>CtrlSFPrompt
nnoremap <silent><F2> :CtrlSFToggle<CR>
" }

" Toggle {
nnoremap <silent>cod :<C-R>=&diff ? 'diffoff' : 'diffthis'<CR><CR>
nnoremap <silent>cop :set invpaste<CR>
nnoremap <silent>col :set invlist<CR>
nnoremap <silent>con :nohlsearch<CR>
nnoremap <silent><Leader><Space> :%s/\s\+$//e<CR>:nohlsearch<CR>
" <Leader><Leader><Space>: strip trailing whitespace + \r (DOS newline)
nnoremap <silent><Leader><Leader><Space> :%s/\s\+$//e<CR>:%s/\r$//e<CR>:nohlsearch<CR>

" Disable paste mode when leaving insert mode
augroup PasteMode
	autocmd!
	autocmd InsertLeave * setlocal nopaste
augroup END
" }

" Zoom {
def ZoomToggle()
	if exists('t:zoomed') && t:zoomed
		execute t:zoom_winrestcmd
		t:zoomed = 0
	else
		t:zoom_winrestcmd = winrestcmd()
		resize
		vertical resize
		t:zoomed = 1
	endif
enddef

nnoremap <silent><Leader>z :call ZoomToggle()<CR>
" }

" vim-dirvish {
nnoremap <silent>- :execute 'Dirvish' expand('%:p:h')<CR>
nnoremap <silent>~ :execute 'Dirvish' GetProjectOrHome()<CR>

def GetFileroot(): string
	var root = g:FindRootDirectory()
	if root ==# ''
		root = expand('%:h')
	endif
	return root
enddef

def GetProjectOrHome(): string
	var root = g:FindRootDirectory()
	return root !=# '' ? root : expand('~')
enddef

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

" ctrlsf.vim {
let g:ctrlsf_confirm_save = 0
let g:ctrlsf_extra_backend_args = {
			\ 'rg': '--hidden',
			\ 'ag': '--hidden',
			\ }
let g:ctrlsf_ignore_dir = ['.git', '.hg', '.svn', '.bzr']

nnoremap <silent><Leader>a <Plug>CtrlSFCwordExec
vnoremap <silent><Leader>a <Plug>CtrlSFVwordExec
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

" vim-qf {
let g:qf_mapping_ack_style = 1
let g:qf_window_bottom = 1
let g:qf_loclist_window_bottom = 1
let g:qf_auto_resize = 1
let g:qf_max_height = 10
let g:qf_auto_open_quickfix = 0
let g:qf_auto_open_loclist = 0
let g:qf_auto_quit = 1

def QuickFixToggle(type: string, cmd: string)
	var ftype = &filetype
	var last_winnr = winnr('#')
	var buffer_count_before = s:BufferCount()
	if type ==# 'quickfix' || type ==# 'q'
		silent! cclose
	elseif type ==# 'location' || type ==# 'l'
		silent! lclose
	endif

	if s:BufferCount() == buffer_count_before
		execute cmd
	else
		if ftype ==# 'qf'
			silent! execute last_winnr .. 'wincmd w'
		endif
	endif
enddef

def s:BufferCount(): number
	return len(tabpagebuflist())
enddef

nnoremap <silent><Leader>q :call QuickFixToggle('q', 'silent! botright copen 10')<CR>
nnoremap <silent><Leader>l :call QuickFixToggle('l', 'silent! lopen 10')<CR>
" }

" vim-fugitive {
nnoremap <silent><Leader>gg :Git<CR>
nnoremap <silent><Leader>gd :Gdiffsplit!<CR>
nnoremap <silent><Leader>gD :Git diff<CR>
map <silent><Leader>gb :Git blame<CR>
" }

" gv.vim {
map <silent><Leader>gl :GV!<CR>
map <silent><Leader>gL :GV<CR>
" }

" vim-gitgutter {
let g:gitgutter_map_keys = 0
let g:gitgutter_preview_win_floating = 1

nmap <Leader>hp <Plug>(GitGutterPreviewHunk)
nmap <Leader>hs <Plug>(GitGutterStageHunk)
nmap <Leader>hr <Plug>(GitGutterUndoHunk)
nmap <Leader>hS :Git add %<CR>
nmap <Leader>hR :Git checkout -- %<CR>
nmap <Leader>hl :GitGutterQuickFixCurrentFile<CR>
nmap <Leader>hq :GitGutterQuickFixCurrentFile<CR>
nmap <Leader>hQ :GitGutterQuickFix<CR>
nmap <silent>[h <Plug>(GitGutterPrevHunk)
nmap <silent>]h <Plug>(GitGutterNextHunk)
" }

" Session {
set sessionoptions-=blank sessionoptions-=options sessionoptions-=folds sessionoptions-=terminal

def s:GetSessionFileInfo(): list<string>
	var session_dir = expand($HOME .. '/.cache/sessions/')
	var session_filename = session_dir .. substitute(trim(g:GetFileroot(), '/', 1), '/', '-', 'g') .. '-session.vim'
	return [session_dir, session_filename]
enddef

def BackupSession()
	var session_info = s:GetSessionFileInfo()
	var session_dir = session_info[0]
	var session_filename = session_info[1]
	mkdir(session_dir, 'p')
	execute 'Obsession' session_filename
enddef

def RestoreSession()
	var session_info = s:GetSessionFileInfo()
	var session_filename = session_info[1]
	if argc() == 0 && filereadable(session_filename)
		execute 'source' session_filename
	endif
enddef

" Backup
nnoremap <Leader>ws :call BackupSession()<CR>
" Remove
nnoremap <Leader>rs :Obsession!<CR>

augroup Session
	autocmd!
	autocmd VimEnter * nested call RestoreSession()
augroup END
" }

" fzf.vim {
let $FZF_DEFAULT_OPTS = '--layout=reverse'
let g:fzf_layout = { 'window': { 'width': 0.8, 'height': 0.9 } }
let g:fzf_preview_window = ['right:60%']
let g:fzf_action = {
			\ 'ctrl-s': 'split',
			\ 'ctrl-v': 'vsplit',
			\ 'ctrl-t': 'tab split',
			\ }

nnoremap <silent><C-p> :Files<CR>
nnoremap <silent><Leader>b :call <SID>fzf_buffers()<CR>
nnoremap <silent><Leader>y :BTags<CR>
nnoremap <silent><Leader>f :call <SID>fzf_lsp_doc_symbols([6, 9, 12])<CR>
nnoremap <silent><Leader>e :BLines<CR>

imap <C-x><C-p> <Plug>(fzf-complete-path)
imap <C-x><C-l> <Plug>(fzf-complete-line)
imap <C-x><C-b> <Plug>(fzf-complete-buffer-line)

def s:fzf_buffers()
	g:__fzf_buffers_delete_file = tempname()
	var spec = {
		'options': [
			'--no-footer',
			'--bind', 'ctrl-d:execute-silent(echo {} >> ' .. g:__fzf_buffers_delete_file .. ')+exclude',
			'--bind', 'ctrl-alt-x:execute-silent(echo {} >> ' .. g:__fzf_buffers_delete_file .. ')+exclude',
		],
		'exit': function('s:buf_exit')
	}
	fzf#vim#buffers('', fzf#vim#with_preview(spec, 'right:60%'))
enddef

def s:buf_exit(code: number)
	if exists('g:__fzf_buffers_delete_file')
		var path = remove(g:, '__fzf_buffers_delete_file')
		if filereadable(path)
			for line in readfile(path)
				var b = matchstr(line, '\[\zs\d\+\ze\]')
				if !empty(b)
					silent execute 'bdelete ' .. b
				endif
			endfor
			delete(path)
		endif
	endif
enddef

def s:lsp_sym_sink(line: string)
	var lnum = str2nr(split(line, "\t")[-1])
	if lnum > 0
		execute 'keepjumps normal! ' .. lnum .. 'G'
	endif
enddef

def s:flatten_doc_symbols(syms: list<dict<any>>, srv: dict<any>, bnr: number, kinds: list<number>): list<string>
	var out: list<string> = []
	var stack = reverse(copy(syms))
	while !empty(stack)
		var sym = remove(stack, -1)
		if empty(kinds) || index(kinds, sym.kind) != -1
			var rng = has_key(sym, 'location') ? sym.location.range : sym.selectionRange
			if srv.needOffsetEncoding
				srv.decodeRange(bnr, rng)
			endif
			add(out, sym.name .. "\t" .. (rng.start.line + 1))
		endif
		if has_key(sym, 'children') && !empty(sym.children)
			for idx in range(len(sym.children) - 1, -1, -1)
				add(stack, sym.children[idx])
			endfor
		endif
	endwhile
	return out
enddef

def s:err(msg: string)
	echohl ErrorMsg
	echo msg
	echohl None
enddef

def s:fzf_lsp_doc_symbols(types: list<number>)
	var srv = lsp#buffer#CurbufGetServer('documentSymbol')
	if empty(srv) || !srv.running || !srv.ready
		s:err('No ready LSP server with documentSymbol support for this buffer')
		return
	endif
	var reply = srv.rpc('textDocument/documentSymbol', {'textDocument': {'uri': lsp#util#LspFileToUri(expand('%:p'))}})
	if empty(reply) || !has_key(reply, 'result') || empty(reply.result)
		s:err('No document symbols returned by the LSP server')
		return
	endif
	if type(reply.result) != v:t_list
		return
	endif
	var entries = s:flatten_doc_symbols(reply.result, srv, bufnr('%'), types)
	var opts = {
		'source': entries,
		'sink': function('s:lsp_sym_sink'),
		'options': ['--delimiter=\t', '-n', '1', '--with-nth=1'],
		'placeholder': fzf#shellescape(expand('%:p')) .. ':{2}',
	}
	fzf#run(fzf#wrap('lspdoc', fzf#vim#with_preview(opts, 'right:60%:+{2}/2')))
enddef
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
nnoremap s <plug>(SubversiveSubstitute)
xnoremap s <plug>(SubversiveSubstitute)
nnoremap ss <plug>(SubversiveSubstituteLine)
nnoremap S <plug>(SubversiveSubstituteToEndOfLine)
" }

" vim-asterisk {
map *  <Plug>(asterisk-z*)
map g* <Plug>(asterisk-gz*)
map #  <Plug>(asterisk-z#)
map g# <Plug>(asterisk-gz#)
" }

" vim-visual-multi {
let g:VM_maps = {}
let g:VM_maps['Select Operator'] = 'gs'
let g:VM_set_statusline = 0
let g:VM_silent_exit = 1
" }

" FastFold {
" Only update fold after type zx or zX
let g:fastfold_fold_command_suffixes = ['x', 'X', 'a', 'A']
let g:fastfold_fold_movement_commands = []
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
def OnLspSetup()
	var lspOpts = {
				   aleSupport: false,
				   autoComplete: true,
				   autoHighlight: true,
				   autoHighlightDiags: true,
				   autoPopulateDiags: false,
				   completionMatcher: 'case',
				   completionMatcherValue: 1,
				   completionTextEdit: false,
				   diagVirtualTextAlign: 'below',
				   diagVirtualTextWrap: 'wrap',
				   diagSignErrorText: 'E',
				   diagSignHintText: 'H',
				   diagSignInfoText: 'I',
				   diagSignWarningText: 'W',
				   echoSignature: false,
				   hideDisabledCodeActions: false,
				   highlightDiagInline: true,
				   hoverInPreview: false,
				   ignoreMissingServer: false,
				   keepFocusInDiags: true,
				   keepFocusInReferences: true,
				   noNewlineInCompletion: false,
				   omniComplete: false,
				   outlineOnRight: false,
				   outlineWinSize: 20,
				   popupBorder: true,
				   popupBorderHighlight: 'Title',
				   popupBorderHighlightPeek: 'Special',
				   popupBorderSignatureHelp: false,
				   popupHighlightSignatureHelp: 'Pmenu',
				   popupHighlight: 'Normal',
				   popupHighlightCompletion: 'Pmenu',
				   semanticHighlight: true,
				   semanticHighlightDelay: 300,
				   showDiagInBalloon: true,
				   showDiagInPopup: true,
				   showDiagOnStatusLine: true,
				   showDiagWithSign: true,
				   showDiagWithVirtualText: true,
				   showInlayHints: false,
				   showSignature: true,
				   snippetSupport: true,
				   ultisnipsSupport: false,
				   useBufferCompletion: false,
				   usePopupInCodeAction: false,
				   useQuickfixForLocations: false,
				   vsnipSupport: true,
				   bufferCompletionTimeout: 100,
				   customCompletionKinds: false,
				   completionKinds: {},
				   filterCompletionDuplicates: false,
				   condensedCompletionMenu: false,
				 }

	var lspServers = [{
				  name: 'clangd',
				  filetype: ['c', 'cpp'],
				  path: 'clangd',
				  args: [
				    '--background-index',
				    '--background-index-priority = background',
				    '--clang-tidy',
				    '--cross-file-rename',
				    '--all-scopes-completion = true',
				    '--completion-style = detailed',
				    '--function-arg-placeholders = true',
				    '--header-insertion = iwyu',
				    '--header-insertion-decorators',
				    '--limit-references = 0',
				    '--limit-results = 0'
				  ],
				 },
				{name: 'rust-analyzer',
				   filetype: ['rust'],
				   path: 'rust-analyzer',
				   args: [],
				   workspaceConfig: {
				     'rust-analyzer': {
				       'checkOnSave': {
				         'command': 'clippy',
				       },
				       'procMacro': {
				         'enable': true,
				       },
				       'cargo': {
				         'allFeatures': true,
				       },
				     },
				   },
				 },
				{name: 'gopls',
				   filetype: ['go', 'gomod', 'gowork', 'gotmpl'],
				   path: 'gopls',
				   rootSearch: ['go.work', 'go.mod'],
				   workspaceConfig: {
				     'gopls': {
				       'analyses': {
				         'nilness': true,
				         'shadow': true,
				         'unusedparams': true,
				         'unusedwrite': true,
				         'useany': true,
				       },
				       'hoverKind': 'FullDocumentation',
				       'gofumpt': true,
				       'completeUnimported': true,
				       'staticcheck': true,
				       'usePlaceholders': true,
				       'completionDocumentation': true,
				       'codelenses': {
				         'generate': true,
				         'test': true,
				         'run_vulncheck_exp': true,
				       },
				       'hints': {
				         'assignVariableTypes': true,
				         'compositeLiteralFields': true,
				         'compositeLiteralTypes': true,
				         'constantValues': true,
				         'functionTypeParameters': true,
				         'parameterNames': true,
				         'rangeVariableTypes': true,
				       },
				     },
				   }
				 },
				{name: 'typescript-language-server',
				   filetype: ['javascript', 'typescript'],
				   path: 'typescript-language-server',
				   args: ['--stdio'],
				   rootSearch: ['tsconfig.json', 'jsconfig.json', 'package.json'],
				   workspaceConfig: {
				     'typescript': {
				       'suggest': {'completeFunctionCalls': true},
				     },
				     'javascript': {
				       'suggest': {'completeFunctionCalls': true},
				     },
				   },
				 },
				 {name: 'pylsp',
				   filetype: 'python',
				   path: 'pylsp',
				   args: [],
				   rootSearch: ['pyproject.toml', 'setup.py', 'setup.cfg', '.git/'],
				   workspaceConfig: {
				     'pylsp': {
				       'plugins': {
				         'black': {'enabled': true},
				         'pylint': {
				           'enabled': false
				         },
				         'pycodestyle': {
				           'enabled': true,
				           'maxLineLength': 120,
				           'ignore': ['E501', 'W503'],
				         },
				         'rope_autoimport': {
				           'enabled': true,
				           'completions': {
				             'enabled': true
				           },
				           'code_actions': {
				             'enabled': true
				           }
				         },
				       }
				     }
				   },
				 },
				{name: 'lua-language-server',
				   filetype: 'lua',
				   path: 'lua-language-server',
				   args: [],
				   rootSearch: ['.luarc.json', '.luarc.jsonc', '.git/'],
				 },
				{name: 'bash-language-server',
				   filetype: 'sh',
				   path: 'bash-language-server',
				   args: ['start'],
				   rootSearch: ['.shellcheckrc', '.git/'],
				   workspaceConfig: {
				     'bashIde': {
				       'globPattern': '**/*@(.sh|.inc|.bash|.command|.bashrc|.bash_profile|.profile)',
				       'includeAllWorkspaceSymbols': true,
				     },
				   },
				 },
				{name: 'vim-language-server',
				   filetype: 'vim',
				   path: 'vim-language-server',
				   args: ['--stdio']
				 },
				{name: 'marksman',
				   filetype: ['markdown'],
				   path: 'marksman',
				   args: ['server'],
				   rootSearch: ['.marksman.toml', '.git/'],
				 },
				{name: 'yaml-language-server',
				   filetype: ['yaml'],
				   path: 'yaml-language-server',
				   args: ['--stdio'],
				   workspaceConfig: {
				     'yaml': {
				       'schemaStore': {
				         'enable': true,
				         'url': 'https: //www.schemastore.org/api/json/catalog.json',
				       },
				       'completion': true,
				       'hover': true,
				       'validate': true,
				     },
				   },
				 },
				{name: 'vscode-json-language-server',
				   filetype: ['json'],
				   path: 'vscode-json-language-server',
				   args: ['--stdio']
				 }
				]

	g:LspOptionsSet(lspOpts)
	g:LspAddServer(lspServers)
enddef

def OnLspAttached()
	setlocal formatexpr=lsp#lsp#FormatExpr()

	nnoremap <silent><buffer>gh :LspHover<CR>
	nnoremap <silent><buffer>gd :LspGotoDefinition<CR>
	nnoremap <silent><buffer>gc :LspGotoDeclaration<CR>
	nnoremap <silent><buffer>gt :LspGotoTypeDef<CR>
	nnoremap <silent><buffer>gi :LspGotoImpl<CR>
	nnoremap <silent><buffer>gr :LspShowReferences<CR>

	nnoremap <silent><buffer><Leader>d :LspDiag show<CR>
	nnoremap <silent><buffer>[d :LspDiag prevWrap<CR>
	nnoremap <silent><buffer>]d :LspDiag nextWrap<CR>
	nnoremap <silent><buffer>[D :LspDiag first<CR>
	nnoremap <silent><buffer>]D :LspDiag last<CR>
	nnoremap <silent><buffer><Leader>gh :LspDiag! current<CR>

	nnoremap <silent><buffer><Leader>rn :LspRename<CR>
enddef

augroup Lsp
	autocmd!
	autocmd User LspSetup call OnLspSetup()
	autocmd User LspAttached call OnLspAttached()
	autocmd BufWritePre * if !empty(lsp#buffer#CurbufGetServer('documentFormatting')) | LspFormat | endif
augroup END
" }

" vim-vsnip {
" Expand or jump
imap <expr> <C-l> vsnip#available(1) ? '<Plug>(vsnip-expand-or-jump)' : '<C-l>'
smap <expr> <C-l> vsnip#available(1) ? '<Plug>(vsnip-expand-or-jump)' : '<C-l>'

" Jump forward or backward
imap <expr> <Tab> vsnip#jumpable(1) ? '<Plug>(vsnip-jump-next)' : '<Tab>'
smap <expr> <Tab> vsnip#jumpable(1) ? '<Plug>(vsnip-jump-next)' : '<Tab>'
imap <expr> <S-Tab> vsnip#jumpable(-1) ? '<Plug>(vsnip-jump-prev)' : '<S-Tab>'
smap <expr> <S-Tab> vsnip#jumpable(-1) ? '<Plug>(vsnip-jump-prev)' : '<S-Tab>'
" }

" vim-markdown {
" tpope/vim-markdown
" Don't need to install these if you are running a recent version of Vim
let g:markdown_syntax_conceal = 0
let g:markdown_minlines = 100
let g:markdown_fenced_languages = ['c', 'cpp', 'rust', 'go', 'javascript', 'typescript', 'python', 'lua', 'bash=sh', 'vim', 'sql', 'yaml', 'json']
" }

" Terminal env {
if !has('gui_running')
	if &t_fe == ''
		" Enable focus event tracking for terminal vim.
		" Most terminal terminfo entries lack Ss/Se capability definitions,
		" causing t_fe/t_fd to remain empty. Set them manually so that
		" FocusGained/FocusLost autocommands work (e.g. for checktime).
		let &t_fe = "\<Esc>[?1004h"
		let &t_fd = "\<Esc>[?1004l"
		execute "set <FocusGained>=\<Esc>[I"
		execute "set <FocusLost>=\<Esc>[O"
	endif

	augroup CheckFileChanges
		autocmd!
		" Check file changes outside vim (terminal/TTY/kmscon)
		autocmd FocusGained,BufWinEnter,WinEnter,CursorHold * if getcmdtype() ==# '' | checktime | endif
	augroup END
endif
" }
