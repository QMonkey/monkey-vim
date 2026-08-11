vim9script

# Notes {
# vim: set nofoldenable foldmethod=marker foldmarker={,} foldlevel=0:
#
#                                _
#          _ __ ___   ___  _ __ | | _____ _   _     __   _(_)_ __ ___
#         | '_ ` _ \ / _ \| '_ \| |/ / _ \ | | |____\ \ / / | '_ ` _ \
#         | | | | | | (_) | | | |   <  __/ |_| |_____\ V /| | | | | | |
#         |_| |_| |_|\___/|_| |_|_|\_\___|\__, |      \_/ |_|_| |_| |_|
#                                         |___/
#
#     Author: Charles Qiu
#     Email: Thinking.QMonkey@GMail.com
# }

# Init {
# Install vim-plug if not present
if empty(glob($HOME .. '/.vim/autoload/plug.vim'))
	var path = '/.vim/autoload/plug.vim'
	silent execute '!curl' '-fLo' $HOME .. path '--create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim'

	augroup Init
		autocmd!
		autocmd VimEnter * PlugInstall | source $MYVIMRC | mkdir($HOME . '/.vim/swap/', 'p')
		autocmd VimEnter * echohl Title | echo 'monkey-vim is ready! Run :PlugStatus to verify plugins.' | echohl None
	augroup END
endif
# }

# vim-plug {
# Time limit of each task in seconds
g:plug_timeout = 300
# }

plug#begin(expand($HOME .. '/.vim/bundle'))

# Plugins {
Plug 'sainnhe/sonokai'
Plug 'itchyny/lightline.vim'

Plug 'junegunn/fzf' | Plug 'junegunn/fzf.vim'
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
# }

plug#end()

# Builtin packages {
silent! packadd! comment
silent! packadd! hlyank

# Enable 'Man' command
source $VIMRUNTIME/ftplugin/man.vim

# Disable netrw
g:loaded_netrw = 1
g:loaded_netrwPlugin = 1
# }

# Leader {
g:mapleader = ','
# }

# Encoding {
language message en_US.UTF-8
set langmenu=en_US.UTF-8

set encoding=utf-8
scriptencoding utf-8

# Only work in terminal vim
set termencoding=utf-8

set fileencodings=utf-8,gb18030,cp936,ucs-bom,big5,euc-jp,euc-kr,latin1
# }

# Number {
set relativenumber number

augroup RelativeNumber
	autocmd!
	# Only display relativenumber in active normal mode buffer
	autocmd WinEnter,InsertLeave * set relativenumber
	autocmd WinLeave,InsertEnter * set norelativenumber number
augroup END
# }

set ruler

# Cursorline {
set cursorline

augroup CursorLine
	autocmd!
	# Disable cursorline in insert mode
	autocmd InsertEnter * set nocursorline
	autocmd InsertLeave * set cursorline
augroup END
# }

# Search {
set incsearch
set hlsearch
set ignorecase
set smartcase

augroup Hlsearch
	autocmd!
	autocmd InsertEnter * if v:hlsearch | feedkeys("\<Cmd>nohlsearch\<CR>", 'm') | endif
augroup END
# }

# Show search count message when searching
set shortmess-=S shortmess+=s

set showmatch

# The ":substitute" flag 'g' is default on. This means that
# all matches in a line are substituted instead of one. When a 'g' flag
# is given to a ":substitute" command, this will toggle the substitution
# of all or one match
set gdefault

set wildmenu
set wildmode=list:longest,full

# Complete options (disable preview scratch window, longest removed to aways show menu)
set completeopt=menu,menuone

set magic

set directory=$HOME/.vim/swap//

# Make the jumplist behave like the tagstack
set jumpoptions+=stack

# Share vim clipboard with system clipboard
if has('unnamedplus') && (!empty($DISPLAY) || !empty($WAYLAND_DISPLAY) || has('mac'))
	# When possible use + register for copy-paste
	set clipboard=unnamed,unnamedplus
elseif !empty($DISPLAY) || !empty($WAYLAND_DISPLAY) || has('mac')
	# Use * register for copy-paste (X11 without +clipboard, or Mac)
	set clipboard=unnamed
elseif !empty($TMUX)
	# Fallback: KMScon/TTY fallback +/* registers to tmux buffers via clipboard provider
	set clipboard=unnamed,unnamedplus

	def TmuxAvailable(): bool
		return !empty($TMUX)
	enddef

	def TmuxCopy(reg: string, type: string, lines: list<string>)
		system('tmux load-buffer -w -', join(lines, "\n"))
	enddef

	def TmuxPaste(reg: string): list<any>
		var content = system('tmux save-buffer -')
		return ['v', split(content, "\n", true)]
	enddef

	v:clipproviders["tmux"] = {
		available: TmuxAvailable,
		copy: { '+': TmuxCopy, '*': TmuxCopy },
		paste: { '+': TmuxPaste, '*': TmuxPaste },
	}
	set clipmethod=tmux
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

# For mappings
set timeout
set timeoutlen=1000
# For key codes
set ttimeout
# Unnoticeable small value
set ttimeoutlen=10
set updatetime=300

