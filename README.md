# vim-repl

A plugin for sane, frictionless interaction with multiple REPLs and shells.
A REPL is a command line program that runs your code. When you call
`python` or `matlab` on the command line, the prompt that comes up is a REPL.

This plugin opens REPL's on a per project and per file type basis. That way
each project you are working can have a REPL for each filetype (langauge) it
uses and a single command sends your code to the appropriate REPL based on the
file you're currently in. It uses
[vim-projectroot](https://github.com/dbakker/vim-projectroot)) to determine the
current project.

The available commands are:

1. `<Plug>(repl-toggle)` - open/hide a REPL, (runs a language specific program)
2. `<Plug>(repl-shell)` - open a REPL but start it in the shell (OS general command line)
2. `<Plug>(repl-cd)` - change the directory of the REPL
3. `<Plug>(repl-run)` - run the current file in the REPL
4. `<Plug>(repl-send-text)` - send the current line or selected region to the REPL
5. `<Plug>(repl-resize)` - resize REPL to be `g:repl_size` lines.
6. `<Plug>(repl-switch)` - while in the REPL, switch to REPL 1-9 (see below)

The default mappings are as follows

```vim
nmap <Leader>' <Plug>(repl-toggle)
nmap <Leader>sh <Plug>(repl-shell-toggle)
tmap <C-w>' <Plug>(repl-toggle)

nmap <Leader>. <Plug>(repl-send-text)
vmap <Leader>. <Plug>(repl-send-text)
nmap <Leader>cd <Plug>(repl-cd)
nmap <Leader>r <Plug>(repl-run)
tmap <C-w>= <Plug>(repl-resize)
tmap <C-w>g <Plug>(repl-switch)

" not strictly related to plugin commands, but very handy for quickly reading errors
" that scroll past the size of the REPL screen.
tmap <C-w><C-u> <C-w>N<C-u>:set nonumber<cr> 
```

If you wish to remove the default mappings you can add `let
g:repl_default_mappings=0` to `.vimrc`.

## Configuration

By default the cd and run commands assume you are operating in a standard unix
shell. However, you can easily configure cd and run for your specific
language or shell. For example, to configure the commands for the
[Julia](https://julialang.org/) language you could do the following:

```vim
augroup Julia
  au!
  au FileType julia let b:repl_program='julia'
  au FileType julia let b:cd_prefix='cd("'
  au FileType julia let b:cd_suffix='")'
  au FileType julia let b:run_prefix='include("'
  au FileType julia let b:run_suffix='")'
augroup END
```

These language specific variables are only used when a REPL is first opened with
`<Plug>(repl-toggle)` not `<Plug>(repl-shell)`. With `<Plug>(repl-shell)` the
global defaults are used, which are specified by global variables by the same
name.

## Mutliple REPLs

If you want to get fancy, you can have multiple REPLS per filetype and project.
Use the `<Plug>(repl-switch)` command to switch between different REPLS while
in one, and pass a count to `<Plug>(repl-toggle)` to switch to a specific REPL

In fact, each of the commands can take a count which is used to specify which
REPL to use. When no count is specified, the last REPL that was opened or that
text was sent to is used. If this REPL was closed, it gets reoponed.

## TODO:
1. add prefixs for sending text (e.g. for ipython)
2. create an operator
3. make the location of the REPL configuraable
4. make it possible to resize the REPL when not in the REPL
