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
" characters when joining lines and merge literal strings.  Works with J/gJ
" alone, with a count, or in visual mode.  Also provides a :[range]Join[!]
" command.

""
" @section Introduction, intro
" @order intro commands mappings config functions
" conjoin is a plugin that handles line joining in the presence of line
" continuation characters and merges literal strings.  Vim's normal behavior
" for |J| and |:join| on the following shell script: >
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
" conjoin also merges quoted string literals, which are often spread over
" multiple lines.  For example, in Python: >
"   print('Lorem ipsum '
"         'sic dolor amet,'
"         + ' consectetur adipisicing elit')
" < would normally be joined as >
"   print('Lorem ipsum ' 'sic dolor amet,' + ' consectetur adipisicing elit')
" < but conjoin will join it into a single literal string: >
"   print('Lorem ipsum sic dolor amet, consectetur adipisicing elit')
" <
"
" If the plugin https://github.com/tpope/vim-repeat is installed,
" |conjoin-J|, |conjoin-gJ|, |conjoin-v_J|, and |conjoin-v_gJ| can be repeated
" with |.| .  Repeating a command will join the same number of lines as the
" original command count or visual line count.  Like |:join|, |:Join| is not
" repeatable.
"
" Note that vim already removes leading comment characters when joining lines
" in a block comment when |formatoptions| contains the 'j' flag.  conjoin
" currently removes line continuation characters in comments and does not
" merge strings with intervening comment characters.  For example, >
"   # Line 1 \
"   # "Line 2" +
"   # "Line 3"
" < will join as >
"   # Line 1 "Line 2" "Line 3"
" < but >
"   /* "Line 1" +
"    * "Line 2" +
"      "Line 3"
"    */
" < will join as >
"   /* "Line 1" + "Line 2Line3" */
" <
" This comment behavior is subject to change.
"
" conjoin works with several programming languages by default, see
" @section(config) for details.

""
" @section Mappings, mappings
" *conjoin-J*
" J  Join [count] lines, as with the builtin |J| command.  Before joining
" lines, trailing and/or leading continuation escape characters will be
" removed from the lines to be joined and trailing/leading literal strings
" will be merged.
"
" *conjoin-v_J*
" {Visual}J  Join the highlighted lines, as with the builtin |v_J| command.
" Before joining lines, trailing and/or leading continuation escape characters
" will be removed from the lines to be joined and trailing/leading literal
" strings will be merged.
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
" @setting(g:conjoin_filetypes) configures continuation patterns for many
" programming lanugages.  It is a dict with filetypes (e.g. "sh", "ruby",
" "vim") as keys and conjoin pattern dicts as values.  A conjoin dict has
" optional `trailing` and `leading` keys mapped to regular expression patterns.
" A conjoin dict may also have a `quote` entry mapped to a list of 2-element
" lists of trailing/leading patterns for string literal concatenation, e.g. >
"   [['"\s*+\s*$', '^\s*"'], ['"\s*$', '^\s*+\s*"']]
" < for double-quoted string literals concatenated with a + operator.
" When conjoin mappings or functions are called, the current buffer's
" 'filetype' is looked up in g:conjoin_filetypes.  If it contains a conjoin
" dict, the "trailing" pattern will be matched against each join line (except
" the last) and the "leading" pattern will be matched against each join line
" (except the first).  Make sure to include $ at the end of trailing patterns
" and ^ at the beginning of leading patterns.  Example use in .vimrc: >
"   if !exists('g:conjoin_filetypes')
"     let g:conjoin_filetypes = {}
"   endif
"   g:conjoin_filetypes.intercal = #{leading: '^\s*PLEASE', trailing: '\\$'}
"   g:conjoin_filetypes.lolcode = #{quote: [['\s*MKAY?\s*$', '^\s*SMOOSH']]}
" <
" A buffer-local variable b:conjoin_patterns can replace the global filetype
" settings.
"
" Setting @setting(g:conjoin_merge_strings)=0 or
" @setting(b:conjoin_merge_strings)=0 will disable merging string literals.
"
" The default set of line continuation filetypes is >
"   applescript autoit bash c cobra context cpp csh fortran m4 make mma
"   plaintex ps1 python ruby sh tcl tcsh tex texmf vb vim vroom zsh
" < and the default set of string-merging filetypes is >
"   ada applescript c cobol cobra cpp cs d dart elixir erlang fortran go
"   haskell java javascript julia kotlin lua mma pascal perl php ps1 python
"   raku ruby rust scala swift typescript vb vhdl vim
" <

