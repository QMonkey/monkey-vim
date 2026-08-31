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
		autocmd VimEnter * PlugInstall | mkdir($HOME . '/.vim/swap/', 'p') | source $MYVIMRC
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
# Theme / UI
Plug 'sainnhe/sonokai'
# Editor
Plug 'svermeulen/vim-subversive'
Plug 'wellle/targets.vim'
Plug 'michaeljsmith/vim-indent-object'
Plug 'tpope/vim-surround' | Plug 'tpope/vim-repeat'
Plug 'cohama/lexima.vim'
Plug 'andymass/vim-matchup'
Plug 'Konfekt/FastFold'
Plug 'kshenoy/vim-signature'
# Navigation / Search
Plug 'junegunn/fzf' | Plug 'junegunn/fzf.vim'
Plug 'dyng/ctrlsf.vim', {'on': ['CtrlSF', 'CtrlSFQuickfix', 'CtrlSFToggle', 'CtrlSFOpen', 'CtrlSFUpdate', 'CtrlSFClose', 'CtrlSFFocus', '<Plug>CtrlSFPrompt', '<Plug>CtrlSFCwordExec', '<Plug>CtrlSFVwordExec']}
Plug 'monkoose/vim9-stargate'
Plug 'haya14busa/vim-asterisk'
# Git
Plug 'tpope/vim-fugitive' | Plug 'junegunn/gv.vim', {'on': 'GV'}
Plug 'airblade/vim-gitgutter'
# Project
Plug 'airblade/vim-rooter'
Plug 'ludovicchabant/vim-gutentags'
Plug 'justinmk/vim-dirvish'
Plug 'tpope/vim-obsession'
# Code Intelligence
Plug 'yegappan/lsp', {'on': []}
Plug 'hrsh7th/vim-vsnip', {'on': []} | Plug 'hrsh7th/vim-vsnip-integ', {'on': []} | Plug 'rafamadriz/friendly-snippets', {'on': []}
# Tools
Plug 'mg979/vim-visual-multi'
Plug 'tpope/vim-eunuch'
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

# Disable the window-local statusline set by ftplugin/qf.vim (8.1.1715+)
g:qf_disable_statusline = 1
# }

# Leader {
g:mapleader = ','
g:maplocalleader = ','
# }

# Terminal type detection {
# Detect the outermost terminal type by walking up the real process
# tree from the current Vim (or its tmux client). Needed before the
# color block because a tmux client running on a physical tty reports
# &term = tmux-256color, hiding the 8/16-color console behind it.
# Return value: 'kmscon' | 'tty' | 'physical_console' | 'pseudo_terminal' | 'remote_ssh' | 'no_tty' | 'unknown'
def GetRootTerminalType(): string
	var pid = getpid()
	if !empty($TMUX)
		var pid_str = trim(system('tmux display-message -p "#{client_pid}" 2>/dev/null'))
		if pid_str =~ '^[0-9]\+$'
			pid = str2nr(pid_str)
		endif
	endif

	var uname = trim(system('uname -s'))
	if empty(uname) || uname =~? 'unknown'
		return 'unknown'
	endif

	var last_tty = ''
	var saw_login = false
	var saw_sshd = false
	for _ in range(10)
		var line = trim(system('ps -o ppid=,tty=,comm= -p ' .. pid))
		var parts = matchlist(line, '^\s*\(\S\+\)\s\+\(\S\+\)\s*\(.*\)$')
		if empty(parts)
			break
		endif
		var ppid = parts[1]
		var tty = parts[2]
		var comm = parts[3]
		if comm ==# 'kmscon'
			return 'kmscon'
		endif
		if comm ==# 'login'
			saw_login = true
		endif
		if comm =~# '^sshd'
			saw_sshd = true
		endif
		if tty != '' && tty != '?'
			last_tty = tty
		endif
		if ppid == '' || str2nr(ppid) <= 1
			break
		endif
		pid = str2nr(ppid)
	endfor

	if last_tty == '' && !saw_login
		return 'no_tty'
	endif
	if uname =~? 'Linux'
		if last_tty =~ '^tty[0-9]\+$' || saw_login
			return 'tty'
		elseif last_tty =~ '^pts/'
			return saw_sshd ? 'remote_ssh' : 'pseudo_terminal'
		endif
	endif
	if uname =~? 'Darwin'
		return last_tty ==# 'console' || last_tty ==# '/dev/console'
			? 'physical_console' : 'pseudo_terminal'
	endif
	return 'unknown'
enddef

var root_terminal = GetRootTerminalType()
var is_tty_console = &term =~# '^linux' || root_terminal ==# 'tty'
# }

# Color support {
# The Linux framebuffer console (tty1-tty63, TERM=linux) has no true
# color and sonokai is a true-color-only theme (its `&t_Co < 256 -> finish`
# guard makes it a no-op there). Detect it, moreover via a physical tty
# under a tmux client that masks the term as tmux-256color, so we can fall
# back to the built-in unokai theme below.
if has('termguicolors') && !is_tty_console
	# True color: Vim renders GUI colors (guifg/guibg) directly
	set termguicolors
else
	set notermguicolors
	if !is_tty_console
		# Fallback: 256-color mode for terminals without true color support
		set t_Co=256
	else
		# The console physically supports 16 colors (8 base + 8 bright);
		# &t_Co=16 picks unokai's richer `t_Co >= 16` named-color branch
		# over its cruder 8-color one.
		set t_Co=16
	endif

	# Disable Background Color Erase (BCE) so that color schemes
	# render properly when inside 256-color tmux and GNU screen.
	# See http://snk.tuxfamily.org/log/vim-256color-bce.html
	if &term =~# '256color'
		set t_ut=
	endif
endif
# }

# Theme {
# unokai is a built-in Monokai-style theme whose named-color branches
# match the console's fixed VGA palette, keeping a sonokai-like look when
# is_tty_console.
set background=dark
if !is_tty_console
	# sonokai settings must be set before :colorscheme
	g:sonokai_style = 'andromeda'
	g:sonokai_better_performance = 1
	g:sonokai_diagnostic_text_highlight = 1
	g:sonokai_diagnostic_virtual_text = 'colored'
	g:sonokai_dim_inactive_windows = 1
	colorscheme sonokai
