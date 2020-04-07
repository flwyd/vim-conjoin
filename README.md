# vim-conjoin
Remove continuation characters when joining lines in vim.

`conjoin` is a [Vim](https://vim.org/) plugin that handles line joining in the
presence of line continuation characters.  Vim's normal behavior for `J` and
`:join` on the following shell script:

```sh
  cat file.txt \
    | sort \
    | uniq -c
```

leaves the backslash continuation characters in place:

```sh
cat file.txt \ | sort \ | uniq -c
```

With `conjoin`, running join commands on the same script will produce

```sh
  cat file.txt | sort | uniq -c
```

Note that vim already removes leading comment characters when joining lines
in a block comment.

## Installation

Use your favorite plugin manager, e.g.

```vim
" vim-plug:
Plug 'flwyd/vim-conjoin'
" Vundle:
Plugin 'flwyd/vim-conjoin'
" vim-addon-manager:
VAMActivate github:flwyd/vim-conjoin
```

or `git clone https://github.com/flwyd/vim-conjoin` and set
`runtimepath+=/path/to/vim-conjoin` in your `.vimrc`.

## Filetype support

`conjoin` currently supports line continuation patterns for the following types:

*   `autoit`
*   `bash`
*   `c`
*   `cobra`
*   `context`
*   `cpp`
*   `csh`
*   `fortran`
*   `m4`
*   `mma`
*   `plaintex`
*   `ps1`
*   `python`
*   `ruby`
*   `sh`
*   `tcl`
*   `tcsh`
*   `tex`
*   `texmf`
*   `vb`
*   `vim`
*   `zsh`

You can add support for your own filetypes in your `.vimrc`:

```vim
if !exists('g:conjoin_filetypes')
  let g:conjoin_filetypes = {}
endif
g:conjoin_filetypes.intercal = {'leading': '^\s*PLEASE', 'trailing': '\\$'}
" Or use a literal-Dict in Vim 8.1.1705+
" g:conjoin_filetypes.intercal = #{leading: '^\s*PLEASE', trailing: '\\$'}
```

Run `:help conjoin-config` for more details.

## License and Contributing

The code in this project is made available under an Apache 2.0 open source
license.  Copyright 2020 Google LLC.  This is not an official Google project.

Pull requests to add line continuation support for additional filetypes are
welcome, but please read the [CONTRIBUTING] document first.