if !exists('g:conjoin_filetypes')
	" @setting g:conjoin_filetypes
	let g:conjoin_filetypes = {}
endif

if !exists('g:conjoin_merge_strings')
	" @setting g:conjoin_merge_strings
	let g:conjoin_merge_strings = 1
endif

" Common tring literal patterns: lists of [trailing, leading] pairs.
" Two sequential "strings" as in C/C++/D/Python/Ruby
let s:double_quote_sequential = [['"\s*$', '^\s*"']]
" Two sequential 'strings' as in Python/Ruby
let s:single_quote_sequential = [["'\\s*$", "^\\s*'"]]
" Two "strings" with a + concatenation operator as in C#/Go/Java/JS/Rust/...
let s:double_quote_plus = [['"\s*+\s*$', '^\s*"'], ['"\s*$', '^\s*+\s*"']]
" Two 'strings' with a + concatenation operator as in JS/Pascal/PowerShell/...
let s:single_quote_plus = [["'\\s*+\\s*$", "^\\s*'"], ["'\\s*$", "^\\s*+\\s*'"]]
" Two `strings` with a + concatenation operator as in JavaScript/TypeScript
let s:backtick_plus = [['`\s*+\s*$', '^\s*`'], ['`\s*$', '^\s*+\s*`']]
" Two "strings" with a ++ concatenation operator as in Erlang/Haskell
let s:double_quote_double_plus = [['"\s*++\s*$', '^\s*"'], ['"\s*$', '^\s*++\s*"']]
" Two "strings" with a . concatenation operator as in Perl/PHP/Vim
let s:double_quote_dot = [['"\s*\.\s*$', '^\s*"'], ['"\s*$', '^\s*\.\s*"']]
" Two 'strings' with a . concatenation operator as in Perl/PHP/Vim
let s:single_quote_dot = [["'\\s*\\.\\s*$", "^\\s*'"], ["'\\s*$", "^\\s*\\.\\s*'"]]
" Two "strings" with a ~ concatenation operator as in D/Raku
let s:double_quote_tilde = [['"\s*\~\s*$', '^\s*"'], ['"\s*$', '^\s*\~\s*"']]
" Two 'strings' with a ~ concatenation operator as in Raku
let s:single_quote_tilde = [["'\\s*\\~\\s*$", "^\\s*'"], ["'\\s*$", "^\\s*\\~\\s*'"]]
" Two "strings" with a & concatenation operator as in Ada/AppleScript/COBOL/VB
let s:double_quote_ampersand = [['"\s*&\s*$', '^\s*"'], ['"\s*$', '^\s*&\s*"']]
" Two "strings" with a <> concatenation operator as in Elixir/Wolfram
let s:double_quote_left_right = [['"\s*<>\s*$', '^\s*"'], ['"\s*$', '^\s*<>\s*"']]

