" multi-repl.vim - frictionaless REPL interaction
" Maintainer: David F. Little <david.frank.little@gmail.com>
" Version: 0.4.0
" Licesnse: MIT

if &compatible || exists('loaded_vimmultirepl')
  finish
endif
let g:loaded_vimmultirepl = 1

if v:version < 800 && !has('nvim')
  echoer 'vim-multi-repl requires Vim 8 or neovim'
  finish
end

let g:repl_size = get(g:,'repl_size',20)
let g:repl_position = get(g:,'repl_position','botright')
let g:repl_default_mappings= get(g:,'repl_default_mappings',1)
let g:repl_cd_prefix = get(g:,'repl_cd_prefix','cd "')
let g:repl_cd_suffix = get(g:,'repl_cd_suffix','"')
let g:repl_run_prefix = get(g:,'repl_run_prefix','"')
let g:repl_run_suffix = get(g:,'repl_run_suffix','"')
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
    echo "projdir: ".l:projdir
    let l:name = "repl:" . fnamemodify(l:projdir,':t') . ":" . &filetype
  elseif !empty(&filetype)
    let l:name = "repl:" . &filetype
  else
    let l:name = "repl:none"
  endif
  if l:count > 1
    return l:name . ':' . l:count
  else
    return l:name
  end
endfunction

if has('nvim')
  let g:REPL_pattern = 'term:.\+#repl:.\+'
else
  let g:REPL_pattern = 'repl:.\+'
end

function s:REPLFindTerm(name)
  if has('nvim')
    for i in range(1,bufnr('$'))
      if bufname(i) =~ 'term:.*' . a:name . '$'
        return bufname(i)
      end
    endfor
    return ''
  else
    return a:name
  end
endfunction

function s:REPLFileType(name)
  return matchstr(a:name,'[^:]\+$')
endfunction

" show the terminal, creating it if necessary
function s:REPLShow(count,program,start_only)
  " hide any other visible REPLs
  let l:cur_window = win_getid()
  for i in range(1,bufnr('$'))
    if bufname(i) =~ g:REPL_pattern
      for w in win_findbuf(i)
        call win_gotoid(w)
        execute ":hide"
      endfor
    endif
  endfor
  call win_gotoid(l:cur_window)

  let l:dir = resolve(expand('%:p:h'))
  if has('nvim')
    let l:key = s:REPLName(a:count)
    let l:repl = s:REPLFindTerm(l:key)
    if empty(l:repl)
      execute ":" . g:repl_position . " new"
      execute ":resize " . g:repl_size
      set winfixheight

      let l:repl_id = termopen(a:program . ";#" . l:key,{"cwd": l:dir})
      let l:repl = bufname("%")
      call setbufvar(l:repl,'REPL_jobid',l:repl_id)
      call setbufvar(l:repl,'&buflisted',0)
    elseif a:start_only
      echoer "Cannot start, already running a REPL."
    else
      if empty(win_findbuf(bufnr(l:repl)))
        execute ":noautocmd " . g:repl_position . " split " . 
              \substitute(l:repl,'\#','\\#','g')
        execute ":noautocmd resize " . g:repl_size
        call setbufvar(bufnr(l:repl),'&buflisted',0)
      end
    end
  else
    let l:repl = s:REPLName(a:count)
    if bufnr(l:repl) == -1
      call term_start(a:program,{ 
            \ "cwd": l:dir,
            \ "hidden": 1,
            \ "norestore": 1,
            \ "term_name": l:repl,
            \ "term_kill":  "term",
            \ "term_finish": "close"
            \ })
    elseif a:start_only
      echoer "Cannot start, already running a REPL."
    end

    if empty(win_findbuf(bufnr(l:repl)))
      execute ":" . g:repl_position . " sb" . bufnr(l:repl)
      call setbufvar(bufnr(l:repl),'&buflisted',0)
    endif
    execute ":resize " . g:repl_size
    set winfixheight
  end

  return l:repl
endfunction