else
	colorscheme unokai
endif
# }

# manual statusline + tabline {
# Draw paths read only builtins + cached values (never system()/plugins).
# Git/LSP data is recomputed on events (BufEnter/BufWritePost/CursorHold/
# LspDiagsUpdated) into b:git_info, b:diagnostic_info.

# Mode -> [label, highlight-group]
const mode_map = {
	'n': ['NORMAL', 'Normal'], 'i': ['INSERT', 'Insert'], 'R': ['REPLACE', 'Replace'],
	'v': ['VISUAL', 'Visual'], 'V': ['V-LINE', 'Visual'], "\<C-v>": ['V-BLOCK', 'Visual'],
	'c': ['COMMAND', 'Command'], 's': ['SELECT', 'Visual'], 'S': ['S-LINE', 'Visual'],
	"\<C-s>": ['S-BLOCK', 'Visual'],
	't': ['TERMINAL', 'Terminal'],
}

# Palette (truecolor = sonokai "andromeda", console = 16color)
# Each color is [gui, cterm]; gui is '' on the console.
def StatusPalette(): dict<any>
	if !is_tty_console
		return {
			'modeFg': { 'Normal': ['#2b2d3a', 235], 'Insert': ['#2b2d3a', 235], 'Visual': ['#2b2d3a', 235], 'Replace': ['#2b2d3a', 235], 'Command': ['#2b2d3a', 235], 'Terminal': ['#2b2d3a', 235] },
			'modeBg': { 'Normal': ['#77d5f0', 110], 'Insert': ['#a9dc76', 107], 'Visual': ['#bb97ee', 176], 'Replace': ['#f89860', 215], 'Command': ['#edc763', 179], 'Terminal': ['#ff6188', 203] },
			'l2': [['#e1e3e4', 250], ['#3f445b', 237]], 'base': [['#e1e3e4', 250], ['#393e53', 237]],
			'Midline': [['#e1e3e4', 250], ['#333648', 236]], 'Inactive': [['#7e8294', 246], ['#333648', 236]],
			'TabSelected': [['#2b2d3a', 235], ['#ff6188', 203]], 'TabInactive': [['#7e8294', 246], ['#333648', 236]],
			'diagnosticFg': { 'Error': ['#fb617e', 203], 'Warn': ['#edc763', 179], 'Hint': ['#bb97ee', 176], 'Info': ['#6dcae8', 110] },
		}
	endif
	return {
		'modeFg': { 'Normal': ['', 15], 'Insert': ['', 15], 'Visual': ['', 15], 'Replace': ['', 15], 'Command': ['', 0], 'Terminal': ['', 15] },
		'modeBg': { 'Normal': ['', 12], 'Insert': ['', 2], 'Visual': ['', 5], 'Replace': ['', 9], 'Command': ['', 11], 'Terminal': ['', 9] },
		'l2': [['', 15], ['', 8]], 'base': [['', 7], ['', 0]], 'Midline': [['', 7], ['', 0]],
		'Inactive': [['', 7], ['', 8]], 'TabSelected': [['', 15], ['', 12]], 'TabInactive': [['', 7], ['', 8]],
		'diagnosticFg': { 'Error': ['', 9], 'Warn': ['', 11], 'Hint': ['', 13], 'Info': ['', 14] },
	}
enddef

# color is a pair [fg, bg], each itself a [gui, cterm] pair.
def StatusHighlight(name: string, color: list<any>, bold: bool)
	var fg = color[0]
	var bg = color[1]
	var attr = bold ? 'bold' : 'none'
	if fg[0] == ''
		execute printf('highlight %s term=%s ctermfg=%d ctermbg=%d', name, attr, fg[1], bg[1])
	else
		execute printf('highlight %s term=%s guifg=%s guibg=%s ctermfg=%d ctermbg=%d',
			name, attr, fg[0], bg[0], fg[1], bg[1])
	endif
enddef

# Define all status/tab highlight groups from the current palette.
def StatusDefineHighlights()
	var pal = StatusPalette()
	for [mkey, mbg] in items(pal.modeBg)
		StatusHighlight('StlMode' .. mkey, [[pal.modeFg[mkey][0], pal.modeFg[mkey][1]], mbg], true)
	endfor
	StatusHighlight('StlL2', pal.l2, false)
	StatusHighlight('StlBase', pal.base, false)
	StatusHighlight('StlMidline', pal.Midline, false)
	StatusHighlight('StlInactive', pal.Inactive, false)
	StatusHighlight('StlTabSelected', pal.TabSelected, true)
	StatusHighlight('StlTabInactive', pal.TabInactive, false)
	StatusHighlight('StlTabMidline', pal.Midline, false)
	for [dkey, dfg] in items(pal.diagnosticFg)
		StatusHighlight('StlDiagnostic' .. dkey, [dfg, pal.l2[1]], false)
	endfor
enddef

# Window type (0 = normal file window): 1 loclist, 2 quickfix, 3 preview,
# 4 terminal, 5 help, 6 man, 7 empty nofile. Works on any window number;
# shared by the statusline labels and the auxiliary-window checks in Quit.
def WindowTypeOf(winnr: number): number
	var bufnr = winbufnr(winnr)
	if bufnr == -1
		return 0
	endif
	if getwinvar(winnr, '&previewwindow')
		return 3
	endif
	var bt = getbufvar(bufnr, '&buftype')
	if bt ==# 'terminal'
		return 4
	endif
	if bt ==# 'help' || getbufvar(bufnr, '&filetype') ==# 'help'
		return 5
	endif
	if bt ==# 'nofile' && getbufvar(bufnr, '&filetype') ==# 'man'
		return 6
	endif
	if bt ==# 'nofile' && bufname(bufnr) ==# '' && !getbufvar(bufnr, '&modified')
		return 7
	endif
	if getbufvar(bufnr, '&filetype') ==# 'qf'
		return qf#IsLocWindow(winnr) ? 1 : 2
	endif
	return 0
