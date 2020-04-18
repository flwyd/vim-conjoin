" Copyright 2020 Google LLC
"
" Licensed under the Apache License, Version 2.0 (the "License");
" you may not use this file except in compliance with the License.
" You may obtain a copy of the License at
"
"      http://www.apache.org/licenses/LICENSE-2.0
"
" Unless required by applicable law or agreed to in writing, software
" distributed under the License is distributed on an "AS IS" BASIS,
" WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
" See the License for the specific language governing permissions and
" limitations under the License.

" File: autoload/conjoin.vim
" Author: Trevor Stone
" Description: Functions to handle continuation characters when joining lines.


""
" Removes continuation characters and then joins lines as if (count) {cmd}
" were typed in normal mode.  If cmd is empty (or otherwise neither J nor gJ)
" then no command will be performed to join the lines, with the expectation
" that a mapping will initiate its own join operation.  This function is
" typically called from the from a mapping established in plugin/conjoin.vim.
" @public
function! conjoin#joinNormal(cmd) abort
	let l:patterns = s:getDict()
	" Always join at least 2 lines: J == 1J == 2J
	call s:substituteRange(line('.'), line('.') + max([v:count - 1, 1]),
				\ get(l:patterns, 'trailing', ''), get(l:patterns, 'leading', ''))
	" If cmd is J/gJ, execute that command; otherwise caller will do it.
	if a:cmd ==# 'J' || a:cmd ==# 'gJ'
		execute 'normal! ' . v:count1 . a:cmd
	endif
endfunction


""
" Removes continuation characters and then joins lines as if (count) {cmd}
" were typed in visual mode.  If cmd is empty (or otherwise neither J nor gJ)
" then no command will be performed to join the lines, with the expectation
" that a mapping will initiate its own join operation.  This function is
" typically called from the from a mapping established in plugin/conjoin.vim.
" @public
function! conjoin#joinVisual(cmd) abort
	let l:patterns = s:getDict()
	" Always join at least 2 lines: vJ is the same as vjJ
	call s:substituteRange(line("'<"), max([line("'>"), line("'<") + 1]),
				\ get(l:patterns, 'trailing', ''), get(l:patterns, 'leading', ''))
	" gv to restore visual range
	execute 'normal! gv'
	" If cmd is J/gJ, execute that command; otherwise caller will do it.
	if a:cmd ==# 'J' || a:cmd ==# 'gJ'
		execute 'normal! ' . a:cmd
	endif
endfunction


""
" Removes continuation characters and then joins lines as if :[range]join[!]
" were typed in ex mode.  This function is typically called from the :Join
" command.
" @public
function! conjoin#joinEx(line1, line2, range, bang, qargs) abort
	if a:range == 0
		let l:rangestr = ''
	elseif a:range == 1
		let l:rangestr = a:line1
	else
		let l:rangestr = a:line1 . ',' . a:line2
	endif
	" :join command to execute after removing continuation characters
	let l:cmd = printf('%sjoin%s %s', l:rangestr, a:bang, a:qargs)
	" 1,3join joins lines 1 through 3
	let l:start = a:line1
	let l:end = a:line2
	let l:count = 0
	let l:args = split(a:qargs)
	" first argument to :join is an optional count
	if len(l:args) > 0 && l:args[0] =~ '^\d'
		let l:count = str2nr(l:args[0])
	endif
	if l:count > 0
		" 1,3join 5 joins lines 3 through 7
		let l:start = a:line2
		let l:end = l:start + l:count - 1
	elseif l:start == l:end && a:range == 2
		" :1,1join with no count doesn't join any lines
		execute l:cmd
		return
	elseif l:start == l:end && a:range == 0
		" :join with no range and no count joins two lines
		let l:end = l:start + 1
	endif
	let l:patterns = s:getDict()
	call s:substituteRange(l:start, l:end,
				\ get(l:patterns, 'trailing', ''), get(l:patterns, 'leading', ''))
	execute l:cmd
endfunction


""
" Removes {trailpat} from all lines from {linefirst} to {linelast}-1 and
" removes {leadpat} from all lines from {linefirst}+1 to {linelast}.
" @private
function! s:substituteRange(linefirst, linelast, trailpat, leadpat) abort
	if empty(a:leadpat) && empty(a:trailpat)
		return
	endif
	for l:i in range(a:linefirst, a:linelast)
		let l:text = getline(l:i)
		" Apply trailing pattern to all lines but the last
		if l:i < a:linelast && !empty(a:trailpat)
			let l:text = substitute(l:text, a:trailpat, '', '')
		endif
		" Apply leading pattern to all lines but the first
		if l:i > a:linefirst && !empty(a:leadpat)
			let l:text = substitute(l:text, a:leadpat, '', '')
		endif
		call setline(l:i, l:text)
	endfor
endfunction


""
" Determines the pattern dict to use for the current buffer.
" @private
function! s:getDict() abort
	if exists('b:conjoin_patterns')
		" User buffer-level override
		return b:conjoin_patterns
	endif
	if !empty(&filetype) && has_key(g:conjoin_filetypes, &filetype)
		return g:conjoin_filetypes[&filetype]
	endif
	return {}
endfunction
