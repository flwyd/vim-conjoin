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
" Description: Functions to handle continuation characters and merging string
" literals when joining lines.


""
" Removes continuation characters, merges string literals, and then joins
" lines as if (count) {cmd} were typed in normal mode.  If cmd is empty (or
" otherwise neither J nor gJ) then no command will be performed to join the
" lines, with the expectation that a mapping will initiate its own join
" operation.  This function is typically called from the from a mapping
" established in plugin/conjoin.vim.
" @public
function! conjoin#joinNormal(cmd) abort
	" Save v:count1 for repeat
	let l:count = v:count1
	let l:patterns = s:getDict()
	let l:start = line('.')
	let l:end = line('.') + max([v:count1 - 1, 1])
	" Always join at least 2 lines: J == 1J == 2J
	call s:substituteRange(l:start, l:end,
				\ get(l:patterns, 'trailing', ''), get(l:patterns, 'leading', ''))
	" Merge string literals directly because J would add inappropriate space
	let l:removed = s:mergeQuotes(l:start, l:end, get(l:patterns, 'quote', []))
	" If cmd is J/gJ, execute that command; otherwise caller will do it.
	if l:end - l:start - l:removed > 0 && (a:cmd ==# 'J' || a:cmd ==# 'gJ')
		execute 'normal! ' . (l:count - l:removed) . a:cmd
	endif
	if !empty(a:cmd)
		silent! call repeat#set(a:cmd, l:count)
	endif
endfunction


""
" Removes continuation characters, merges string literals, and then joins
" lines as if (count) {cmd} were typed in visual mode.  If cmd is empty (or
" otherwise neither J nor gJ) then no command will be performed to join the
" lines, with the expectation that a mapping will initiate its own join
" operation.  This function is typically called from the from a mapping
" established in plugin/conjoin.vim.
" @public
function! conjoin#joinVisual(cmd) abort
	let l:patterns = s:getDict()
	let l:start = line("'<")
	let l:vend = line("'>")
	" Always join at least 2 lines: vJ is the same as vjJ
	let l:end = max([l:vend, l:start + 1])
	call s:substituteRange(l:start, l:end,
				\ get(l:patterns, 'trailing', ''), get(l:patterns, 'leading', ''))
	let l:removed = s:mergeQuotes(l:start, l:end, get(l:patterns, 'quote', []))
	" If any lines were removed, adjust visual position
	if l:removed > 0
		" TODO Be a little smarter about column position
		call setpos("'>", [0, l:vend - l:removed, col('.'), 0])
	endif
	if l:end - l:start - l:removed > 0
		" gv to restore visual range
		execute 'normal! gv'
		" If cmd is J/gJ, execute that command; otherwise caller will do it.
		if a:cmd ==# 'J' || a:cmd ==# 'gJ'
			execute 'normal! ' . a:cmd
		endif
	endif
	if !empty(a:cmd)
		silent! call repeat#set(a:cmd, l:end - l:start + 1)
	endif
endfunction


""
" Removes continuation characters, merges string literals, and then joins
" lines as if :[range]join[!] were typed in ex mode.  This function is
" typically called from the :Join command.
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
		let l:flags = join(l:args[1:], ' ')
	else
		let l:flags = a:qargs
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
	let l:removed = s:mergeQuotes(l:start, l:end, get(l:patterns, 'quote', []))
	" if lines were removed, turn command into :{start}join {count} [flags]
	if l:removed > 0
		let l:count = l:end - l:start - l:removed + 1
		" If all lines were merged quotes, do nothing further
		if l:count > 1
			let l:cmd = printf('%sjoin%s %s %s', l:start, a:bang, l:count, l:flags)
		else
			let l:cmd = ''
		endif
	endif
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
" For each pair of patterns in {quotepairs}, checks each adjacent pair of
" lines between {linefirst} and {linelast}.  If the first quote pattern
" matches the end of the first line and the second quote pattern matches the
" beginning of the second line then the two lines are joined with the matched
" trailing and leading strings removed.  Returns the number of lines removed
" from the range, which should be subtracted from the count or range of the
" subsequent join operation.
" @private
function! s:mergeQuotes(linefirst, linelast, quotepairs) abort
	let l:fewerlines = 0
	if empty(a:quotepairs)
		return l:fewerlines
	endif
	if !get(g:, 'conjoin_merge_strings', 1) || !get(g:, 'conjoin_merge_strings', 1)
		return l:fewerlines
	endif
	" Iterate in reverse to keep index position while deleting continuation
	" quote lines after joining them into the previous line.
	for l:i in range(a:linelast - 1, a:linefirst, -1)
		let l:first = getline(l:i)
		let l:second = getline(l:i + 1)
		" Iterate through each trailing/leading pattern pair, e.g. " and ' strings
		for [l:trailpat, l:leadpat] in a:quotepairs
			if match(l:first, l:trailpat) >= 0 && match(l:second, l:leadpat) >= 0
				let l:line = substitute(l:first, l:trailpat, '', '')
							\ . substitute(l:second, l:leadpat, '', '')
				call setline(l:i, l:line)
				call s:deleteLine(l:i + 1)
				let l:fewerlines += 1
				break
			endif
		endfor
	endfor
	return l:fewerlines
endfunction


""
" Deletes a line with deletebufline in Vim 8.1.0039+ or :delete prior.
" @private
if exists('*deletebufline')
	function! s:deleteLine(lineno) abort
		call deletebufline('', a:lineno)
	endfunction
else
	function! s:deleteLine(lineno) abort
		" TODO Tests that join the whole file fail due to a trailing space
		let l:pos = getcurpos()
		keepjumps execute a:lineno . 'delete'
		call setpos('.', l:pos)
	endfunction
endif


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