enddef

# Window type of the current window, cached until the next WinEnter
def WindowType(): number
	if exists('w:window_type')
		return w:window_type
	endif
	w:window_type = WindowTypeOf(winnr())
	return w:window_type
enddef

def WindowTypeLabel(): string
	var wt = WindowType()
	return wt == 1 ? 'Location' : wt == 2 ? 'Quickfix' : wt == 3 ? 'Preview' :
		wt == 4 ? 'Terminal' : wt == 5 ? 'Help' : wt == 6 ? 'Man' : ''
enddef

# Mode label (left, colored block)
def ModeLabel(): string
	var wt = WindowType()
	if wt != 0
		return WindowTypeLabel()
	endif
	if exists('b:VM_Selection') && !empty(b:VM_Selection)
		return 'V-MULTI'
	endif
	return winwidth(0) > 60 ? get(mode_map, mode(), ['', ''])[0] : ''
enddef

# Git info (event-driven, cached in b:git_info)
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

# Recompute git info for the current buffer into b:git_info.
# Called from events only -- never from the statusline draw path.
# Returns true when git info actually changed, false otherwise.
def UpdateGitInfo(): bool
	if !IsGitFile()
		b:git_info = ''
		return false
	endif
	var parts: list<string> = []
	if getftype(expand('%')) ==# 'link'
		g:FugitiveDetect(resolve(expand('%')))
	endif
	var branch = g:FugitiveHead()
	if branch != ''
		add(parts, '⎇ ' .. branch)
	endif
	var sum = g:GitGutterGetHunkSummary()
	for idx in range(3)
		if sum[idx] != 0
			add(parts, printf(['+%d', '~%d', '-%d'][idx], sum[idx]))
		endif
	endfor
	var new_info = join(parts, ' ')
	if new_info ==# get(b:, 'git_info', '')
		return false
	endif
	b:git_info = new_info
	return true
enddef

# Display name: tail of the buffer name, "[No Name]" when empty.
# Shared by statusline (current buffer) and tabline (each tab's active buffer)
# so unnamed/dir-like buffers display the same way.
def BufDisplayName(bufnr: number): string
	var fname = fnamemodify(bufname(bufnr), ':t')
	return fname == '' ? '[No Name]' : fname
enddef

# Status marker: "[+]" modified, "[-]" readonly/nomodifiable, "" otherwise.
# Shared by statusline (current buffer) and tabline (each tab's active buffer)
# so their modified/read-only markers always agree.
def FileStatus(bufnr: number): string
	return getbufvar(bufnr, '&filetype') =~# 'help\|man' ? '' :
		getbufvar(bufnr, '&modified') ? '[+]' :
		(getbufvar(bufnr, '&readonly') || !getbufvar(bufnr, '&modifiable')) ? '[-]' : ''
enddef

def StatusFilename(): string
	var wt = WindowType()
	if wt == 1 || wt == 2 || wt == 3
		return ''
	endif
	var fname = BufDisplayName(bufnr(''))
	var fstatus = FileStatus(bufnr(''))
	return fstatus == '' ? fname : fname .. ' ' .. fstatus
enddef

# Right-hand components
def StatusSearchInfo(): string
	if WindowType() != 0
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
	endif
	return ''
enddef

def StatusPercent(): string
	return winwidth(0) > 70 ? printf('%d%%%%', (100 * line('.') / line('$'))) : ''
enddef

def StatusLineInfo(): string
	return winwidth(0) > 70 ? printf('%d/%d:%d', line('.'), line('$'), col('.')) : ''
enddef

def StatusFileformat(): string
	return winwidth(0) > 70 ? &fileformat : ''
enddef

def StatusFiletype(): string
	return winwidth(0) > 70 ? (&filetype != '' ? &filetype : 'unknown') : ''
enddef

def StatusFileencoding(): string
	return winwidth(0) > 70 ? (&fileencoding != '' ? &fileencoding : &encoding) : ''
enddef

# Wrap like lightline's "%( x %)" (grouped, one space each side).
def StatusPadding(v: string): string
	return v == '' ? '' : '%( ' .. v .. ' %)'
enddef

# LSP diagnostic summary (events update b:diagnostic_info; draw only reads cache)
# Section renders each severity in its own color: E:1 W:1 H:1 I:1.
# Returns true when the diagnostic summary actually changed, false when there
# is no LSP or nothing changed.
def UpdateDiagnosticInfo(): bool
	if !exists('g:loaded_lsp')
		b:diagnostic_info = ''
		return false
	endif
	var cnt = lsp#diag#DiagsGetErrorCount(bufnr('%'))
	var s = ''
	var sep = ''
	for [dkey, tag, n] in [
			['Error', 'E', cnt.Error],
			['Warn', 'W', cnt.Warn],
			['Hint', 'H', cnt.Hint],
			['Info', 'I', cnt.Info]]
		if n > 0
			s ..= sep .. '%#StlDiagnostic' .. dkey .. '#' .. tag .. ':' .. n
			sep = ' '
		endif
	endfor
	if s ==# get(b:, 'diagnostic_info', '')
		return false
	endif
	b:diagnostic_info = s
	return true
enddef

# Statusline composer (evaluated per window on redraw)
def g:Statusline(): string
	var sel = win_getid() == str2nr(get(g:, 'actual_curwin', win_getid() .. ''))
	if !sel
		return '%#StlInactive#' .. StatusPadding(ModeLabel()) .. StatusPadding(StatusFilename())
	endif

	var mhl = '%#StlMode' .. get(mode_map, mode(), ['', 'Normal'])[1] .. '#'
	var left = mhl .. StatusPadding(ModeLabel())
	if &paste
		left ..= StatusPadding('PASTE')
	endif
	var git = get(b:, 'git_info', '')
	if git != ''
		left ..= '%#StlL2#' .. StatusPadding(git)
	endif
	var diag = get(b:, 'diagnostic_info', '')
	if diag != ''
		left ..= '%#StlDiagnosticError# ' .. diag .. ' '
	endif
	left ..= '%#StlBase#' .. StatusPadding(StatusFilename())

	var right = '%#StlBase#'
	right ..= StatusPadding(StatusSearchInfo())
	right ..= StatusPadding(StatusFiletype())
	right ..= StatusPadding(StatusFileencoding())
	right ..= StatusPadding(StatusFileformat())
	right ..= '%#StlL2#' .. StatusPadding(StatusPercent())
	right ..= mhl .. StatusPadding(StatusLineInfo())

	return left .. '%#StlMidline#%=' .. right
