# vim-repl

A plugin for sane, frictionless interaction with multiple REPLs or terminals.

Each REPL is specific to the filetype and project directory (as determined by
[vim-projectroot](https://github.com/dbakker/vim-projectroot)).

The available commands are:

1. `<Plug>(repl-toggle)` - open/close a terminal window at the bottom of the screen.
2. `<Plug>(repl-cd)` - change the directory of the REPL to that of the current file.
3. `<Plug>(repl-run)` - run the current file in the REPL
4. `<Plug>(repl-send-text)` - send the current line or selected region to the REPL
5. `<Plug>(repl-resize)` - resize REPL to be `g:repl_size` lines.

**TODO**: create an operator 

The default mappings are as follows

```vim
map <Leader>t <Plug>(repl-toggle)
nmap <Leader>. <Plug>(repl-send-text)
nmap <Leader>cd <Plug>(repl-cd)
nmap <Leader>r <Plug>(repl-run)
tmap <Leader>= <Plug>(repl-resize)
tmap <C-w><C-u> <C-w>N<C-u>:set nonumber<cr>
vmap <silent><Leader>. <Plug>(repl-send-text)
```

By default cd and run assume you are operating in a standard unix shell.
However, you can easily configure cd and run for your specific language as follows:

```vim
augroup Julia
  au!
  au FileType julia let b:repl_program='julia'
  au FileType julia let b:cd_prefix='cd("'
  au FileType julia let b:cd_suffix='")'
  au FileType julia let b:run_suffix='include("'
  au FileType julia let b:run_suffix='")'
augroup END
```

**TODO**: add prefixs for sending text (e.g. for ipython)

Run `:h repl` in vim for more details.
