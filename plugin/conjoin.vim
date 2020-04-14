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

" File: conjoin.vim
" Author: Trevor Stone
" Description: Plugin which maps J and gJ to remove line continuation
" characters when joining lines.  Works with J/gJ alone, with a count, or in
" visual mode.  Also provides a :[range]Join[!] command.

""
" @section Introduction, intro
" @order intro commands mappings config functions
" conjoin is a plugin that handles line joining in the presence of line
" continuation characters.  Vim's normal behavior for |J| and |:join| on the
" following shell script: >
"   cat file.txt \
"     | sort \
"     | uniq -c
" <
" leaves the backslash continuation characters in place: >
"   cat file.txt \ | sort \ | uniq -c
" <
" With conjoin, running join commands on the same script will produce >
"   cat file.txt | sort | uniq -c
" <
" (|gJ| does the same but doesn't adjust leading/trailing space.)
"
" Note that vim already removes leading comment characters when joining lines
" in a block comment when |formatoptions| contains the 'j' flag.
"
" conjoin works with several programming languages by default, see
" @section(config) for details.

""
" @section Mappings, mappings
" *conjoin-J*
" J  Join [count] lines, as with the builtin |J| command.  Before joining
" lines, trailing and/or leading continuation escape characters will be
" removed from the lines to be joined.
"
" *conjoin-v_J*
" {Visual}J  Join the highlighted lines, as with the builtin |v_J| command.
" Before joining lines, trailing and/or leading continuation escape characters
" will be removed from the lines to be joined.
"
" *conjoin-gJ*
" gJ  Like J but with joining semantics like the builtin |gJ|.
"
" *conjoin-v_gJ*
" {Visual}gJ  Like J but with joining semantics like the builtin |v_gJ|.
"
" If these keys have existing mappings, conjoin will call the prior mapping
" after removing continuation characters.  This allows conjoin to delegate gJ
" to the |splitjoin| plugin as long as splitjoin appears before conjoin in
" |runtimepath|.
"
" You can use different mappings for conjoin (not touching J/gJ) by setting
" the appropriate variable: >
"   let g:conjoin_map_J = '<Leader>z'
"   let g:conjoin_map_gJ = '<Leader>x'
" <

if exists('did_conjoin') || version < 700
	finish
endif
let did_conjoin = 1

""
" @section Configuration, config
" g:conjoin_filetypes configures continuation patterns for many programming
" lanugages.  It is a dict with filetypes (e.g. "sh", "ruby", "vim") as keys
" and conjoin pattern dicts as values.  A conjoin dict has optional "trailing"
" and "leading" keys mapped to regular expression patterns.  When conjoin
" mappings or functions are called, the current buffer's 'filetype' is looked
" up in g:conjoin_filetypes.  If it contains a conjoin dict, the "trailing"
" pattern will be matched against each join line (except the last) and the
" "leading" pattern will be matched against each join line (except the first).
" Make sure to include $ at the end of trailing patterns and ^ at the
" beginning of leading patterns.  Example use in .vimrc: >
"   if !exists('g:conjoin_filetypes')
"     let g:conjoin_filetypes = {}
"   endif
"   g:conjoin_filetypes.intercal = #{leading: '^\s*PLEASE', trailing: '\\$'}
" <
" A buffer-local variable b:conjoin_patterns can replace the global filetype
" settings.
"
" The default set of configured filetypes is >
"   autoit bash c cobra context cpp csh fortran m4 mma plaintex ps1 python
"   ruby sh tcl tcsh tex texmf vb vim zsh
" <

if !exists('g:conjoin_filetypes')
	let g:conjoin_filetypes = {}
endif