enddef

# Tabline composer
# Each label reflects the tab's current active window via FileStatus
def TabModified(n: number): string
	var bufs = tabpagebuflist(n)
	var b = bufs[tabpagewinnr(n) - 1]
	return FileStatus(b)
enddef

def TabLabel(n: number): string
	var bufs = tabpagebuflist(n)
	var b = bufs[tabpagewinnr(n) - 1]
	var fname = BufDisplayName(b)
	var mod = TabModified(n)
	return mod == '' ? fname : fname .. ' ' .. mod
enddef

def g:Tabline(): string
	var s = ''
	var nr = tabpagenr()
	var cnt = tabpagenr('$')
	for i in range(1, cnt)
		s ..= (i == nr ? '%#StlTabSelected#' : '%#StlTabInactive#')
		s ..= '%' .. i .. 'T%( ' .. TabLabel(i) .. ' %)%T'
	endfor
	return s .. '%#StlTabMidline#%='
enddef

# Options
set showtabline=1
set laststatus=2
set statusline=%{%g:Statusline()%}
set tabline=%{%g:Tabline()%}

# Sonokai is loaded synchronously above (colorscheme sonokai), so the palette
# and highlight groups are defined here once at startup.
StatusDefineHighlights()

augroup Statusline
	autocmd!
	autocmd ColorScheme * StatusDefineHighlights()
	autocmd BufEnter * unlet! b:is_git_file | call UpdateGitInfo() | call UpdateDiagnosticInfo()
	autocmd BufWritePost * if UpdateGitInfo() | redrawstatus | endif
	autocmd CursorHold * if UpdateGitInfo() | redrawstatus | endif
	autocmd User LspDiagsUpdated,LspAttached,LspDetached if UpdateDiagnosticInfo() | redrawstatus | endif
	autocmd BufWinEnter,WinEnter * unlet! w:window_type
augroup END
# }

# CheckFileChanges {
# Enable focus event tracking for terminal vim.
# Most terminal terminfo entries lack Ss/Se capability definitions,
# causing t_fe/t_fd to remain empty. Set them manually so that
# FocusGained/FocusLost autocommands work (e.g. for checktime).
if !has('gui_running') && &t_fe == ''
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
# }

# Session / Restore {
set sessionoptions-=blank sessionoptions-=options sessionoptions-=folds sessionoptions-=terminal

def GetFileRoot(fallback: string): string
	var root = g:FindRootDirectory()
	return root !=# '' ? root : fallback
enddef

def GetSessionFileInfo(): list<string>
	var session_dir = expand($HOME .. '/.cache/sessions/')
	var session_filename = session_dir .. substitute(trim(GetFileRoot(expand('%:h')), '/', 1), '/', '-', 'g') .. '-session.vim'
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

# Delete session with confirmation. The readability guard keeps ":Obsession!"
# on its delete branch, so it never starts tracking ./Session.vim.
def DeleteSession()
	var session = get(g:, 'this_obsession', v:this_session)
	if session ==# '' || !filereadable(session)
		EchoErr('No session to delete')
		return
	endif
	if confirm('Delete session ' .. fnamemodify(session, ':~') .. '?', "&Yes\n&No", 2) != 1
		return
	endif
	execute 'Obsession!'
enddef

# Backup
nnoremap <Leader>ws <ScriptCmd>call BackupSession()<CR>
# Remove
nnoremap <Leader>rs <ScriptCmd>call DeleteSession()<CR>

# Restore cursor to previous editing position
augroup RestoreCursorPosition
	autocmd!
	autocmd BufReadPost * if line("'\"") > 1 && line("'\"") <= line("$") | execute "normal! g'\"" | endif
augroup END

augroup Session
	autocmd!
	# Obsession fires User Obsession after every persist; keep the saved file usable.
	autocmd User Obsession FixVim9SessionFile(g:this_session)
	autocmd VimEnter * ++nested RestoreSession()
augroup END

# Clear jumplist on vim startup
augroup Jumplist
	autocmd!
	autocmd VimEnter * :clearjumps
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

# Branch-aware tags rebuild. gutentags only updates gtags incrementally
# (--incremental), which can't handle deleted/renamed files after a branch
# switch. Compare the joint (branch, HEAD) identity against a session baseline
# and force a full rebuild when both change; detached HEAD compares HEAD only.
g:tags_branch_aware = get(g:, 'tags_branch_aware', 1)
g:tags_branch_baseline = {}
g:tags_rebuild_pending = {}

def TagsBranchIdentity(): dict<string>
	var root = exists('b:gutentags_root') ? b:gutentags_root : ''
	if root == ''
		return {}
	endif
	var branch = trim(join(systemlist('git -C ' .. shellescape(root) .. ' branch --show-current'), "\n"))
	var head = trim(join(systemlist('git -C ' .. shellescape(root) .. ' rev-parse HEAD'), "\n"))
	if head == ''
		return {}
	endif
	return {'root': root, 'branch': branch, 'head': head}
enddef

def TagsHeadFile(root: string): string
	return gutentags#get_cachefile(root, '') .. '/.tags-head'
enddef

def TagsLoadHead(root: string): string
	var f = TagsHeadFile(root)
	if !filereadable(f)
		return ''
	endif
	return trim(join(readfile(f), "\n"))
enddef

def TagsSaveHead(root: string, head: string)
	writefile([head], TagsHeadFile(root), 'b')
enddef

