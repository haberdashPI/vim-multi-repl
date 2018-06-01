" repl.vim - frictionaless REPL interaction
" Maintainer: David F. Little
" Version: 0.2
" Licesnse: MIT

if &cp || exists('loaded_vimrepl')
  finish
endif
let loaded_vimrepl = 1

if version < 800
  echom "vim-repl requires Vim 8"
  finish
end

let g:repl_size = get(g:,'repl_size',20)
let g:repl_default_mappings= get(g:,'repl_default_mappings',1)
let g:cd_prefix = get(g:,'cd_prefix','cd ')
let g:cd_suffix = get(g:,'cd_suffix','')
let g:run_prefix = get(g:,'run_prefix','')
let g:run_suffix = get(g:,'run_suffix','')

if has('win32')
  let g:repl_program = get(g:,'repl_program','sh.exe')
else
  let g:repl_program = get(g:,'repl_program','sh')
end

" choose a project and filetype specific name for the terminal
function! TerminalName(count)
  echom "Count " . a:count
  let l:count = a:count > 0 ? a:count : get(b:,'last_repl_count',1)
  let b:last_repl_count = l:count
  echom "Chosen count " . l:count
  let l:projdir = projectroot#get(expand('%'))
  if len(l:projdir) > 0
    let l:name = "term:" . fnamemodify(l:projdir,':t') . ":" . &filetype
  else
    let l:name = "term:" . &filetype
  endif
  if l:count > 1
    return l:name . ':' . l:count
  else
    return l:name
  end
endfunction

" show the terminal, creating it if necessary
function! ShowTerminal(term,count,use_shell)
  let l:dir = resolve(expand('%:p:h'))

  for i in range(1,bufnr('$'))
    if !empty(matchstr(bufname(i),'term:.\+'))
      for w in win_findbuf(i)
        if bufname(i) !=# a:term
          call win_gotoid(w)
          execute ":hide"
        endif
      endfor
    endif
  endfor

  if bufnr(a:term) == -1
    if a:use_shell == 1
      let l:program = g:repl_program
    else
      let l:program = get(b:,'repl_program',g:repl_program)
    end

    call term_start(l:program,{ 
          \ "hidden": 1,
          \ "norestore": 1,
          \ "term_name": a:term,
          \ "term_kill":  "term",
          \ "term_finish": "close"
          \ })
    call setbufvar(bufnr(a:term),'use_shell',a:use_shell)
    call TermCd(l:dir,a:count)
  elseif a:use_shell == 1
    echom "Cannot start shell in already running REPL"
  end

  " hide any other terminals
  for w in getwininfo()
    let l:name = bufname(w['bufnr'])
    if l:name =~ '^term:'
      if l:name !=# a:term
        exe w['winnr'] . "wincmd w" 
        wincmd c
      endif
    endif
  endfor

  if empty(win_findbuf(bufnr(a:term)))
    execute ":botright sb" . bufnr(a:term)
    execute ":resize " . g:repl_size
    call setbufvar(bufnr(a:term),'&buflisted',0)
    let b:use_shell = a:use_shell
  endif
endfunction

" switch to terminal (showing it if necessary) when not in a terminal,
" hide the terminal and return to the buffer that opeend the terminal
" if it's already the active window
function! ToggleTerminal(count,...)
  let l:use_shell = a:0 > 0 ? a:1 : 0
  let l:buf = bufname("%")
  if empty(matchstr(l:buf,'term:.\+'))
    let l:term = TerminalName(a:count)
    call ShowTerminal(l:term,a:count,l:use_shell)
    call win_gotoid(win_findbuf(bufnr(l:term))[0])
    let b:opened_from = l:buf
  else
    let l:gotowin = b:opened_from
    execute ":hide"
    let l:windows = win_findbuf(bufnr(l:gotowin))
    if !empty(l:windows)
      call win_gotoid(l:windows[0])
    end
  endif
endfunction

function! SwitchTerminal()
  let l:parts = split(bufname('%'),':')
  let l:root = bufname('%')
  if l:parts[-1] =~ '\d\+'
    let l:root = join(l:parts[0:-2],':')
  end
  let l:num = nr2char(getchar())
  if l:num > 1
    let l:term = l:root . ':' . l:num
  else
    let l:term = l:root
  end
  call ShowTerminal(l:term,l:num,0)
endfunction

" send a line to the terminal (showing it if necessary)
function! TermSendText(text,count)
  let l:buf = bufname("%")
  let l:win = win_getid()
  if !empty(matchstr(l:buf,'term:\+'))
    echoer "Already in a terminal buffer." . 
          \ " Send text only works when focused on a text file."
  else
    let l:term = TerminalName(a:count)
    call ShowTerminal(l:term,a:count,0)
    call term_sendkeys(bufnr(l:term),a:text . "\n")
  endif
  call win_gotoid(l:win)
endfunction

function! TermCd(dir,count)
  if !getbufvar(bufnr(TerminalName(a:count)),'use_shell',0)
    let l:prefix = get(b:,'cd_prefix',g:cd_prefix)
    let l:suffix = get(b:,'cd_suffix',g:cd_suffix)
  else
    let l:prefix = g:cd_prefix
    let l:suffix = g:cd_suffix
  end
  call TermSendText(l:prefix . a:dir . l:suffix,a:count)
endfunction

function! TermRun(file,count)
  if !getbufvar(bufnr(TerminalName(a:count)),'use_shell',0)
    let l:prefix = get(b:,'run_prefix',g:run_prefix)
    let l:suffix = get(b:,'run_suffix',g:run_suffix)
  else
    let l:prefix = g:run_prefix
    let l:suffix = g:run_suffix
  end
  call TermSendText(l:prefix . a:file . l:suffix,a:count)
endfunction

nnoremap <silent><Plug>(repl-send-text) :<C-u>call TermSendText(getline('.'),v:count)<cr>j
nnoremap <silent><Plug>(repl-toggle) :<C-u>call ToggleTerminal(v:count)<cr>
nnoremap <silent><Plug>(repl-shell) :<C-u>call ToggleTerminal(v:count,1)<cr>
nnoremap <silent><Plug>(repl-cd) :<C-u>call TermCd(expand('%:p:h'),v:count)<cr>
nnoremap <silent><Plug>(repl-run) :<C-u>call TermRun(resolve(expand('%:p')),v:count)<cr>
" TODO: add repl-resize for normal mode
tnoremap <silent><Plug>(repl-toggle) <C-w>:call ToggleTerminal(0)<cr>
tnoremap <silent><Plug>(repl-switch) <C-w>:call SwitchTerminal()<cr>
tnoremap <silent><Plug>(repl-resize) <C-w>:execute ":resize " . g:repl_size<cr>
vnoremap <silent><Plug>(repl-send-text) mr"ty:call TermSendText(@t,v:count)<cr>`r

if g:repl_default_mappings == 1
  nmap <Leader>sh <Plug>(repl-shell-toggle)
  nmap <Leader>' <Plug>(repl-toggle)
  tmap <C-w>' <Plug>(repl-toggle)

  nmap <Leader>. <Plug>(repl-send-text)
  nmap <Leader>cd <Plug>(repl-cd)
  nmap <Leader>r <Plug>(repl-run)
  tmap <C-w>= <Plug>(repl-resize)
  tmap <C-w>g <Plug>(repl-switch)
  tmap <C-w><C-u> <C-w>N<C-u>:set nonumber<cr>
  vmap <silent><Leader>. <Plug>(repl-send-text)
end