" Default continuation character information taken primarily from
" https://en.wikipedia.org/wiki/Comparison_of_programming_languages_(syntax)#Line_continuation
" Entries are ordered by the continuation pattern they use:
" Shell-style languages use a trailing backslash (\):
"   sh bash csh tcsh zsh c cpp python ruby tcl texmf
" Mathematica/Wolfram Language uses a trailing backslash or the special
" Unicode character F3B1 ():
"   mma
" PowerShell uses a trailing backtick preceeded by whitespace ( `):
"   ps1
" Visual Basic etc. use a trailing underscore preceeded by whitespace ( _):
"   autoit cobra vb
" Vim uses a leading backslash and optional space, :help line-continuation
"   vim
" Vroom vim testing framework uses a leading pipe preceeded by space:
"   vroom
" Fortran 90+ uses a trailing ampersand and optionally a leading ampersand on
" the next line.  Note that this pattern doesn't require the & to be in column
" 6, nor does it handle other non-zero column 6 values.
"   fortran
" TeX treats an empty trailing comment (%) as a line continuation:
"   context plaintex tex
" m4 uses an empty trailing comment (dnl) to avoid outputting newline:
"   m4
let s:default_filetypes = {
			\ 'sh': {'trailing': '\\$'},
			\ 'bash': {'trailing': '\\$'},
			\ 'csh': {'trailing': '\\$'},
			\ 'tcsh': {'trailing': '\\$'},
			\ 'zsh': {'trailing': '\\$'},
			\ 'c': {'trailing': '\\$'},
			\ 'cpp': {'trailing': '\\$'},
			\ 'python': {'trailing': '\\$'},
			\ 'ruby': {'trailing': '\\$'},
			\ 'tcl': {'trailing': '\\$'},
			\ 'texmf': {'trailing': '\\$'},
			\ 'mma': {'trailing': '[\uF3B1\\]$'},
			\ 'ps1': {'trailing': '\s`$'},
			\ 'autoit': {'trailing': '\s_$'},
			\ 'cobra': {'trailing': '\s_$'},
			\ 'vb': {'trailing': '\s_$'},
			\ 'vim': {'leading': '^\s*\\'},
			\ 'vroom': {'leading': '\v^\s*\|'},
			\ 'fortran': {'trailing': '&\s*$', 'leading': '^\s*&'},
			\ 'tex': {'trailing': '%$'},
			\ 'context': {'trailing': '%$'},
			\ 'plaintex': {'trailing': '%$'},
			\ 'm4': {'trailing': '\<dnl$'},
			\}

" Populate g:conjoin_filetypes with defaults, respecting user overrides.
call extend(g:conjoin_filetypes, s:default_filetypes, 'keep')

" Define a normal/visual mode mapping, respecting existing mapping.
" {mode} is 'n' or 'v', {mapping} is the key(s) to map, {default} is either
" 'J' or 'gJ' to indicicate command behavior.
function! s:mapping(mode, mapping, default) abort
	let l:fname = {'n': 'joinNormal', 'v': 'joinVisual'}[a:mode]
	" See if mapping is already defined.  Returns empty string for native vim.
	let l:prevmap = maparg(a:mapping, a:mode)
	" If replacing an existing J/gJ mapping, call function with empty string
	" (don't execute cmd) and append the previous mapping to the end of this
	" one, which is easier than :exe on an arbitrary mapping string.  If
	" prevmap is empty (not replacing a mapping) or replacing a mapping other
	" than J/gJ (who knows what original does), function will call J/gJ in the
	" appropriate mode.
	let l:cmd = empty(l:prevmap) || a:mapping !=# a:default ? a:default : ''
	execute printf("%snoremap <silent> %s :<C-U>call conjoin#%s('%s')<CR>%s",
		\ a:mode, a:mapping, l:fname, l:cmd, l:prevmap)
endfunction

" User mapping override for normal/visual J.
if !exists('g:conjoin_map_J')
	let g:conjoin_map_J = 'J'
endif
" User mapping override for normal/visual gJ.
if !exists('g:conjoin_map_gJ')
	let g:conjoin_map_gJ = 'gJ'
endif

" nnoremap <silent> J :<C-U>call conjoin#joinNormal('J')<CR>
call s:mapping('n', g:conjoin_map_J, 'J')
" nnoremap <silent> gJ :<C-U>call conjoin#joinNormal('gJ')<CR>
call s:mapping('n', g:conjoin_map_gJ, 'gJ')
" vnoremap <silent> J :<C-U>call conjoin#joinVisual('J')<CR>
call s:mapping('v', g:conjoin_map_J, 'J')
" vnoremap <silent> gJ :<C-U>call conjoin#joinVisual('gJ')<CR>
call s:mapping('v', g:conjoin_map_gJ, 'gJ')

""
" Like :[range]join[!] [count] [flags] but removes continuation characters.
" Before joining lines, trailing line continuation characters are removed from
" each line in the range before the last and leading line continuation
" characters are removed from each line after the first.
command! -bang -bar -range -nargs=* Join
	\ :call conjoin#joinEx(<line1>, <line2>, <range>, <q-bang>, <q-args>)
