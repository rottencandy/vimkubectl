fun! s:loadViewBuffer() abort
  let existing = bufwinnr('__KUBERNETES__')

  if l:existing ==# -1
    silent split __KUBERNETES__
    setlocal buftype=nofile
    setlocal bufhidden=wipe
    setlocal ft=kubernetes
    nnoremap <buffer> i <NOP>
  else
    silent execute l:existing . 'wincmd w'
  endif
endfun


fun! vimctl#getResource(res='pods') abort
  echo 'Fetching resources... (Ctrl-C to cancel)'
  silent let resource = systemlist('kubectl get ' . a:res)

  if v:shell_error !=# 0
    echohl WarningMsg | echo join(l:resource) | echohl None
    return
  endif

  call <SID>loadViewBuffer()
  silent normal! ggdG
  let failed = append(0, join(l:resource))
endfun