set list
set listchars=tab:▸\ ,leadmultispace:│\ \ \ ,eol:¬,trail:·

# FileType {
augroup FileTypeGroup
	autocmd!
	# Space indent, 4-width: Rust, Python, Markdown
	autocmd FileType rust,python,markdown setlocal expandtab tabstop=4 shiftwidth=4 softtabstop=4
	# Space indent, 2-width: JavaScript, TypeScript, Lua, YAML, JSON
	autocmd FileType javascript,typescript,lua,yaml,json setlocal expandtab tabstop=2 shiftwidth=2 softtabstop=2

	autocmd BufNewFile *.sh,*.py AutoInsertFileHead()

	# Move the quickfix window to the bottom of the window layout
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
# }

# vim-markdown {
# tpope/vim-markdown
# Don't need to install these if you are running a recent version of Vim
g:markdown_syntax_conceal = 0
g:markdown_minlines = 100
g:markdown_fenced_languages = ['c', 'cpp', 'rust', 'go', 'javascript', 'typescript', 'python', 'lua', 'bash=sh', 'vim', 'sql', 'yaml', 'json']
# }

# Docset {
augroup Docset
	autocmd!
	autocmd FileType man,help setlocal nolist

	# Use :LspHover as the default docset
	autocmd FileType * setlocal keywordprg=:LspHover
	autocmd FileType c,man setlocal keywordprg=:Man
	autocmd FileType c setenv('MANSECT', '2:3:1:4:5:6:7:8:9')
	autocmd FileType vim,help setlocal keywordprg=:help
augroup END
# }

# Resize splits when the window is resized
def ResizeAllTab()
	var cur_tab = tabpagenr()
	silent! execute 'tabdo wincmd = '
	silent! execute 'tabnext ' .. cur_tab
enddef

augroup AutoResize
	autocmd!
	autocmd VimResized * ResizeAllTab()
augroup END

set scrolloff=7

set sidescrolloff=15

set sidescroll=1

# Disable fold on startup
set nofoldenable
set foldmethod=syntax
set foldlevel=99

# Use indent style fold for python and yaml
augroup LanguageFold
	autocmd!
	autocmd FileType python,yaml setlocal foldmethod=indent
augroup END

# Character width. Should never be enable!
#set ambiwidth=double

set fileformats=unix,dos,mac

set backspace=indent,eol,start

set hidden

set autoread

# Restore cursor to previous editing position
augroup RestoreCursorPosition
	autocmd!
	autocmd BufReadPost * if line("'\"") > 1 && line("'\"") <= line("$") | execute "normal! g'\"" | endif
augroup END

# Clear jumplist on vim startup
augroup Jumplist
	autocmd!
	autocmd VimEnter * :clearjumps
augroup END

set belloff=all

set mouse=nvi

set showtabline=1

set laststatus=2