" switch to terminal (showing it if necessary) when not in a terminal,
" hide the terminal and return to the buffer that opeend the terminal
" if it's already the active window
function s:REPLToggle(...)
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
  " echom 'Count'  . l:count

  let l:use_shell = a:0 > 0 ? a:1 : 0
  let l:buf = bufname("%")
  if empty(matchstr(l:buf,g:REPL_pattern))
    let l:repl = s:REPLShow(l:count,l:program,l:custom_start)
    call win_gotoid(win_findbuf(bufnr(l:repl))[0])
    normal! a
    let b:opened_from = l:buf
  elseif !l:custom_start
    let l:gotowin = get(b:,'opened_from','')
    hide
    if !empty(l:gotowin)
      let l:windows = win_findbuf(bufnr(l:gotowin))
      if !empty(l:windows)
        call win_gotoid(l:windows[0])
      else
        " try to find a window with a buffer of the same filetype as that
        " supported by the repl 
        let l:filetype = s:REPLFileType(l:buf)
        for i in range(1,bufnr('$'))
          if getbufvar(i,'&filetype') ==# l:filetype
            let l:windows = win_findbuf(bufnr(l:gotowin))
            if !empty(l:windows)
              call win_gotoid(l:windows[0])
              break
            endif
          endif
        endfor
      endif
    endif
  endif
endfunction

function s:REPLSwitch()
  let l:num = nr2char(getchar())
  call s:REPLToggle(0)
  call s:REPLToggle(l:num)
endfunction
  

" send a line to the terminal (showing it if necessary)
function s:REPLSendText(text,count,...)
  let l:eventignore = &eventignore 
  let &eventignore = 'all'

  let l:buf = bufname("%")
  let l:mode = mode()
  let l:win = win_getid()
  let l:delay = get(b:,'repl_send_text_delay',g:repl_send_text_delay)

  let l:prefix = get(b:,'repl_send_prefix',g:repl_send_prefix)
  let l:suffix = get(b:,'repl_send_suffix',g:repl_send_suffix)
  if !empty(matchstr(l:buf,g:REPL_pattern))
    echoer "Tried to send text to REPL while already in the REPL."
  else
    " echom 'Count'  . a:count
    let l:repl = s:REPLShow(a:count,get(b:,'repl_program',g:repl_program),0)
    if has('nvim')
      let l:repl_id = getbufvar(l:repl,'&channel')
    end
    if a:0 > 0 && a:1 > 0
      if has('nvim')
        call chansend(l:repl_id,l:prefix)
      else
        call term_sendkeys(bufnr(l:repl),l:prefix)
      end
      if l:delay !=# '0m'
        execute 'sleep ' . l:delay
      end
    end

    if has('nvim')
      call chansend(l:repl_id,a:text . "\n")
    else
      call term_sendkeys(bufnr(l:repl),a:text . "\n")
    end

    if a:0 > 0 && a:1 > 0
      if has('nvim')
        call chansend(l:repl_id,l:suffix)
      else
        call term_sendkeys(bufnr(l:repl),l:suffix)
      end
      if l:delay !=# '0m'
        execute 'sleep ' . l:delay
      end
    end
  endif
  call win_gotoid(l:win)

  let &eventignore = l:eventignore
endfunction

function s:REPLCd(dir,count,global)
  if !a:global
    let l:prefix = get(b:,'repl_cd_prefix',g:repl_cd_prefix)
    let l:suffix = get(b:,'repl_cd_suffix',g:repl_cd_suffix)
  else
    let l:prefix = g:repl_cd_prefix
    let l:suffix = g:repl_cd_suffix
  end
  call s:REPLSendText(l:prefix . a:dir . l:suffix,a:count)
endfunction

function s:REPLRun(file,count,global)
  if !a:global
    let l:prefix = get(b:,'repl_run_prefix',g:repl_run_prefix)
    let l:suffix = get(b:,'repl_run_suffix',g:repl_run_suffix)
  else
    let l:prefix = g:repl_run_prefix
    let l:suffix = g:repl_run_suffix
  end
  call s:REPLSendText(l:prefix . a:file . l:suffix,a:count)
endfunction

function s:REPLSendTextOp(opfunc)
  if a:opfunc ==# 'line'
    let l:old_pos = getcurpos()
    let l:old_line = getcurpos()[1]
    normal! '[V']"ty']
    if l:old_line >= getcurpos()[1]
      :call setpos('.',l:old_pos)
    else
      normal! +
    end
  elseif a:opfunc ==# 'char'
    normal! `[hv`]"ty`]
  else
    return
  endif

  call s:REPLSendText(@t,g:REPL_count_holder,1)
endfunction

function s:REPLResize(size)
  let l:eventignore = &eventignore 
  let &eventignore = 'all'

  let l:curwin = win_getid()
  for i in range(1,bufnr('$'))
    if !empty(matchstr(bufname(i),g:REPL_pattern))
      for w in win_findbuf(i)
        call win_gotoid(w)
        execute ":resize " . a:size
      endfor
    endif
  endfor
  call win_gotoid(l:curwin)
  let &eventignore = l:eventignore 
