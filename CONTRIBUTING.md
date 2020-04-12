# How to Contribute

We'd love to accept your patches and contributions to this project. There are
just a few small guidelines you need to follow.

## Contributor License Agreement

Contributions to this project must be accompanied by a Contributor License
Agreement. You (or your employer) retain the copyright to your contribution;
this simply gives us permission to use and redistribute your contributions as
part of the project. Head over to <https://cla.developers.google.com/> to see
your current agreements on file or to sign a new one.

You generally only need to submit a CLA once, so if you've already submitted one
(even if it was for a different project), you probably don't need to do it
again.

## Change Guidelines

Most changes should be discussed in a GitHub issue first.  This plugin should
do one thing well—intuitive line joining.  I may therefore reject feature
requests that stray from that focus.

Pull requests are welcome to fix bugs or vim compatibility issues, or to support
continuation lines for additional languages.  I don’t know how to write valid
code all of the supported languages, so it’s possible that the patterns are
incorrect.  I would love to improve them!

vim-conjoin uses [vader.vim](https://github.com/junegunn/vader.vim) for
testing.  Please include a unit test with any pull request.  You can run all
tests with `path/to/vim-conjoin/tests/runtests`.  This script can also run
specific `.vader` test files as arguments and accepts `VIM_CMD` and
`VADER_PLUGIN` environment variables to test with a non-default `vim` version or
specify the path to `vader.vim`.  To interactively inspect test results, run
`VADER=Vader tests/runtests`.

## Community Guidelines

The Internet brings together billions of people with different backgrounds,
values, worldviews, and personal situations.  Be excellent to each other, and
don’t be a jerk when participating in open source software.  Please follow the
[Contributor Covenant](https://contributor-covenant.org/).