# True if a gutentags generation job is running for any module of 'root'.
def TagsJobsRunning(root: string): bool
	for bn in range(1, bufnr('$'))
		if bufexists(bn) && getbufvar(bn, 'gutentags_root', '') ==# root
			for [module, tf] in items(getbufvar(bn, 'gutentags_files', {}))
				if gutentags#find_job_index_by_tags_file(module, tf) >= 0
					return true
				endif
			endfor
		endif
	endfor
	return false
enddef

def TagsDoRebuildNow(root: string)
	var dbpath = gutentags#get_cachefile(root, '')
	var gtags_file = dbpath .. '/GTAGS'
	# Kill the DB's cscope connection first: rebuilding changes the inode,
	# which defeats cs-add dedup and would leak a gtags-cscope process.
	silent! execute 'cscope kill ' .. fnameescape(gtags_file)
	for f in ['GTAGS', 'GRTAGS', 'GPATH']
		var p = dbpath .. '/' .. f
		if filereadable(p)
			delete(p)
		endif
	endfor
	if exists(':GutentagsUpdate') == 2
		execute 'GutentagsUpdate!'
	endif
enddef

# Run deferred rebuilds whose project now has no jobs in flight. With no
# yield points in TagsDoRebuildNow, this execution is atomic.
def TagsPendingRebuildCheck()
	for root in keys(g:tags_rebuild_pending)
		if !TagsJobsRunning(root)
			remove(g:tags_rebuild_pending, root)
			TagsDoRebuildNow(root)
		endif
	endfor
enddef

def TagsDoRebuild(root: string)
	if has_key(g:tags_rebuild_pending, root)
		return
	endif
	# GutentagsUpdate! drops its request (queue mode 0) while jobs are in
	# flight, so defer until the next job exit.
	if TagsJobsRunning(root)
		g:tags_rebuild_pending[root] = v:true
		return
	endif
	TagsDoRebuildNow(root)
enddef

def TagsCheckBranch()
	if !g:tags_branch_aware
		return
	endif
	var info = TagsBranchIdentity()
	if empty(info)
		return
	endif
	var root = info['root']
	var branch = info['branch']
	var head = info['head']

	if !has_key(g:tags_branch_baseline, root)
		# No in-memory baseline yet (fresh Vim). Rebuild only if the DB was
		# generated for a different HEAD; trust the existing DB otherwise.
		var saved = TagsLoadHead(root)
		if saved == ''
			TagsSaveHead(root, head)
		elseif saved != head
			TagsDoRebuild(root)
			TagsSaveHead(root, head)
		endif
		g:tags_branch_baseline[root] = {'branch': branch, 'head': head}
		return
	endif

	var base = g:tags_branch_baseline[root]
	if base['branch'] == branch && base['head'] == head
		return
	endif

	# Rebuild on a real switch (branch+HEAD both changed) or a detached
	# HEAD move. Same-branch commit is ignored; rename only refreshes baseline.
	var rebuild = (base['branch'] != branch && base['head'] != head) ||
		(branch == '' && base['head'] != head)
	if rebuild
		TagsDoRebuild(root)
		TagsSaveHead(root, head)
		g:tags_branch_baseline[root] = {'branch': branch, 'head': head}
	elseif base['branch'] != branch
		g:tags_branch_baseline[root]['branch'] = branch
	endif
enddef

def TagsRebuild()
	var info = TagsBranchIdentity()
	if empty(info)
		echoerr 'TagsRebuild: cannot determine project root'
		return
	endif
	TagsDoRebuild(info['root'])
	TagsSaveHead(info['root'], info['head'])
	g:tags_branch_baseline[info['root']] = {'branch': info['branch'], 'head': info['head']}
enddef

command! TagsRebuild TagsRebuild()

augroup TagsBranchAware
	autocmd!
	autocmd BufEnter * TagsCheckBranch()
	autocmd FocusGained * TagsCheckBranch()
	autocmd User FugitiveChanged TagsCheckBranch()
	autocmd User GutentagsUpdated TagsPendingRebuildCheck()
augroup END
# }

# Encoding {
language message en_US.UTF-8
set langmenu=en_US.UTF-8
set encoding=utf-8
scriptencoding utf-8

# Only work in terminal vim
set termencoding=utf-8
set fileencodings=utf-8,gb18030,cp936,ucs-bom,big5,euc-jp,euc-kr,latin1
set fileformats=unix,dos,mac

# Character width. Should never be enable!
#set ambiwidth=double
# }

# Number {
set relativenumber number
set ruler

augroup RelativeNumber
	autocmd!
	# Only display relativenumber in active normal mode buffer
	autocmd WinEnter,InsertLeave * set relativenumber
	autocmd WinLeave,InsertEnter * set norelativenumber number
augroup END
# }

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
set showmatch

# The ":substitute" flag 'g' is default on. This means that
# all matches in a line are substituted instead of one. When a 'g' flag
# is given to a ":substitute" command, this will toggle the substitution
# of all or one match
set gdefault

# Show search count message when searching
set shortmess-=S shortmess+=s

augroup Hlsearch
	autocmd!
	autocmd InsertEnter * if v:hlsearch | feedkeys("\<Cmd>nohlsearch\<CR>", 'm') | endif
augroup END
# }

# Completion {
set wildmenu
set wildmode=list:longest,full
set magic
set completeopt=menu,menuone
# }

# Swap {
set directory=$HOME/.vim/swap//
set jumpoptions+=stack
# }

# Clipboard {
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

# tmux clipboard provider, used as +/* register fallback when the
# GUI clipboard is unavailable (e.g. kmscon/TTY inside tmux).
# Registered whenever tmux is present; only activated by
# `set clipmethod=tmux` in the branch below.
if !empty($TMUX)
	v:clipproviders["tmux"] = {
		available: TmuxAvailable,
		copy: { '+': TmuxCopy, '*': TmuxCopy },
		paste: { '+': TmuxPaste, '*': TmuxPaste },
	}
endif

