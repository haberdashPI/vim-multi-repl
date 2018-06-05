" repl.vim - frictionaless REPL interaction
" Maintainer: David F. Little
" Version: 0.3
" Licesnse: MIT

if &cp || exists('loaded_vimrepl')
  finish
endif
let loaded_vimrepl = 1

if version < 800
  echoer "vim-repl requires Vim 8"
  finish
end

let g:repl_size = get(g:,'repl_size',20)
let g:repl_position = get(g:,'repl_position','botright')
let g:repl_default_mappings= get(g:,'repl_default_mappings',1)
let g:repl_cd_prefix = get(g:,'repl_cd_prefix','cd ')
let g:repl_cd_suffix = get(g:,'repl_cd_suffix','')
let g:repl_run_prefix = get(g:,'repl_run_prefix','')
let g:repl_run_suffix = get(g:,'repl_run_suffix','')
let g:repl_send_prefix = get(g:,'repl_send_prefix','')
let g:repl_send_suffix = get(g:,'repl_send_suffix','')
let g:repl_send_text_delay = get(g:,'repl_send_text_delay','0m')

if has('win32')
  let g:repl_program = get(g:,'repl_program','sh.exe')
else
  let g:repl_program = get(g:,'repl_program','sh')
end

" choose a project and filetype specific name for the terminal
function s:REPLName(count)
  let l:count = a:count > 0 ? a:count : get(b:,'last_repl_count',1)
  let b:last_repl_count = l:count
  let l:projdir = projectroot#get(expand('%'))
  if len(l:projdir) > 0
    let l:name = "repl:" . fnamemodify(l:projdir,':t') . ":" . &filetype
  else
    let l:name = "repl:" . &filetype
  endif
  if l:count > 1
    return l:name . ':' . l:count
  else
    return l:name
  end
endfunction

" show the terminal, creating it if necessary
function s:REPLShow(repl,count,program,start_only)
  let l:dir = resolve(expand('%:p:h'))

  for i in range(1,bufnr('$'))
    if !empty(matchstr(bufname(i),'repl:.\+'))
      for w in win_findbuf(i)
        if bufname(i) !=# a:repl
          call win_gotoid(w)
          execute ":hide"
        endif
      endfor
    endif
  endfor

  if bufnr(a:repl) == -1
    call term_start(a:program,{ 
          \ "cwd": l:dir,
          \ "hidden": 1,
          \ "norestore": 1,
          \ "term_name": a:repl,
          \ "term_kill":  "term",
          \ "term_finish": "close"
          \ })
  elseif a:start_only
    echoer "Cannot start, already running a REPL."
  end

  " hide any other terminals
  for w in getwininfo()
    let l:name = bufname(w['bufnr'])
    if l:name =~ '^repl:'
      if l:name !=# a:repl
        exe w['winnr'] . "wincmd w" 
        wincmd c
      endif
    endif
  endfor

  if empty(win_findbuf(bufnr(a:repl)))
    execute ":" . g:repl_position . " sb" . bufnr(a:repl)
    execute ":resize " . g:repl_size
    call setbufvar(bufnr(a:repl),'&buflisted',0)
  endif
endfunction

" switch to terminal (showing it if necessary) when not in a terminal,
" hide the terminal and return to the buffer that opeend the terminal
" if it's already the active window
function REPLToggle(...)
  if a:0 > 0
    if a:1 =~# '^\d\+$'
      let l:count = a:1
      if a:0 > 1
        let l:program = join(a:000[1:-1]," ")
        let l:custom_start = 1
      else
        let l:program = get(b:,'repl_program',g:repl_program)
        let l:custom_start = 0
      end
    else
      let l:count = 0
      let l:program = join(a:000[0:-1]," ")
      let l:custom_start = 1
    end
  else
    let l:count = 0
    let l:program = get(b:,'repl_program',g:repl_program)
    let l:custom_start = 0
  end

  let l:use_shell = a:0 > 0 ? a:1 : 0
  let l:buf = bufname("%")
  if empty(matchstr(l:buf,'repl:.\+'))
    let l:repl = s:REPLName(l:count)
    call s:REPLShow(l:repl,l:count,l:program,l:custom_start)
    call win_gotoid(win_findbuf(bufnr(l:repl))[0])
    let b:opened_from = l:buf
  elseif !l:custom_start
    let l:gotowin = get(b:,'opened_from','')
    execute ":hide"
    if !empty(l:gotowin)
      let l:windows = win_findbuf(bufnr(l:gotowin))
      if !empty(l:windows)
        call win_gotoid(l:windows[0])
      endif
    endif
  endif