endfunction

function s:REPLCloseAll()
  for i in range(1,bufnr('$'))
    if !empty(matchstr(bufname(i),g:REPL_pattern))
      execute ":bw! " . bufname(i)
    endif
  endfor
endfunction

function s:REPLListAll()
  for i in range(1,bufnr('$'))
    if !empty(matchstr(bufname(i),g:REPL_pattern))
      echom bufname(i)
    endif
  endfor
endfunction

command! -nargs=* -complete=shellcmd REPL :call <SID>REPLToggle(<f-args>)
command! -nargs=0 REPLCloseAll :call <SID>REPLCloseAll()
command! -nargs=0 REPLlist :call <SID>REPLListAll()
nnoremap <silent><Plug>(repl-send-motion) :<C-u>let g:REPL_count_holder=v:count<cr>
      \:set operatorfunc=<SID>REPLSendTextOp<cr>g@
nnoremap <silent><Plug>(repl-send-text) 
      \:<C-u>let g:REPL_count_holder=v:count<cr>
      \"tyy:<C-u>call <SID>REPLSendText(@t,g:REPL_count_holder,1)<cr>+
vnoremap <silent><Plug>(repl-send-text) :<C-u>let g:REPL_count_holder=v:count<cr>
      \gvmr"ty:call <SID>REPLSendText(@t,g:REPL_count_holder,1)<cr>`r
nnoremap <silent><Plug>(repl-toggle) :<C-u>call <SID>REPLToggle(v:count)<cr>
nnoremap <silent><Plug>(repl-cd) 
      \ :<C-u>call <SID>REPLCd(expand('%:p:h'),v:count,0)<cr>
nnoremap <silent><Plug>(repl-global-cd) 
      \ :<C-u>call <SID>REPLCd(expand('%:p:h'),v:count,1)<cr>
nnoremap <silent><Plug>(repl-run) 
      \ :<C-u>call <SID>REPLRun(resolve(expand('%:p')),v:count,0)<cr>
nnoremap <silent><Plug>(repl-resize) 
      \ :<C-u>call <SID>REPLResize(v:count > 0 ? v:count : g:repl_size)<cr>

if has('nvim')
  tnoremap <silent><Plug>(repl-toggle) <C-\><C-n>:call <SID>REPLToggle(0)<cr>
  tnoremap <silent><Plug>(repl-switch) <C-\><C-n>:call <SID>REPLSwitch()<cr>a
  tnoremap <silent><Plug>(repl-resize) <C-\><C-n>:call <SID>REPLResize(g:repl_size)<cr>a
else
  tnoremap <silent><Plug>(repl-toggle) <C-w>:call <SID>REPLToggle(0)<cr>
  tnoremap <silent><Plug>(repl-switch) <C-w>:call <SID>REPLSwitch()<cr>
  tnoremap <silent><Plug>(repl-resize) <C-w>:call <SID>REPLResize(g:repl_size)<cr>
end

if g:repl_default_mappings == 1
  nmap <C-w>' <Plug>(repl-toggle)
  vmap <C-w>' <Plug>(repl-toggle)
  tmap <C-w>' <Plug>(repl-toggle)

  nmap <Leader>= <Plug>(repl-resize)
  vmap <Leader>= <Plug>(repl-resize)
  tmap <C-w>= <Plug>(repl-resize)

  nmap <Leader>. <Plug>(repl-send-motion)
  vmap <silent><Leader>. <Plug>(repl-send-text)
  nmap <Leader>; <Plug>(repl-send-text)

  nmap <Leader>r <Plug>(repl-run)
  vmap <Leader>r <Plug>(repl-run)

  nmap <Leader>cd <Plug>(repl-cd)
  vmap <Leader>cd <Plug>(repl-cd)

  nmap <Leader>gcd <Plug>(repl-global-cd)
  vmap <Leader>gcd <Plug>(repl-global-cd)

  tmap <C-w>g <Plug>(repl-switch)
  if has('nvim')
    tmap <silent> <C-w><C-u> <C-\><C-n><C-u>:set nonumber<cr>
  else
    tmap <C-w><C-u> <C-w>N<C-u>:set nonumber<cr>
  end
end

""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" language specific config
augroup REPLConfiguration
  au!
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
augroup END