# Choose the clipboard backend for the +/* registers.
# Over ssh, prefer OSC 52 so yanks reach the local clipboard; the remote
# X11/Wayland clipboard is otherwise unreachable from here.
var is_physical_console = &term =~# '^linux' || root_terminal ==# 'kmscon' || root_terminal ==# 'tty' || root_terminal ==# 'physical_console'
var is_ssh = !empty($SSH_CONNECTION) || !empty($SSH_CLIENT) || !empty($SSH_TTY) || root_terminal ==# 'remote_ssh'

if is_ssh && exists('*echoraw')
	# osc52 provider (Vim 9.1+): yanks to the local clipboard via OSC 52.
	# tmux masks the DA1 detection, so force_avail; but only when the
	# remote tmux has set-clipboard on (it answers the OSC52 paste query,
	# so `p` won't block), otherwise fall back to wayland/x11/tmux.
	packadd osc52
	set clipboard=unnamed,unnamedplus
	if !empty($TMUX)
		var sc = trim(system('tmux show-options -s set-clipboard 2>/dev/null'))
		if sc =~# 'on'
			g:osc52_force_avail = 1
			set clipmethod^=osc52
		else
			set clipmethod+=tmux
		endif
	else
		set clipmethod^=osc52
	endif
elseif !is_physical_console && (!empty($DISPLAY) || !empty($WAYLAND_DISPLAY) || has('mac'))
	if has('unnamedplus')
		# When possible use + register for copy-paste
		set clipboard=unnamed,unnamedplus
	else
		# Use * register for copy-paste (X11 without +clipboard, or Mac)
		set clipboard=unnamed
	endif
elseif !empty($TMUX)
	set clipboard=unnamed,unnamedplus
	set clipmethod=tmux
endif
# }

# Indent {
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
# }

# Timing {
# For mappings
set timeout
set timeoutlen=1000
# For key codes
set ttimeout
# Unnoticeable small value
set ttimeoutlen=10
set updatetime=300
# }

# Display {
set list
set listchars=tab:▸\ ,leadmultispace:│\ \ \ ,eol:¬,trail:·
# }

# Scroll {
set scrolloff=7
set sidescrolloff=15
set sidescroll=1
# }

# Misc {
set splitright
set backspace=indent,eol,start
set hidden
set autoread
set belloff=all
set mouse=nvi
set showtabline=1
set laststatus=2
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
# }

# Buffer {
def OpenPrompt(prompt: string, cmd: string)
	var name = Strip(input(prompt, '', 'file'))
	if name !=# ''
		execute cmd .. ' ' .. fnameescape(name)
	endif
enddef

def Strip(input_string: string): string
	return substitute(input_string, '^\s*\(.\{-}\)\s*$', '\1', '')
enddef

nnoremap <silent>[b <Cmd>bprevious<CR>
nnoremap <silent>]b <Cmd>bnext<CR>
nnoremap <silent><Leader>o <ScriptCmd>call OpenPrompt('New buffer name: ', 'edit')<CR>
# }

# Tab {
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
nnoremap <silent><Leader><Leader>t <ScriptCmd>call OpenPrompt('New tab name: ', 'tabnew')<CR>
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

# Resize {
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

def ResizeAllTab()
	var cur_tab = tabpagenr()
	silent! execute 'tabdo wincmd = '
	silent! execute 'tabnext ' .. cur_tab
enddef

augroup AutoResize
	autocmd!
	autocmd VimResized * ResizeAllTab()
augroup END
# }

# FileType {
augroup FileTypeGroup
	autocmd!
	# Space indent, 4-width: Zig, Rust, Python, Markdown
	autocmd FileType zig,rust,python,markdown setlocal expandtab tabstop=4 shiftwidth=4 softtabstop=4
	# Space indent, 2-width: JavaScript, TypeScript, Lua, YAML, JSON
	autocmd FileType javascript,typescript,lua,yaml,json,jsonc setlocal expandtab tabstop=2 shiftwidth=2 softtabstop=2
	autocmd BufRead,BufNewFile *.gotmpl,*.go.tmpl setlocal filetype=gotmpl
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
g:markdown_fenced_languages = ['c', 'cpp', 'zig', 'rust', 'go', 'javascript', 'typescript', 'python', 'lua', 'bash=sh', 'zsh', 'vim', 'sql', 'yaml', 'json', 'jsonc']
# }

# Docset {
augroup Docset
	autocmd!
	autocmd FileType man,help setlocal nolist

	# Default docset: built-in :Man for everything
	autocmd FileType * setlocal keywordprg=:Man
	# LSP-enabled file types prefer :LspHover
	autocmd FileType cpp,zig,rust,go,gomod,gowork,gosum,gotmpl,javascript,typescript,python,lua,sh,markdown,yaml,json,jsonc setlocal keywordprg=:LspHover
	autocmd FileType c setlocal keywordprg=:Man | setenv('MANSECT', '2:3:1:4:5:6:7:8:9')
	autocmd FileType vim,help setlocal keywordprg=:help!
augroup END
# }

# Quit {
def FocusToValidWindow()
	if WindowTypeOf(winnr()) == 0
		return
	endif
	for info in getwininfo()
		if WindowTypeOf(info.winnr) == 0
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
		if WindowTypeOf(info.winnr) == 0
			total_valid += 1
			if info.tabnr == cur_tab
				tab_valid += 1
			endif
		endif
	endfor

	if !has_other_window || total_valid == 0
		confirm quitall
	elseif tab_valid == 0
		tabclose
		FocusToValidWindow()
	else
		quit
		FocusToValidWindow()
	endif
enddef

nnoremap <silent>q <ScriptCmd>call Quit()<CR>
nnoremap <silent><S-q> <Cmd>confirm quitall<CR>

nnoremap t q
vnoremap t q
# }

# Terminal {
# F4/F5 toggle one global terminal (bottom / right); either key hides it
# while visible. The job and history survive hides. F3 opens extra terminals.
def TerminalToggle(vertical: bool)
	var buf = get(g:, 'terminal_bufnr', 0)
	if buf > 0 && bufexists(buf) && term_getstatus(buf) =~# 'running'
		var wids = win_findbuf(buf)
		for wid in wids
			if win_id2tabwin(wid)[0] == tabpagenr()
				win_execute(wid, 'hide')
				return
			endif
		endfor
		for wid in wids
			win_execute(wid, 'hide')
		endfor
		if vertical
			execute 'botright vertical sbuffer ' .. buf
		else
			execute 'botright sbuffer ' .. buf
			execute 'resize 20'
		endif
		feedkeys("i", 't')
	else
		if vertical
			execute 'botright vertical terminal'
		else
			execute 'botright terminal ++rows=20'
		endif
		g:terminal_bufnr = bufnr('%')
	endif