endfunction

function REPLSwitch()
  let l:parts = split(bufname('%'),':')
  let l:root = bufname('%')
  if l:parts[-1] =~ '\d\+'
    let l:root = join(l:parts[0:-2],':')
  end
  let l:num = nr2char(getchar())
  if l:num > 1
    let l:repl = l:root . ':' . l:num
  else
    let l:repl = l:root
  end
  call s:REPLShow(l:repl,l:num,get(b:,'repl_program',g:repl_program),0)
endfunction

" send a line to the terminal (showing it if necessary)
function REPLSendText(text,count,...)
  let l:buf = bufname("%")
  let l:win = win_getid()
  let l:delay = get(b:,'repl_send_text_delay',g:repl_send_text_delay)

  let l:prefix = get(b:,'repl_send_prefix',g:repl_send_prefix)
  let l:suffix = get(b:,'repl_send_suffix',g:repl_send_suffix)
  if !empty(matchstr(l:buf,'repl:\+'))
    echoer "Already in a terminal buffer." . 
          \ " Send text only works when focused on a text file."
  else
    let l:repl = s:REPLName(a:count)
    call s:REPLShow(l:repl,a:count,get(b:,'repl_program',g:repl_program),0)
    if a:0 > 0 && a:1 > 0
      call term_sendkeys(bufnr(l:repl),l:prefix)
      if l:delay !=# '0m'
        execute 'sleep ' . l:delay
      end
    end

    call term_sendkeys(bufnr(l:repl),a:text . "\n")

    if a:0 > 0 && a:1 > 0
      call term_sendkeys(bufnr(l:repl),l:suffix)
      if l:delay !=# '0m'
        execute 'sleep ' . l:delay
      end
    end
  endif
  call win_gotoid(l:win)
endfunction

function REPLCd(dir,count,global)
  if !a:global
    let l:prefix = get(b:,'repl_cd_prefix',g:repl_cd_prefix)
    let l:suffix = get(b:,'repl_cd_suffix',g:repl_cd_suffix)
  else
    let l:prefix = g:repl_cd_prefix
    let l:suffix = g:repl_cd_suffix
  end
  call REPLSendText(l:prefix . a:dir . l:suffix,a:count)
endfunction

function REPLRun(file,count,global)
  if !a:global
    let l:prefix = get(b:,'repl_run_prefix',g:repl_run_prefix)
    let l:suffix = get(b:,'repl_run_suffix',g:repl_run_suffix)
  else
    let l:prefix = g:repl_run_prefix
    let l:suffix = g:repl_run_suffix
  end
  call REPLSendText(l:prefix . a:file . l:suffix,a:count)
endfunction

function REPLSendTextOp(opfunc)
  let l:old_register = @@
  if a:opfunc ==# 'line'
    normal! `[V`]y`]j
  elseif a:opfunc ==# 'char'
    normal! `[v`]y`]
  else
    return
  endif

  call REPLSendText(@@,g:REPL_count_holder,1)
  let @@ = l:old_register
endfunction

function REPLResize(size)
  let l:curwin = win_getid()
  for i in range(1,bufnr('$'))
    if !empty(matchstr(bufname(i),'repl:.\+'))
      for w in win_findbuf(i)
        call win_gotoid(w)
        execute ":resize " . a:size
      endfor
    endif
  endfor
  call win_gotoid(l:curwin)
endfunction

function REPLCloseAll()
  for i in range(1,bufnr('$'))
    if !empty(matchstr(bufname(i),'repl:.\+'))
      echom "Closing " . bufname(i)
      execute ":bw! " . bufname(i)
    endif
  endfor
