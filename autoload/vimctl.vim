if !exists('g:vimctl_command')
  let g:vimctl_command = 'kubectl'
endif


fun! s:loadViewBuffer() abort
  let existing = bufwinnr('__KUBERNETES__')

  if l:existing ==# -1
    silent! split __KUBERNETES__
    setlocal buftype=nofile
    setlocal bufhidden=wipe
    setlocal ft=kubernetes
    nnoremap <silent><buffer> i :call <SID>editResource(getpos('.')[1])<CR>
  else
    silent! execute l:existing . 'wincmd w'
  endif
endfun


fun! s:loadEditBuffer(resourceName) abort
  silent! execute 'edit __' . a:resourceName
  setlocal buftype=nofile
  setlocal bufhidden=wipe
  setlocal ft=yaml
endfun


fun! s:editResource(pos) abort
  let resourceName = s:resources[a:pos - 1]
  let manifest = system(g:vimctl_command . ' get ' . l:resourceName . ' -o yaml')
  call <SID>loadEditBuffer(l:resourceName)
  let failed = append(0, split(l:manifest, "\n"))
  silent! normal! ddgg
endfun


let s:resources = []
fun! vimctl#getResource(res='pods') abort
  echo 'Fetching resources... (Ctrl-C to cancel)'
  silent let s:resources = systemlist(g:vimctl_command . ' get ' . a:res . ' -o name')
  redraw!

  if v:shell_error !=# 0
    let s:resources = []
    echohl WarningMsg | echo join(s:resources) | echohl None
    return
  endif

  call <SID>loadViewBuffer()
  let failed = append(0, s:resources)
  silent! normal! ddgg
endfun


fun! vimctl#completionList(A, L, P)
  " TODO: Get resource list
  return []
endfun