enddef

tnoremap <silent><ScrollWheelUp> <C-\><C-n><ScrollWheelUp>
tnoremap <silent><ScrollWheelDown> <C-\><C-n><ScrollWheelDown>
nnoremap <F3> :botright terminal ++rows=20<Space>
nnoremap <silent><F4> <ScriptCmd>call TerminalToggle(false)<CR>
tnoremap <silent><F4> <C-\><C-n><ScriptCmd>call TerminalToggle(false)<CR>
nnoremap <silent><F5> <ScriptCmd>call TerminalToggle(true)<CR>
tnoremap <silent><F5> <C-\><C-n><ScriptCmd>call TerminalToggle(true)<CR>

augroup TerminalSettings
	autocmd!
	# term_setkill: on exit, SIGKILL shells silently instead of asking (SIGTERM is ignored by interactive shells); :hide keeps the job
	autocmd TerminalOpen * if &buftype ==# 'terminal' && bufname('%') !~# 'fzf' | setlocal nobuflisted bufhidden=hide scrolloff=0 | term_setkill('%', 'kill') | endif
augroup END
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
def TagJump()
	var name = expand('<cword>')
	var items = []
	for t in taglist('^' .. escape(name, '\^$.') .. '$')
		add(items, {'filename': t.filename, 'pattern': matchstr(t.cmd, '/\zs.*\ze/$'), 'text': t.name})
	endfor
	try
		execute 'tag ' .. name
	catch /E426/
		EchoErr('Tag not found: ' .. name)
		return
	endtry
	setqflist(items, 'r')
	copen
enddef

nnoremap <silent>gd <C-]>
nnoremap <silent>g] <ScriptCmd>TagJump()<CR>

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

# vim-visual-multi {
g:VM_maps = {}
g:VM_maps['Select Operator'] = 'gs'
g:VM_set_statusline = 0
g:VM_silent_exit = 1

# Use sonokai's purple accent in true-color mode; on the 16-color console
# fall back to the closest ANSI purple (cterm 13) with console-safe indices.
if !is_tty_console
	highlight VM_Mode cterm=bold ctermfg=232 ctermbg=141 gui=bold guifg=#1a1b26 guibg=#bb9af7
	highlight VM_Info ctermfg=141 ctermbg=236 guifg=#bb9af7 guibg=#3b3f54
else
	highlight VM_Mode cterm=bold ctermfg=0 ctermbg=13 gui=bold guifg=#1a1b26 guibg=#bb9af7
	highlight VM_Info ctermfg=13 ctermbg=0 guifg=#bb9af7 guibg=#3b3f54
endif

def VMEnter()
	if !is_tty_console
		execute 'highlight StlModeNormal term=bold guifg=#1a1b26 guibg=#bb9af7 ctermfg=232 ctermbg=141 cterm=bold'
	else
		execute 'highlight StlModeNormal term=bold guifg=#1a1b26 guibg=#bb9af7 ctermfg=0 ctermbg=13 cterm=bold'
	endif
	redrawstatus
enddef

augroup VMLightLine
	autocmd!
	autocmd User visual_multi_start silent VMEnter()
	autocmd User visual_multi_exit call StatusDefineHighlights() | redrawstatus
augroup END
# }

# vim-dirvish {
nnoremap <silent>- <Cmd>execute 'Dirvish' expand('%:p:h')<CR>
nnoremap <silent>~ <ScriptCmd>execute('Dirvish ' .. GetFileRoot(expand('~')))<CR>

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

# vim-fugitive {
nnoremap <silent><Leader>gg <Cmd>Git<CR>
nnoremap <silent><Leader>gd <Cmd>Gdiffsplit!<CR>
nnoremap <silent><Leader>gD <Cmd>Git diff<CR>
nnoremap <silent><Leader>gb :Git blame<CR>
xnoremap <silent><Leader>gb :Git blame<CR>
# }

# gv.vim {
nnoremap <silent><Leader>gl :GV!<CR>
xnoremap <silent><Leader>gl :GV!<CR>
nnoremap <silent><Leader>gL :GV<CR>
xnoremap <silent><Leader>gL :GV<CR>
# }

# vim-gitgutter {
g:gitgutter_map_keys = 0
g:gitgutter_preview_win_floating = 1

nmap <silent><Leader>hp <Plug>(GitGutterPreviewHunk)
nmap <silent><Leader>hs <Plug>(GitGutterStageHunk)
nmap <silent><Leader>hr <Plug>(GitGutterUndoHunk)
nmap <silent><Leader>hS :Git add %<CR>
nmap <silent><Leader>hR :Git checkout -- %<CR>
nmap <silent><Leader>hl :GitGutterQuickFixCurrentFile<CR>
nmap <silent><Leader>hq :GitGutterQuickFixCurrentFile<CR>
nmap <silent><Leader>hQ :GitGutterQuickFix<CR>
nmap <silent>[h <Plug>(GitGutterPrevHunk)
nmap <silent>]h <Plug>(GitGutterNextHunk)
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
			for line in uniq(sort(readfile(path)))
				var b = str2nr(matchstr(line, '\[\zs\d\+\ze\]'))
				if b > 0 && bufexists(b)
					execute 'silent! bdelete ' .. b
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

def EchoErr(msg: string)
	echohl ErrorMsg
	echomsg msg
	echohl None
enddef

