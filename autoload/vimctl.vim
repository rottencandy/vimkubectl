if !exists('g:vimctl_command')
  let g:vimctl_command = 'kubectl'
endif


fun! s:getManifest(resource) abort
  return systemlist(g:vimctl_command . ' get ' . a:resource . ' -o yaml')
endfun


let s:currentResourceName = ''

fun! s:applyManifest() abort
  echo 'Applying resource...'
  let manifest = getline('1', '$')
  silent let return = systemlist(g:vimctl_command . ' apply -f -', l:manifest)

  if v:shell_error ==# 0
    setlocal nomodified
    let updatedManifest = s:getManifest(s:currentResourceName)
    echom join(l:return, "\n")
  call s:fillEditBuffer(l:updatedManifest)
  else
    echohl WarningMsg | echom 'Error: ' . join(l:return, "\n") | echohl None
  endif
endfun


fun! s:setupEditBuffer() abort
  silent! execute 'edit __' . s:currentResourceName
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
  let s:currentResourceName = s:viewResourcesList[a:pos - 1]
  let manifest = s:getManifest(s:currentResourceName)
  setlocal modifiable
  call s:setupEditBuffer()
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
  call setline('.', s:viewResourcesList)
  setlocal nomodifiable
  nnoremap <silent><buffer> i :call <SID>editResource(getpos('.')[1])<CR>
endfun


let s:viewResourcesList = []

fun! vimctl#getResource(res='pods') abort
  echo 'Fetching resources... (Ctrl-C to cancel)'
  silent let s:viewResourcesList = systemlist(g:vimctl_command . ' get ' . a:res . ' -o name')
  redraw!

  if v:shell_error !=# 0
    echohl WarningMsg | echom 'Error: ' . join(s:viewResourcesList, "\n") | echohl None
    let s:viewResourcesList = []
    return
  endif

  call s:setupViewBuffer()
  call s:fillViewBuffer()
endfun


fun! vimctl#completionList(A, L, P)
  let availableResources = system(g:vimctl_command . ' api-resources -o name --cached --request-timeout=5s --verbs=get')
  if v:shell_error ==# 0
    return availableResources
  return ''
endfun

" vim: set ts et sw=2