# lightline.vim {
g:lightline = {
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
		'searchinfo': 'LightLineVMInfo',
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

def g:LightLineModified(): string
	return &filetype =~# 'help\|man' ? '' : &modified ? '+' : &modifiable ? '' : '-'
enddef

def g:LightLineReadonly(): string
	return &filetype !~? 'help\|man' && &readonly ? '🔒' : ''
enddef

# Cached window type: returns 0=normal, 1=location, 2=quickfix,
# 3=preview, 4=terminal, 5=help, 6=man, 7=nofile(no name)
def GetWindowType(): number
	if exists('w:window_type')
		return w:window_type
	endif
	if &previewwindow
		w:window_type = 3
	elseif &buftype ==# 'terminal'
		w:window_type = 4
	elseif &filetype ==# 'help' || &buftype ==# 'help'
		w:window_type = 5
	elseif &buftype ==# 'nofile' && &filetype ==# 'man'
		w:window_type = 6
	elseif &buftype ==# 'nofile' && bufname('%') ==# '' && !&modified
		w:window_type = 7
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

# Cached git file detection. Result is stored in b:is_git_file,
# invalidated on BufEnter.
def IsGitFile(): number
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

# Invalidate per-buffer and per-window caches
augroup LightLineCache
	autocmd!
	autocmd BufEnter * unlet! b:is_git_file
	autocmd BufWinEnter,WinEnter * unlet! w:window_type
augroup END

# Combined git status component: gutter summary + branch name.
# Replaces LightLineGitGutter & LightLineFugitive; avoids calling
# GetWindowType() / IsGitFile() / FugitiveExtractGitDir() twice.
def g:LightLineGitInfo(): string
	if GetWindowType() != 0
		return ''
	endif
	if !IsGitFile()
		return ''
	endif
	var l_parts = []
	if getftype(expand('%')) ==# 'link'
		g:FugitiveDetect(resolve(expand('%')))
	endif
	var branch = g:FugitiveHead()
	if branch != ''
		add(l_parts, '⎇ ' .. branch)
	endif
	var s_summary = g:GitGutterGetHunkSummary()
	for item in [['+%d', s_summary[0]], ['~%d', s_summary[1]], ['-%d', s_summary[2]]]
		if item[1] != 0
			add(l_parts, printf(item[0], item[1]))
		endif
	endfor
	return join(l_parts, ' ')
enddef

def g:LightLineFilename(): string
	var wt = GetWindowType()
	if wt == 1 || wt == 2 || wt == 3
		return ''
	endif
	var ro = g:LightLineReadonly()
	var mod = g:LightLineModified()
	var fname = expand('%:t')
	if fname == ''
		fname = '[No Name]'
	endif
	return join(filter([ro, fname, mod], 'v:val != ""'), ' ')
enddef

def g:LightLineFileformat(): string
	return winwidth(0) > 70 ? &fileformat : ''
enddef

def g:LightLineFiletype(): string
	return winwidth(0) > 70 ? (&filetype != '' ? &filetype : 'unknown') : ''
enddef

def g:LightLineFileencoding(): string
	return winwidth(0) > 70 ? (&fileencoding != '' ? &fileencoding : &encoding) : ''
enddef

def g:LightLinePercent(): string
	return winwidth(0) > 70 ? printf('%3d%%', (100 * line('.') / line('$'))) : ''
enddef

def g:LightLineLineInfo(): string
	return winwidth(0) > 70 ? printf('%3d/%-d : %-2d', line('.'), line('$'), col('.')) : ''
enddef

def g:LightLineVMInfo(): string
	if GetWindowType() != 0
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
	return ''
enddef

def g:LightLineMode(): string
	var window_type = GetWindowType()
	if window_type != 0
		return window_type == 1 ? 'Location' :
			window_type == 2 ? 'Quickfix' :
			window_type == 3 ? 'Preview' :
			window_type == 4 ? 'Terminal' :
			window_type == 5 ? 'Help' :
			window_type == 6 ? 'Man' : ''
	endif

	if exists('b:VM_Selection') && !empty(b:VM_Selection)
		return 'V-MULTI'
	endif

	return winwidth(0) > 60 ? lightline#mode() : ''
enddef
# }

# vim-visual-multi lightline integration {
highlight VM_Mode cterm=bold ctermfg=232 ctermbg=141 gui=bold guifg=#1a1b26 guibg=#bb9af7
highlight VM_Info ctermfg=141 ctermbg=236 guifg=#bb9af7 guibg=#3b3f54

var saved_normal_left = []
def VMEnter()
	var pal = get(g:, 'lightline#colorscheme#sonokai#palette')
	saved_normal_left = copy(pal.normal.left[0])
	pal.normal.left[0] = ['#1a1b26', '#bb9af7', 232, 141, 'bold']
	lightline#highlight()
	lightline#update()
enddef

def VMLeave()
	if !empty(saved_normal_left)
		var pal = get(g:, 'lightline#colorscheme#sonokai#palette')
		pal.normal.left[0] = saved_normal_left
		saved_normal_left = []
	endif
	lightline#highlight()
	lightline#update()
enddef

augroup VMLightLine
	autocmd!
	autocmd User visual_multi_start silent VMEnter()
	autocmd User visual_multi_exit  silent VMLeave()
augroup END
# }

# Color support {
# Use true color when the terminal supports it
if has('termguicolors')
	# True color: Vim renders GUI colors (guifg/guibg) directly
	set termguicolors
else
	# Fallback: 256-color mode for terminals without true color support
	set t_Co=256

	# Disable Background Color Erase (BCE) so that color schemes
	# render properly when inside 256-color tmux and GNU screen.
	# See http://snk.tuxfamily.org/log/vim-256color-bce.html
	if &term =~# '256color'
		set t_ut=
	endif
endif
# }

# sonokai {
# Should be set before :colorscheme
g:sonokai_style = 'andromeda'
g:sonokai_better_performance = 1
g:sonokai_diagnostic_text_highlight = 1
g:sonokai_diagnostic_virtual_text = 'colored'
g:sonokai_dim_inactive_windows = 1

set background=dark
colorscheme sonokai

# sonokai explicitly defines MatchParenCur/MatchWord,
# which blocks vim-matchup's hi def link. Re-link them.
highlight! link MatchParen Search
highlight! link MatchParenCur Search
highlight! link MatchWord Search
highlight! link MatchWordCur Search
# }

# Key map {
# Make Y behave like other capitals
nnoremap Y y$

# Improve up/down movement on wrapped lines
noremap j gj
noremap k gk

# Jump to start and end of line using the home row keys
noremap H ^
noremap L $

# Keep text selected after manual indentation
vnoremap < <gv
vnoremap > >gv

noremap ; :

# Remap U to <C-r> for easier redo
nnoremap U <C-r>

# Better insert mode moving and editing
inoremap <C-p> <Up>
inoremap <C-n> <Down>
inoremap <C-b> <Left>
inoremap <C-f> <Right>
inoremap <C-a> <Home>
inoremap <C-e> <End>
inoremap <C-h> <BackSpace>
inoremap <C-d> <Del>

# Better command mode moving and editing
cnoremap <C-p> <Up>
cnoremap <C-n> <Down>
cnoremap <C-b> <Left>
cnoremap <C-f> <Right>
cnoremap <C-a> <Home>
cnoremap <C-e> <End>
cnoremap <C-h> <BackSpace>
cnoremap <C-d> <Del>

def SendExitToAllTerminals()
	for buf in getbufinfo()
		if getbufvar(buf.bufnr, '&buftype') == 'terminal' && term_getstatus(buf.bufnr) =~ 'running'
			term_sendkeys(buf.bufnr, "exit\<CR>")
		endif
	endfor
enddef

def IsAuxiliaryWindow(winnr: number): number
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

def FocusToValidWindow()
	if !IsAuxiliaryWindow(winnr())
		return
	endif
	for info in getwininfo()
		if !IsAuxiliaryWindow(info.winnr)
			win_gotoid(info.winid)
			return
		endif
	endfor
enddef

def CloseFugitiveDiff(): number
	if !&diff
		return 0
	endif
	for wn in range(1, winnr('$'))
		var winid = win_getid(wn)
		var buf = winbufnr(wn)
		var name = bufname(buf)
		var bt = getbufvar(buf, '&buftype')
		if name =~# '^fugitive:' || name =~# '^gitgutter:' || (empty(name) && bt ==# 'nofile')
			win_execute(winid, 'quit')
			return 1
		endif
	endfor
	return 0
enddef

def QuitAll()
	SendExitToAllTerminals()
	silent! confirm quitall!
enddef

def Quit()
	if CloseFugitiveDiff()
		return
	endif

	var cur_tab = tabpagenr()
	var cur = win_getid()
	var has_other_window = 0
	var total_valid = 0
	var tab_valid = 0

	for info in getwininfo()
		if info.winid == cur
			continue
		endif
		has_other_window = 1
		if !IsAuxiliaryWindow(info.winnr)
			total_valid += 1
			if info.tabnr == cur_tab
				tab_valid += 1
			endif
		endif
	endfor

	if !has_other_window || total_valid == 0
		QuitAll()
	elseif tab_valid == 0
		tabclose
		FocusToValidWindow()
	else
		quit
		FocusToValidWindow()
	endif
enddef

nnoremap <silent>q <ScriptCmd>call Quit()<CR>
nnoremap <silent><S-q> <ScriptCmd>call QuitAll()<CR>

nnoremap t q
vnoremap t q
# }

# Terminal {
def TerminalToggle()
	var termrows = 20
	if exists('t:terminal_bufnr') && bufexists(t:terminal_bufnr) && term_getstatus(t:terminal_bufnr) =~# 'running'
		var winid = bufwinid(t:terminal_bufnr)
		if winid != -1
			win_execute(winid, 'hide')
		else
			execute 'botright sbuffer ' .. t:terminal_bufnr
			execute 'resize ' .. termrows
			feedkeys("i", 't')
		endif
	else
		execute 'botright terminal ++rows=' .. termrows
		t:terminal_bufnr = bufnr('%')
	endif
enddef

tnoremap <silent><ScrollWheelUp> <C-\><C-n><ScrollWheelUp>
tnoremap <silent><ScrollWheelDown> <C-\><C-n><ScrollWheelDown>
nnoremap <F3> :botright terminal ++rows=20<Space>
nnoremap <silent><F4> <ScriptCmd>call TerminalToggle()<CR>
tnoremap <silent><F4> <C-\><C-n><ScriptCmd>call TerminalToggle()<CR>

augroup TermSettings
	autocmd!
	autocmd TerminalOpen * if &buftype ==# 'terminal' && bufname('%') !~# 'fzf' | setlocal nobuflisted bufhidden=hide scrolloff=0 | endif
augroup END
# }

def OpenPrompt(prompt: string, cmd: string)
	var name = Strip(input(prompt, '', 'file'))
	if name !=# ''
		execute cmd .. ' ' .. fnameescape(name)
	endif
enddef

def Strip(input_string: string): string
	return substitute(input_string, '^\s*\(.\{-}\)\s*$', '\1', '')
enddef

# Buffer {
nnoremap <silent><Leader>o <ScriptCmd>call OpenPrompt('New buffer name: ', 'edit')<CR>

nnoremap <silent>[b <Cmd>bprevious<CR>
nnoremap <silent>]b <Cmd>bnext<CR>
# }

# Tab {
nnoremap <silent><Leader><Leader>t <ScriptCmd>call OpenPrompt('New tab name: ', 'tabnew')<CR>
nnoremap <silent>[t <Cmd>tabprevious<CR>
nnoremap <silent>]t <Cmd>tabnext<CR>
nnoremap <Leader>1 <Cmd>1tabnext<CR>
nnoremap <Leader>2 <Cmd>2tabnext<CR>
nnoremap <Leader>3 <Cmd>3tabnext<CR>
nnoremap <Leader>4 <Cmd>4tabnext<CR>
nnoremap <Leader>5 <Cmd>5tabnext<CR>
nnoremap <Leader>6 <Cmd>6tabnext<CR>
nnoremap <Leader>7 <Cmd>7tabnext<CR>
nnoremap <Leader>8 <Cmd>8tabnext<CR>
nnoremap <Leader>9 <Cmd>9tabnext<CR>
nnoremap <Leader>[ <Cmd>tabfirst<CR>
nnoremap <Leader>] <Cmd>tablast<CR>
# }

# Split {
nnoremap <C-j> <C-w>j
nnoremap <C-k> <C-w>k
nnoremap <C-h> <C-w>h
nnoremap <C-l> <C-w>l
nnoremap <silent><Leader><Leader>s <ScriptCmd>call OpenPrompt('New split name: ', 'split')<CR>
nnoremap <silent><Leader><Leader>v <ScriptCmd>call OpenPrompt('New vsplit name: ', 'vsplit')<CR>
# }

# F1 ~ F10 {
nmap <F1> <Plug>CtrlSFPrompt
nnoremap <silent><F2> <Cmd>CtrlSFToggle<CR>
# }

# Toggle {
nnoremap <silent>cod :<C-R>=&diff ? 'diffoff' : 'diffthis'<CR><CR>
nnoremap <silent>cop <Cmd>set invpaste<CR>
nnoremap <silent>col <Cmd>set invlist<CR>
nnoremap <silent>con <Cmd>nohlsearch<CR>
nnoremap <silent><Leader><Space> :%s/\s\+$//e<CR>:nohlsearch<CR>
# <Leader><Leader><Space>: strip trailing whitespace + \r (DOS newline)
nnoremap <silent><Leader><Leader><Space> :%s/\s\+$//e<CR>:%s/\r$//e<CR>:nohlsearch<CR>

# Disable paste mode when leaving insert mode
augroup PasteMode
	autocmd!
	autocmd InsertLeave * setlocal nopaste
augroup END
# }

# Zoom {
def ZoomToggle()
	if exists('t:zoomed') && t:zoomed && win_id2win(t:zoom_winid) != 0
		if winnr('$') == t:zoom_wincount
			execute t:zoom_winrestcmd
		endif
		t:zoomed = false
	else
		t:zoom_winid = win_getid()
		t:zoom_wincount = winnr('$')
		t:zoom_winrestcmd = winrestcmd()
		wincmd _
		wincmd |
		t:zoomed = true
	endif
enddef

nnoremap <silent><Leader>z <ScriptCmd>call ZoomToggle()<CR>
tnoremap <silent><Leader>z <ScriptCmd>call ZoomToggle()<CR>
# }

# vim-dirvish {
nnoremap <silent>- <Cmd>execute 'Dirvish' expand('%:p:h')<CR>
nnoremap <silent>~ <ScriptCmd>execute('Dirvish ' .. GetProjectOrHome())<CR>

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
# }

# ctrlsf.vim {
g:ctrlsf_confirm_save = 0
g:ctrlsf_extra_backend_args = {
			\ 'rg': '--hidden',
			\ 'ag': '--hidden',
			\ }
g:ctrlsf_ignore_dir = ['.git', '.hg', '.svn', '.bzr']

nnoremap <silent><Leader>a <Plug>CtrlSFCwordExec
vnoremap <silent><Leader>a <Plug>CtrlSFVwordExec
# }

# vim-rooter {
g:rooter_patterns = ['.root', '.git', '.hg', '.svn', '.bzr', '_darcs', '_FOSSIL_', '.fslckout']
g:rooter_silent_chdir = 1
g:rooter_change_directory_for_non_project_files = 'current'
g:rooter_resolve_links = 1
g:rooter_manual_only = 1

nnoremap <silent><Leader>cr <Cmd>Rooter<CR>

augroup ChangeRoot
	autocmd!
	# Change the working directory on vim startup
	autocmd VimEnter * :Rooter
augroup END
# }

# Ctags {
augroup Ctags
	autocmd!
	# Highlight .tags file as tags file
	autocmd BufNewFile,BufRead *.tags setfiletype tags
augroup END
# }

# cscope {
set cscopequickfix=s-,c-,d-,i-,t-,e-,f-,g-,a-

nnoremap <silent>gs <Cmd>cscope find s <cword><CR>
nnoremap <silent>gD <ScriptCmd>call GotoDefinition('cscope find g ' .. expand('<cword>'))<CR>
nnoremap <silent>gR <Cmd>cscope find c <cword><CR>

augroup CscopeQuickfix
	autocmd!
	autocmd QuickfixCmdPre cscope call setqflist([], 'r') | call setloclist(0, [], 'r')
	autocmd QuickfixCmdPost cscope if !empty(getloclist(0)) | lwindow | endif
	autocmd QuickfixCmdPost cscope if !empty(getqflist()) | cwindow | endif
augroup END
# }

# vim-gutentags {
if executable('gtags') && has('cscope')
	$GTAGSLABEL = 'native-pygments'
	var gtags_conf_candidates = [
		'/usr/local/etc/gtags.conf',
		'/etc/gtags.conf',
		'/etc/gtags/gtags.conf',
		'/usr/share/gtags/gtags.conf',
		'/usr/local/share/gtags/gtags.conf',
		'/usr/local/opt/global/share/gtags/gtags.conf',
		'/opt/homebrew/etc/gtags.conf',
		'/opt/homebrew/share/gtags/gtags.conf',
		'/opt/homebrew/opt/global/share/gtags/gtags.conf',
	]
	if !empty($GTAGSCONF)
		insert(gtags_conf_candidates, $GTAGSCONF)
	endif
	for gtags_conf in gtags_conf_candidates
		if filereadable(gtags_conf) && stridx(join(readfile(gtags_conf), "\n"), 'native-pygments:') >= 0
			$GTAGSCONF = gtags_conf
			break
		endif
	endfor
	g:gutentags_modules = ['ctags', 'gtags_cscope']
else
	g:gutentags_modules = ['ctags']
endif
g:gutentags_project_root = ['.root', '.git', '.hg', '.svn', '.bzr', '_darcs', '_FOSSIL_', '.fslckout']
g:gutentags_cache_dir = expand($HOME .. '/.cache/tags')
g:gutentags_ctags_tagfile = '.tags'
g:gutentags_ctags_auto_set_tags = 1
g:gutentags_ctags_extra_args = [
	'--fields=+liaS',
	'--extras=+q',
	'--langmap=c:.c.h,vim:.vim.vimrc',
	'--c-kinds=+p',
	'--c++-kinds=+p',
	'--python-kinds=+i',
]
g:gutentags_auto_add_gtags_cscope = 1
g:gutentags_generate_on_missing = 1
g:gutentags_generate_on_new = 0
g:gutentags_generate_on_write = 1
g:gutentags_background_update = 1
g:gutentags_resolve_symlinks = 1
g:gutentags_define_advanced_commands = 1
# }

# vim-qf {
g:qf_mapping_ack_style = 1
g:qf_window_bottom = 1
g:qf_loclist_window_bottom = 1
g:qf_auto_resize = 1
g:qf_max_height = 10
g:qf_auto_open_quickfix = 0
g:qf_auto_open_loclist = 0
g:qf_auto_quit = 1

def QuickFixToggle(type: string, cmd: string)
	var ftype = &filetype
	var last_winnr = winnr('#')
	var buffer_count_before = BufferCount()
	if type ==# 'quickfix' || type ==# 'q'
		silent! cclose
	elseif type ==# 'location' || type ==# 'l'
		silent! lclose
	endif

	if BufferCount() == buffer_count_before
		execute cmd
	else
		if ftype ==# 'qf'
			silent! execute last_winnr .. 'wincmd w'
		endif
	endif
enddef

def BufferCount(): number
	return len(tabpagebuflist())
enddef

nnoremap <silent><Leader>d <ScriptCmd>call QuickFixToggle('l', 'LspDiag show')<CR>
nnoremap <silent><Leader>q <ScriptCmd>call QuickFixToggle('q', 'silent! botright copen 10')<CR>
nnoremap <silent><Leader>l <ScriptCmd>call QuickFixToggle('l', 'silent! lopen 10')<CR>
# }

# vim-fugitive {
nnoremap <silent><Leader>gg <Cmd>Git<CR>
nnoremap <silent><Leader>gd <Cmd>Gdiffsplit!<CR>
nnoremap <silent><Leader>gD <Cmd>Git diff<CR>
map <silent><Leader>gb <Cmd>Git blame<CR>
# }

# gv.vim {
map <silent><Leader>gl <Cmd>GV!<CR>
map <silent><Leader>gL <Cmd>GV<CR>
# }

# vim-gitgutter {
g:gitgutter_map_keys = 0
g:gitgutter_preview_win_floating = 1

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
# }

# Session {
set sessionoptions-=blank sessionoptions-=options sessionoptions-=folds sessionoptions-=terminal

def GetSessionFileInfo(): list<string>
	var session_dir = expand($HOME .. '/.cache/sessions/')
	var session_filename = session_dir .. substitute(trim(GetFileroot(), '/', 1), '/', '-', 'g') .. '-session.vim'
	return [session_dir, session_filename]
enddef

def BackupSession()
	var session_info = GetSessionFileInfo()
	var session_dir = session_info[0]
	var session_filename = session_info[1]
	mkdir(session_dir, 'p')
	execute 'Obsession' session_filename
enddef

def RestoreSession()
	var session_info = GetSessionFileInfo()
	var session_filename = session_info[1]
	if argc() == 0 && filereadable(session_filename)
		FixVim9SessionFile(session_filename)
		execute 'source' session_filename
	endif
enddef

def FixVim9SessionFile(file: string)
	# Since Vim 9.2 (patch 9.2.0579) :mksession writes Vim9 script, but the
	# Obsession plugin inserts legacy "let g:this_session = ..." lines which are
	# not allowed in a Vim9 script (E1126).  Rewrite them without ":let".
	if !filereadable(file)
		return
	endif
	var lines = readfile(file)
	if empty(lines) || lines[0] !=# 'vim9script'
		return
	endif
	var changed = false
	var i = 0
	while i < len(lines)
		if lines[i] =~# '^let g:this_'
			lines[i] = substitute(lines[i], '^let ', '', '')
			changed = true
		endif
		i += 1
	endwhile
	if changed
		writefile(lines, file)
	endif
enddef

# Backup
nnoremap <Leader>ws <ScriptCmd>call BackupSession()<CR>
# Remove
nnoremap <Leader>rs <Cmd>Obsession!<CR>

augroup Session
	autocmd!
	# Obsession fires User Obsession after every persist; keep the saved file usable.
	autocmd User Obsession FixVim9SessionFile(g:this_session)
	autocmd VimEnter * ++nested RestoreSession()
augroup END
# }

# fzf.vim {
$FZF_DEFAULT_OPTS = '--layout=reverse'
g:fzf_layout = { 'window': { 'width': 0.8, 'height': 0.9 } }
g:fzf_preview_window = ['right:60%']
g:fzf_action = {
			\ 'ctrl-s': 'split',
			\ 'ctrl-v': 'vsplit',
			\ 'ctrl-t': 'tab split',
			\ }

nnoremap <silent><C-p> <Cmd>Files<CR>
nnoremap <silent><Leader>b <ScriptCmd>call FzfBuffers()<CR>
nnoremap <silent><Leader>t <Cmd>BTags<CR>
nnoremap <silent><Leader>p <Cmd>Tags<CR>
nnoremap <silent><Leader>f <ScriptCmd>call FzfLspDocSymbols([6, 9, 12])<CR>
nnoremap <silent><Leader>e <Cmd>BLines<CR>

imap <C-x><C-p> <Plug>(fzf-complete-path)
imap <C-x><C-l> <Plug>(fzf-complete-line)
imap <C-x><C-b> <Plug>(fzf-complete-buffer-line)

def FzfBuffers()
	g:__fzf_buffers_delete_file = tempname()
	var spec = {
		'options': [
			'--no-footer',
			'--bind', 'ctrl-d:execute-silent(echo {} >> ' .. g:__fzf_buffers_delete_file .. ')+exclude',
			'--bind', 'ctrl-alt-x:execute-silent(echo {} >> ' .. g:__fzf_buffers_delete_file .. ')+exclude',
		],
		'exit': function('BufferExit')
	}
	fzf#vim#buffers('', fzf#vim#with_preview(spec, 'right:60%'))
enddef

def BufferExit(code: number)
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

def LspSymbolSink(line: string)
	var lnum = str2nr(split(line, "\t")[-1])
	if lnum > 0
		execute 'keepjumps normal! ' .. lnum .. 'G'
	endif
enddef

def FlattenDocSymbols(syms: list<dict<any>>, srv: dict<any>, bnr: number, kinds: list<number>): list<string>
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

def Err(msg: string)
	echohl ErrorMsg
	echo msg
	echohl None
enddef

def FzfLspDocSymbols(types: list<number>)
	var srv = lsp#buffer#CurbufGetServer('documentSymbol')
	if empty(srv) || !srv.running || !srv.ready
		Err('No ready LSP server with documentSymbol support for this buffer')
		return
	endif
	var reply = srv.rpc('textDocument/documentSymbol', {'textDocument': {'uri': lsp#util#LspFileToUri(expand('%:p'))}})
	if empty(reply) || !has_key(reply, 'result') || empty(reply.result)
		Err('No document symbols returned by the LSP server')
		return
	endif
	if type(reply.result) != v:t_list
		return
	endif
	var entries = FlattenDocSymbols(reply.result, srv, bufnr('%'), types)
	var opts = {
		'source': entries,
		'sink': function('LspSymbolSink'),
		'options': ['--delimiter=\t', '-n', '1', '--with-nth=1'],
		'placeholder': fzf#shellescape(expand('%:p')) .. ':{2}',
	}
	fzf#run(fzf#wrap('lspdoc', fzf#vim#with_preview(opts, 'right:60%:+{2}/2')))
enddef
# }

# vim9-stargate {
g:stargate_name = 'QMonkey'

# For 1 character to search before showing hints
noremap f <Cmd>call stargate#OKvim(1)<CR>
# For 2 consecutive characters to search
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
# }

# vim-subversive {
nnoremap s <plug>(SubversiveSubstitute)
xnoremap s <plug>(SubversiveSubstitute)
nnoremap ss <plug>(SubversiveSubstituteLine)
nnoremap S <plug>(SubversiveSubstituteToEndOfLine)
# }

# vim-asterisk {
map *  <Plug>(asterisk-z*)
map g* <Plug>(asterisk-gz*)
map #  <Plug>(asterisk-z#)
map g# <Plug>(asterisk-gz#)
# }

# vim-visual-multi {
g:VM_maps = {}
g:VM_maps['Select Operator'] = 'gs'
g:VM_set_statusline = 0
g:VM_silent_exit = 1
# }

# FastFold {
# Only update fold after type zx or zX
g:fastfold_fold_command_suffixes = ['x', 'X', 'a', 'A']
g:fastfold_fold_movement_commands = []
# }

# vim-signature {
# Highlight mark a-zA-Z
highlight SignatureMarkText cterm=bold ctermfg=154 gui=bold guifg=#A6E22E

# Highlight marker !@#$%^&*()
highlight SignatureMarkerText term=bold cterm=bold ctermfg=197 gui=bold guifg=#F92672

g:SignatureMarkTextHLDynamic = 1
g:SignatureMarkerTextHLDynamic = 1
# }

# lsp {
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
		diagSignErrorText: 'E>',
		diagSignHintText: 'H>',
		diagSignInfoText: 'I>',
		diagSignWarningText: 'W>',
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
		popupBorderSignatureHelp: true,
		popupHighlightSignatureHelp: 'Pmenu',
		popupHighlight: 'Normal',
		popupHighlightCompletion: 'Pmenu',
		semanticHighlight: true,
		semanticHighlightDelay: 300,
		showDiagInBalloon: true,
		showDiagInPopup: true,
		showDiagOnStatusLine: false,
		showDiagWithSign: true,
		showDiagWithVirtualText: true,
		showInlayHints: false,
		showSignature: true,
		showSignatureDocs: true,
		snippetSupport: true,
		ultisnipsSupport: false,
		useBufferCompletion: false,
		usePopupInCodeAction: false,
		useQuickfixForLocations: true,
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
			'--background-index-priority=background',
			'--clang-tidy',
			'--cross-file-rename',
			'--all-scopes-completion=true',
			'--completion-style=detailed',
			'--function-arg-placeholders=true',
			'--header-insertion=iwyu',
			'--header-insertion-decorators',
			'--limit-references=0',
			'--limit-results=0'
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
					'url': 'https://www.schemastore.org/api/json/catalog.json',
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

# Fallback: use <C-]> (tag jump) when no LSP is attached
nnoremap gd <C-]>

def GotoDefinition(cmd: string)
	var pos = getcurpos()
	silent! execute cmd
	if getcurpos()[: 1] == pos[: 1]
		silent! execute 'tag ' .. expand('<cword>')
	endif
enddef

def OnLspAttached()
	setlocal formatexpr=lsp#lsp#FormatExpr()

	nnoremap <silent><buffer>gh <Cmd>LspHover<CR>
	nnoremap <silent><buffer>gd <ScriptCmd>call GotoDefinition('LspGotoDefinition')<CR>
	nnoremap <silent><buffer>gc <Cmd>LspGotoDeclaration<CR>
	nnoremap <silent><buffer>gt <Cmd>LspGotoTypeDef<CR>
	nnoremap <silent><buffer>gi <Cmd>LspGotoImpl<CR>
	nnoremap <silent><buffer>gr <Cmd>LspShowReferences<CR>

	nnoremap <silent><buffer>[d <Cmd>LspDiag prevWrap<CR>
	nnoremap <silent><buffer>]d <Cmd>LspDiag nextWrap<CR>
	nnoremap <silent><buffer>[D <Cmd>LspDiag first<CR>
	nnoremap <silent><buffer>]D <Cmd>LspDiag last<CR>
	nnoremap <silent><buffer><Leader>gh <Cmd>LspDiag! current<CR>

	nnoremap <silent><buffer><Leader>rn <Cmd>LspRename<CR>
enddef

augroup Lsp
	autocmd!
	autocmd User LspSetup OnLspSetup()
	autocmd User LspAttached OnLspAttached()
	autocmd BufWritePre * if !empty(lsp#buffer#CurbufGetServer('documentFormatting')) | LspFormat | endif
augroup END
# }

# vim-vsnip {
# Expand or jump
imap <expr> <C-l> pumvisible() ? '<C-y>' : vsnip#available(1) ? '<Plug>(vsnip-expand-or-jump)' : '<C-l>'
smap <expr> <C-l> vsnip#available(1) ? '<Plug>(vsnip-expand-or-jump)' : '<C-l>'

# Jump forward or backward
imap <expr> <Tab> vsnip#jumpable(1) ? '<Plug>(vsnip-jump-next)' : '<Tab>'
smap <expr> <Tab> vsnip#jumpable(1) ? '<Plug>(vsnip-jump-next)' : '<Tab>'
imap <expr> <S-Tab> vsnip#jumpable(-1) ? '<Plug>(vsnip-jump-prev)' : '<S-Tab>'
smap <expr> <S-Tab> vsnip#jumpable(-1) ? '<Plug>(vsnip-jump-prev)' : '<S-Tab>'
# }

# Terminal env {
if !has('gui_running')
	if &t_fe == ''
		# Enable focus event tracking for terminal vim.
		# Most terminal terminfo entries lack Ss/Se capability definitions,
		# causing t_fe/t_fd to remain empty. Set them manually so that
		# FocusGained/FocusLost autocommands work (e.g. for checktime).
		&t_fe = "\<Esc>[?1004h"
		&t_fd = "\<Esc>[?1004l"
		execute "set <FocusGained>=\<Esc>[I"
		execute "set <FocusLost>=\<Esc>[O"
	endif

	augroup CheckFileChanges
		autocmd!
		# Check file changes outside vim (terminal/TTY/kmscon)
		autocmd FocusGained,BufWinEnter,WinEnter,CursorHold * if getcmdtype() ==# '' | checktime | endif
	augroup END
endif
# }