" TODO Don't merge multiline literals (e.g. three quotes) with normal strings
" TODO "foo" + r"bar" isn't merged, but r"foo" + "bar" merges to r"foobar"
" but raw strings and other special syntax shouldn't be merged.

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
" AppleScript uses Option-L/Unicode 00AC NOT SIGN (¬)
"   applescript
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
"
" Quote-merging-only languages are listed in alphabetic order after languages
" with line continuation support, which are grouped by syntax.
let s:default_filetypes = {
			\ 'make': {'trailing': '\\$'},
			\ 'sh': {'trailing': '\\$'},
			\ 'bash': {'trailing': '\\$'},
			\ 'csh': {'trailing': '\\$'},
			\ 'tcsh': {'trailing': '\\$'},
			\ 'zsh': {'trailing': '\\$'},
			\ 'c': {'trailing': '\\$',
				\ 'quote': s:double_quote_sequential},
			\ 'cpp': {'trailing': '\\$',
				\ 'quote': s:double_quote_sequential},
			\ 'python': {'trailing': '\\$',
				\ 'quote': s:double_quote_plus + s:single_quote_plus
					\ + s:double_quote_sequential + s:single_quote_sequential},
			\ 'ruby': {'trailing': '\\$',
				\ 'quote': s:double_quote_plus + s:single_quote_plus
					\ + s:double_quote_sequential + s:single_quote_sequential},
			\ 'tcl': {'trailing': '\\$'},
			\ 'texmf': {'trailing': '\\$'},
			\ 'mma': {'trailing': '[\uF3B1\\]$',
				\ 'quote': s:double_quote_left_right},
			\ 'ps1': {'trailing': '\s`$',
				\ 'quote': s:double_quote_plus + s:single_quote_plus},
			\ 'autoit': {'trailing': '\s_$'},
			\ 'cobra': {'trailing': '\s_$',
				\ 'quote': s:double_quote_plus + s:single_quote_plus},
			\ 'vb': {'trailing': '\s_$',
				\ 'quote': s:double_quote_ampersand},
			\ 'applescript': {'trailing': '[\u00AC]$',
				\ 'quote': s:double_quote_ampersand},
			\ 'vim': {'leading': '^\s*\\',
				\ 'quote': s:single_quote_dot + s:double_quote_dot},
			\ 'vroom': {'leading': '\v^\s*\|'},
			\ 'fortran': {'trailing': '&\s*$', 'leading': '^\s*&',
				\ 'quote': [['"\s*//\s*$', '^\s*"'], ['"\s*$', '^\s*//\s*"']]},
			\ 'tex': {'trailing': '%$'},
			\ 'context': {'trailing': '%$'},
			\ 'plaintex': {'trailing': '%$'},
			\ 'm4': {'trailing': '\<dnl$'},
			\ 'ada': {'quote': s:double_quote_ampersand},
			\ 'cobol': {'quote': s:double_quote_ampersand},
			\ 'cs': {'quote': s:double_quote_plus},
			\ 'd': {'quote': s:double_quote_tilde},
			\ 'dart': {'quote': s:double_quote_plus + s:single_quote_plus
				\ + s:double_quote_sequential + s:single_quote_sequential},
			\ 'elixir': {'quote': s:double_quote_left_right},
			\ 'erlang': {'quote': s:double_quote_double_plus
				\ + s:double_quote_sequential},
			\ 'haskell': {'quote': s:double_quote_double_plus},
			\ 'go': {'quote': s:double_quote_plus},
			\ 'java': {'quote': s:double_quote_plus},
			\ 'javascript': {'quote': s:double_quote_plus
				\ + s:single_quote_plus + s:backtick_plus},
			\ 'julia': {'quote': [['"\s*\*\s*$', '^\s*"'], ['"\s*$', '^\s*\*\s*"']]},
			\ 'kotlin': {'quote': s:double_quote_plus},
			\ 'lua': {'quote': [['"\s*\.\.\s*$', '^\s*"'], ['"\s*$', '^\s*\.\.\s*"']]},
			\ 'pascal': {'quote': s:single_quote_plus},
			\ 'perl': {'quote': s:double_quote_dot + s:single_quote_dot},
			\ 'php': {'quote': s:double_quote_dot + s:single_quote_dot},
			\ 'raku': {'quote': s:double_quote_tilde + s:single_quote_tilde},
			\ 'perl6': {'quote': s:double_quote_tilde + s:single_quote_tilde},
			\ 'rust': {'quote': s:double_quote_plus},
			\ 'scala': {'quote': s:double_quote_plus},
			\ 'swift': {'quote': s:double_quote_plus},
			\ 'typescript': {'quote': s:double_quote_plus
				\ + s:single_quote_plus + s:backtick_plus},
			\ 'vhdl': {'quote': s:double_quote_ampersand},
			\}

" Populate g:conjoin_filetypes with defaults, respecting user overrides.
call extend(g:conjoin_filetypes, s:default_filetypes, 'keep')

" Define a normal/visual mode mapping, respecting existing mapping.
" {mode} is 'n' or 'x', {mapping} is the key(s) to map, {default} is either
" 'J' or 'gJ' to indicicate command behavior.
function! s:mapping(mode, mapping, default) abort
	let l:fname = {'n': 'joinNormal', 'x': 'joinVisual'}[a:mode]
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
" xnoremap <silent> J :<C-U>call conjoin#joinVisual('J')<CR>
call s:mapping('x', g:conjoin_map_J, 'J')
" xnoremap <silent> gJ :<C-U>call conjoin#joinVisual('gJ')<CR>
call s:mapping('x', g:conjoin_map_gJ, 'gJ')

""
" Like :[range]join[!] [count] [flags] but removes continuation characters
" and merges trailing/leading concatenated string literals.  Before joining
" lines, trailing line continuation characters are removed from each line in
" the range before the last and leading line continuation characters are
" removed from each line after the first.
command! -bang -bar -range -nargs=* Join
	\ :call conjoin#joinEx(<line1>, <line2>, <range>, <q-bang>, <q-args>)
