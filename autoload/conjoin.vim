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
" Removes continuation characters and then joins lines as if (count) cmd were
" typed in normal mode.  This function is typically called from the J mapping
" set by plugins/conjoin.vim but can be called directly from a user mapping.
" {cmd} is the normal-mode join command to execute after modifying lines
" (i.e. 'J' or 'gJ').
" @public
function! conjoin#joinNormal(cmd) abort
	let l:patterns = s:getDict()
	if has_key(l:patterns, 'trailing')
		" continuation character at end of line as in shell
		let l:start = line('.')
		" subtract 2: one for start line, one for final line
		let l:end = max([l:start + v:count1 - 2, l:start])
		call s:substituteRange(l:start, l:end, l:patterns.trailing)
	endif
	if has_key(l:patterns, 'leading')
		" continuation character at start of next line as in VimL
		let l:start = line('.') + 1
		let l:end = l:start + v:count1 - 2
		call s:substituteRange(l:start, l:end, l:patterns.leading)
	endif
	execute 'normal! ' . v:count1 . a:cmd
endfunction


""
" Removes continuation characters and then joins lines as if cmd were typed
" in visual mode.  This function is typically called from the J mapping set by
" plugins/conjoin.vim but can be called directly from a user mapping.
" {cmd} is the normal-mode join command to execute after modifying lines and
" restoring the visual selection (i.e. 'J' or 'gJ').
" @public
function! conjoin#joinVisual(cmd) abort
	let l:patterns = s:getDict()
	if has_key(l:patterns, 'trailing')
		" continuation character at end of line as in shell
		let l:start = line("'<")
		let l:end = max([line("'>") - 1, l:start])
		call s:substituteRange(l:start, l:end, l:patterns.trailing)
	endif
	if has_key(l:patterns, 'leading')
		" continuation character at start of next line as in VimL
		let l:end = line("'>")
		" handle single-line visual join
		let l:start = min([line("'<") + 1, l:end])
		call s:substituteRange(l:start, l:end, l:patterns.leading)
	endif
	" gv to restore visual range
	execute 'normal! gv' . a:cmd
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
	endif
	let l:patterns = s:getDict()
	if has_key(l:patterns, 'trailing')
		" continuation character at end of line as in shell
		call s:substituteRange(l:start, l:end - 1, l:patterns.trailing)
	endif
	if has_key(l:patterns, 'leading')
		" continuation character at start of next line as in VimL
		" Start on second line
		call s:substituteRange(l:start + 1, max([l:end, l:start + 1]), l:patterns.leading)
	endif
	execute l:cmd
endfunction


""
" Removes {pattern} in each line from {startline} to {endline} inclusive.
" @private
function! s:substituteRange(startline, endline, pattern) abort
	if a:pattern == ''
		return
	endif
	for l:i in range(a:startline, a:endline)
		let l:text = substitute(getline(l:i), a:pattern, '', '')
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
