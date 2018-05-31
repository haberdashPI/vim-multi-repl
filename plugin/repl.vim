" repl.vim - frictionaless REPL interaction
" Maintainer: David F. Little
" Version: 0.2
" Licesnse: MIT

if &cp || exists('loaded_vimrepl')
  finish
endif
let loaded_vimrepl = 1

if version < 800
  echo "vim-repl requires Vim 8"
  finish
end

let g:repl_size = get(g:,'repl_size',20)
let g:repl_default_mappings=1
if has('win32')
  let g:repl_program = get(g:,'repl_program','sh.exe')
else
  let g:repl_program = get(g:,'repl_program','sh')
end

" choose a project and filetype specific name for the terminal
function! TerminalName()
  let l:projdir = projectroot#get(expand('%'))
  if len(l:projdir) > 0
    return "term:" . fnamemodify(l:projdir,':t') . ":" . &filetype
  else
    return "term:" . &filetype
  endif
endfunction

" show the terminal, creating it if necessary
function! ShowTerminal(term)
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
    let l:program = get(b:,'terminal_program',g:terminal_program)
    call term_start(l:program,{ 
          \ "hidden": 1,
          \ "norestore": 1,
          \ "term_name": a:term,
          \ "term_kill":  "term",
          \ "term_finish": "close"
          \ })
    call TermCd(l:dir)
  endif

  if empty(win_findbuf(bufnr(a:term)))
    execute ":botright sb" . bufnr(a:term)
    execute ":resize " . g:terminal_size
    call setbufvar(bufnr(a:term),'&buflisted',0)
  endif
endfunction

" switch to terminal (showing it if necessary) when not in a terminal,
" hide the terminal and return to the buffer that opeend the terminal
" if it's already the active window
function! ToggleTerminal()
  let l:buf = bufname("%")
  if empty(matchstr(l:buf,'term:.\+'))
    let l:term = TerminalName()
    call ShowTerminal(l:term)
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

" send a line to the terminal (showing it if necessary)
function! TermSendText(text)
  let l:buf = bufname("%")
  let l:win = win_getid()
  if !empty(matchstr(l:buf,'term:\+'))
    echoer "Already in a terminal buffer." . 
          \ " Send text only works when focused on a text file."
  else
    let l:term = TerminalName()
    call ShowTerminal(l:term)
    call term_sendkeys(bufnr(l:term),a:text . "\n")
  endif
  call win_gotoid(l:win)
endfunction

function! TermCd(dir)
  let l:prefix = get(b:,'cd_prefix','cd ')
  let l:suffix = get(b:,'cd_suffix','')
  call TermSendText(l:prefix . a:dir . l:suffix)
endfunction

function! TermRun(file)
  let l:prefix = get(b:,'run_prefix','./')
  let l:suffix = get(b:,'run_suffix','')
  call TermSendText(l:prefix . a:file . l:suffix)
endfunction

nnoremap <silent><Plug>(repl-send-text) :call TermSendText(getline('.'))<cr>j
nnoremap <silent><Plug>(repl-toggle) :call ToggleTerminal()<cr>
nnoremap <silent><Plug>(repl-cd) :call TermCd(expand('%:p:h'))<cr>
nnoremap <silent><Plug>(repl-run) :call TermRun(resolve(expand('%:p')))<cr>
" TODO: add repl-resize for normal mode
tnoremap <silent><Plug>(repl-toggle) <C-w>:call ToggleTerminal()<cr>
tnoremap <silent><Plug>(repl-resize) <C-w>:execute ":resize " . g:repl_size<cr>
vnoremap <silent><Plug>(repl-send-text) mr"ty:call TermSendText(@t)<cr>`r

if g:repl_default_mappings == 1
  map <Leader>t <Plug>(repl-toggle)
  nmap <Leader>. <Plug>(repl-send-text)
  nmap <Leader>cd <Plug>(repl-cd)
  nmap <Leader>r <Plug>(repl-run)
  tmap <Leader>= <Plug>(repl-resize)
  tmap <C-w><C-u> <C-w>N<C-u>:set nonumber<cr>
  vmap <silent><Leader>. <Plug>(repl-send-text)
end
