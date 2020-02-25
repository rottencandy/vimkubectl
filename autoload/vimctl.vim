if !exists('g:vimctl_command')
  let g:vimctl_command = 'kubectl'
endif


fun! s:applyManifest() abort
  echo 'Applying resource...'
  let manifest = getline('1', '$')
  silent let return = systemlist(g:vimctl_command . ' apply -f -', l:manifest)
  if v:shell_error ==# 0
    echom join(l:return)
    setlocal nomodified
  else
    echohl WarningMsg | echom 'Error: ' . join(l:return) | echohl None
  endif
endfun


fun! s:setupEditBuffer(resourceName) abort
  silent! execute 'edit __' . a:resourceName
  setlocal buftype=acwrite
  setlocal bufhidden=wipe
  setlocal ft=yaml
  autocmd BufWriteCmd <buffer> call <SID>applyManifest()
endfun

fun! s:fillEditBuffer(resourceManifest) abort
  silent! normal ggdG
  call setline('.', a:resourceManifest)
  setlocal nomodified
endfun


fun! s:editResource(pos) abort
  let resourceName = s:view_resources[a:pos - 1]
  let manifest = systemlist(g:vimctl_command . ' get ' . l:resourceName . ' -o yaml')
  setlocal modifiable
  call s:setupEditBuffer(l:resourceName)
  call s:fillEditBuffer(l:manifest)
endfun


fun! s:setupViewBuffer() abort
  let existing = bufwinnr('__KUBERNETES__')
  if l:existing ==# -1
    silent! split __KUBERNETES__
    setlocal buftype=nofile
    setlocal bufhidden=wipe
    setlocal ft=kubernetes
  else
    silent! execute l:existing . 'wincmd w'
  endif
endfun

fun! s:fillViewBuffer() abort
  silent! normal! ggdG
  call setline('.', s:view_resources)
  setlocal nomodifiable
  nnoremap <silent><buffer> i :call <SID>editResource(getpos('.')[1])<CR>
endfun


let s:view_resources = []

fun! vimctl#getResource(res='pods') abort
  echo 'Fetching resources... (Ctrl-C to cancel)'
  silent let s:view_resources = systemlist(g:vimctl_command . ' get ' . a:res . ' -o name')
  redraw!

  if v:shell_error !=# 0
    echohl WarningMsg | echom 'Error: ' . join(s:view_resources) | echohl None
    let s:view_resources = []
    return
  endif

  call s:setupViewBuffer()
  call s:fillViewBuffer()
endfun


fun! vimctl#completionList(A, L, P)
  " TODO: Get resource list
  return []
endfun

" vim: set ts et sw=2
