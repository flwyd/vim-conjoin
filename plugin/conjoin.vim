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
" Note that vim already removes leading comment characters when joining lines
" in a block comment.
"
" conjoin works with several programming languages by default, see
" @section(config) for details.

""
" @section Mappings, mappings
" J  Join [count] lines, as with the builtin |J| command.  Before joining
" lines, trailing and/or leading continuation escape characters will be
" removed from the lines to be joined.
"
" {Visual}J  Join the highlighted lines, as with the builtin |v_J| command.
" Before joining lines, trailing and/or leading continuation escape characters
" will be removed from the lines to be joined.
"
" gJ  Like J but with joining semantics like the builtin |gJ|.
"
" {Visual}gJ  Like J but with joining semantics like the builtin |v_gJ|.

if exists('did_conjoin') || &cp || version < 700
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
let s:default_filetypes = {
			"\ Shell-style languages use trailing backslash
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
			"\ Mathematica/Wolfram Language uses trailing
			"\ backslash or special character Unicode F3B1 ()
			\ 'mma': {'trailing': '[\uF3B1\\]$'},
			"\ PowerShell uses a trailing backtick
			\ 'ps1': {'trailing': '\s`$'},
			"\ Visual Basic and friends use a trailing underscore
			\ 'autoit': {'trailing': '\s_$'},
			\ 'cobra': {'trailing': '\s_$'},
			\ 'vb': {'trailing': '\s_$'},
			"\ Vim uses leading backslash, :help line-continuation
			\ 'vim': {'leading': '^\s*\\'},
			"\ Fortran uses trailing ampersand and optionally a
			"\ leading ampersand on the next line
			\ 'fortran': {'trailing': '&\s*$', 'leading': '^\s*&'},
			"\ TeX continues lines ending with empty comment %
			\ 'tex': {'trailing': '%$'},
			\ 'context': {'trailing': '%$'},
			\ 'plaintex': {'trailing': '%$'},
			"\ m4 trailing dnl comments avoid printing newlines
			\ 'm4': {'trailing': '\<dnl$'},
			\}

" Populate g:conjoin_filetypes with defaults, respecting user overrides.
call extend(g:conjoin_filetypes, s:default_filetypes, 'keep')

" Map J in normal and visual mode.
nnoremap <silent> J :<C-U>call conjoin#joinNormal('J')<CR>
nnoremap <silent> gJ :<C-U>call conjoin#joinNormal('gJ')<CR>
vnoremap <silent> J :<C-U>call conjoin#joinVisual('J')<CR>
vnoremap <silent> gJ :<C-U>call conjoin#joinVisual('gj')<CR>

""
" Like :[range]join[!] [count] [flags] but removes continuation characters.
" Before joining lines, trailing line continuation characters are removed from
" each line in the range before the last and leading line continuation
" characters are removed from each line after the first.
command! -bang -bar -range -nargs=* Join
	\ :call conjoin#joinEx(<line1>, <line2>, <range>, <q-bang>, <q-args>)