def FzfLspDocSymbols(types: list<number>)
	var srv = lsp#buffer#CurbufGetServer('documentSymbol')
	if empty(srv) || !srv.running || !srv.ready
		EchoErr('No ready LSP server with documentSymbol support for this buffer')
		return
	endif
	var reply = srv.rpc('textDocument/documentSymbol', {'textDocument': {'uri': lsp#util#LspFileToUri(expand('%:p'))}})
	if empty(reply) || !has_key(reply, 'result') || empty(reply.result)
		EchoErr('No document symbols returned by the LSP server')
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

if !is_tty_console
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
else
	highlight StargateFocus ctermfg=3 guifg=#958C6A
	highlight StargateDesaturate ctermfg=8 guifg=#49423F
	highlight StargateError ctermfg=1 guifg=#D35B4B
	highlight StargateLabels ctermfg=3 ctermbg=0 guifg=#CAA247 guibg=#171E2C
	highlight StargateErrorLabels ctermfg=3 ctermbg=1 guifg=#CAA247 guibg=#551414
	highlight StargateMain cterm=bold ctermfg=13 gui=bold guifg=#F2119C
	highlight StargateSecondary cterm=bold ctermfg=10 gui=bold guifg=#11EB9C
	highlight StargateShip ctermfg=0 ctermbg=3 guifg=#111111 guibg=#CAA247
	highlight StargateVIM9000 cterm=bold ctermfg=0 ctermbg=5 gui=bold guifg=#111111 guibg=#B2809F
	highlight StargateMessage ctermfg=3 guifg=#A5B844
	highlight StargateErrorMessage ctermfg=9 guifg=#E36659
endif
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

# Fold {
# Disable fold on startup
set nofoldenable
set foldmethod=syntax
set foldlevel=99

# Only update fold after type zx or zX
g:fastfold_fold_command_suffixes = ['x', 'X', 'a', 'A']
g:fastfold_fold_movement_commands = []

# Use indent style fold for python and yaml
augroup LanguageFold
	autocmd!
	autocmd FileType python,yaml setlocal foldmethod=indent
augroup END
# }

# vim-matchup {
# sonokai explicitly defines MatchParenCur/MatchWord,
# which blocks vim-matchup's hi def link. Re-link them.
highlight! link MatchParen Search
highlight! link MatchParenCur Search
highlight! link MatchWord Search
highlight! link MatchWordCur Search
# }

# vim-signature {
# Highlight mark a-zA-Z
if !is_tty_console
	highlight SignatureMarkText cterm=bold ctermfg=154 gui=bold guifg=#A6E22E
else
	highlight SignatureMarkText cterm=bold ctermfg=10 gui=bold guifg=#A6E22E
endif

# Highlight marker !@#$%^&*()
if !is_tty_console
	highlight SignatureMarkerText term=bold cterm=bold ctermfg=197 gui=bold guifg=#F92672
else
	highlight SignatureMarkerText term=bold cterm=bold ctermfg=9 gui=bold guifg=#F92672
endif

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
	{name: 'zls',
		filetype: ['zig'],
		path: 'zls',
		args: [],
		rootSearch: ['build.zig', 'build.zig.zon'],
		workspaceConfig: {
			'zls': {
				'enable_inlay_hints': true,
				'enable_snippets': true,
			},
		},
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
		filetype: ['go', 'gomod', 'gowork', 'gosum', 'gotmpl'],
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
	{name: 'efm-langserver',
		filetype: ['markdown'],
		path: 'efm-langserver',
		args: [],
		rootSearch: ['.git/'],
		initializationOptions: {
			documentFormatting: v:true,
			documentRangeFormatting: v:false,
			documentDiagnostics: v:true,
			codeAction: v:false,
		},
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
		filetype: ['json', 'jsonc'],
		path: 'vscode-json-language-server',
		args: ['--stdio'],
		initializationOptions: {
			provideFormatter: true,
		},
		workspaceConfig: {
			'json': {
				'validate': {'enable': v:true},
			},
		},
	}]

	g:LspOptionsSet(lspOpts)
	g:LspAddServer(lspServers)
enddef

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
	# Lazily load lsp and vsnip only for the supported file types.
	# Order matters: lsp must be loaded before vim-vsnip-integ, otherwise
	# vsnip-integ caches "lsp not detected" and LSP snippets never expand.
	autocmd FileType c,cpp,zig,rust,go,gomod,gowork,gosum,gotmpl,javascript,typescript,python,lua,sh,vim,markdown,yaml,json,jsonc call plug#load('lsp') | call plug#load('vim-vsnip') | call plug#load('vim-vsnip-integ') | call plug#load('friendly-snippets')
	autocmd User LspSetup OnLspSetup()
	autocmd User LspAttached OnLspAttached()
	autocmd BufWritePre * if exists('g:loaded_lsp') && !empty(lsp#buffer#CurbufGetServer('documentFormatting')) | LspFormat | endif
augroup END
# }

# vim-vsnip {
# Expand or jump; otherwise accept the completion in the popup (snippet items
# are expanded automatically on accept via CompleteDone).
imap <expr> <C-l> exists('*vsnip#available') ? (vsnip#available(1) ? '<Plug>(vsnip-expand-or-jump)' : pumvisible() ? '<C-y>' : '<C-l>') : '<C-l>'
smap <expr> <C-l> exists('*vsnip#available') ? (vsnip#available(1) ? '<Plug>(vsnip-expand-or-jump)' : '<C-l>') : '<C-l>'

# Jump forward or backward
imap <expr> <Tab> exists('*vsnip#jumpable') ? (vsnip#jumpable(1) ? '<Plug>(vsnip-jump-next)' : '<Tab>') : '<Tab>'
smap <expr> <Tab> exists('*vsnip#jumpable') ? (vsnip#jumpable(1) ? '<Plug>(vsnip-jump-next)' : '<Tab>') : '<Tab>'
imap <expr> <S-Tab> exists('*vsnip#jumpable') ? (vsnip#jumpable(-1) ? '<Plug>(vsnip-jump-prev)' : '<S-Tab>') : '<S-Tab>'
smap <expr> <S-Tab> exists('*vsnip#jumpable') ? (vsnip#jumpable(-1) ? '<Plug>(vsnip-jump-prev)' : '<S-Tab>') : '<S-Tab>'
# }