endfunction
      
command! -nargs=* -complete=shellcmd REPL :call REPLToggle(<f-args>)
command! -nargs=0 REPLCloseAll :call REPLCloseAll()
nnoremap <silent><Plug>(repl-send-motion)
      \ :<C-u>let g:REPL_count_holder=v:count<cr>
      \ :set operatorfunc=REPLSendTextOp<cr>g@
nnoremap <silent><Plug>(repl-send-text) 
      \ :<C-u>call REPLSendText(getline('.'),v:count,1)<cr>j
vnoremap <silent><Plug>(repl-send-text) 
      \ mr"ty:call REPLSendText(@t,v:count,1)<cr>`r
nnoremap <silent><Plug>(repl-toggle) :<C-u>call REPLToggle(v:count)<cr>
nnoremap <silent><Plug>(repl-cd) 
      \ :<C-u>call REPLCd(expand('%:p:h'),v:count,0)<cr>
nnoremap <silent><Plug>(repl-global-cd) 
      \ :<C-u>call REPLCd(expand('%:p:h'),v:count,1)<cr>
nnoremap <silent><Plug>(repl-run) 
      \ :<C-u>call REPLRun(resolve(expand('%:p')),v:count,0)<cr>
nnoremap <silent><Plug>(repl-resize) 
      \ :<C-u>call REPLResize(v:count > 0 ? v:count : g:repl_size)<cr>

tnoremap <silent><Plug>(repl-toggle) <C-w>:call REPLToggle(0)<cr>
tnoremap <silent><Plug>(repl-switch) <C-w>:call REPLSwitch()<cr>
tnoremap <silent><Plug>(repl-resize) <C-w>:call REPLResize(g:repl_size)<cr>

if g:repl_default_mappings == 1
  nmap <C-w>' <Plug>(repl-toggle)
  nmap <Leader>= <Plug>(repl-resize)
  tmap <C-w>' <Plug>(repl-toggle)

  nmap <Leader>. <Plug>(repl-send-motion)
  nmap <Leader>; <Plug>(repl-send-text)
  nmap <Leader>cd <Plug>(repl-cd)
  nmap <Leader>gcd <Plug>(repl-global-cd)
  nmap <Leader>r <Plug>(repl-run)
  tmap <C-w>= <Plug>(repl-resize)
  tmap <C-w>g <Plug>(repl-switch)
  tmap <C-w><C-u> <C-w>N<C-u>:set nonumber<cr>
  vmap <silent><Leader>. <Plug>(repl-send-text)
end

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" language specific config
au FileType javascript let b:repl_program='node'
au FileType javascript let b:repl_cd_prefix='process.chdir("'
au FileType javascript let b:repl_cd_suffix='")'
au FileType javascript let b:repl_run_prefix='.load '
au FileType javascript let b:repl_send_prefix=".editor\n"
au FileType javascript let b:repl_send_suffix="\n\<c-d>"
au FileType javascript let b:repl_send_text_delay='50m'

au FileType r let b:repl_program='R'
au FileType r let b:repl_cd_prefix='setwd("'
au FileType r let b:repl_cd_suffix='")'
au FileType r let b:repl_run_prefix='source("'
au FileType r let b:repl_run_suffix='")'

au FileType julia let b:repl_program='julia'
au FileType julia let b:repl_cd_prefix='cd("'
au FileType julia let b:repl_cd_suffix='")'
au FileType julia let b:repl_run_prefix='include("'
au FileType julia let b:repl_run_suffix='")'

au FileType matlab let b:repl_program='matlab -nodesktop -nosplash'
au FileType matlab let b:repl_cd_prefix='cd '
au FileType matlab let b:repl_run_prefix='run('''
au FileType matlab let b:repl_run_suffix=''')'

au FileType python let b:repl_program='ipython'
au FileType python let b:repl_cd_prefix='%cd '
au FileType python let b:repl_run_prefix='%run '
au FileType python let b:repl_send_text_delay='250m'
au FileType python let b:repl_send_prefix="%cpaste\n"
au FileType python let b:repl_send_suffix="\n--\n"
