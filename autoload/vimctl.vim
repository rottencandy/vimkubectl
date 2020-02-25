if !exists('g:vimctl_command')
  let g:vimctl_command = 'kubectl'
endif

" Edit mode functions
" ------------------------------------------------------------------------

fun! s:getManifest(resource) abort
  return systemlist(g:vimctl_command . ' get ' . a:resource . ' -o yaml --request-timeout=5s')
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
  silent! execute '%d'
  call setline('.', a:resourceManifest)
  setlocal nomodified
endfun


fun! s:editResource(pos) abort
  let s:currentResourceName = s:resourcesList[a:pos - 1]
  let manifest = s:getManifest(s:currentResourceName)
  setlocal modifiable
  call s:setupEditBuffer()
  call s:fillEditBuffer(l:manifest)
endfun

" Watch mode functions
" ------------------------------------------------------------------------

let s:currentResource = ''
let s:resourcesList = []

fun! s:setupViewBuffer() abort
  let existing = bufwinnr('__KUBERNETES__')
  if l:existing ==# -1
    silent! split __KUBERNETES__
    setlocal buftype=nofile
    setlocal bufhidden=wipe
    setlocal ft=kubernetes
    nnoremap <silent><buffer> i :call <SID>editResource(getpos('.')[1])<CR>
    nnoremap <silent><buffer> gr :call <SID>updateViewBuffer()<CR>
  else
    silent! execute l:existing . 'wincmd w'
  endif
endfun

fun! s:redrawViewBuffer() abort
  setlocal modifiable
  silent! execute '%d'
  call setline('.', s:resourcesList)
  setlocal nomodifiable
endfun

fun! s:updateResourcesList() abort
  echo 'Fetching resources...'
  silent let newResources = systemlist(g:vimctl_command . ' get ' . s:currentResource . ' -o name --request-timeout=5s')
  redraw!
  if v:shell_error != 0
    echohl WarningMsg | echom 'Error: ' . join(l:newResources, "\n") | echohl None
    return
  endif
  let s:resourcesList = l:newResources
endfun

fun! s:updateViewBuffer() abort
  call s:updateResourcesList()
  if v:shell_error ==# 0
    call s:redrawViewBuffer()
  endif
endfun


fun! vimctl#getResource(res='pods') abort
  let s:currentResource = a:res
  call s:updateResourcesList()
  if v:shell_error !=# 0
    return
  endif
  call s:setupViewBuffer()
  call s:redrawViewBuffer()
endfun


fun! vimctl#completionList(A, L, P)
  let availableResources = system(g:vimctl_command . ' api-resources -o name --cached --request-timeout=5s --verbs=get')
  if v:shell_error !=# 0
    return ''
  endif
  return availableResources
endfun

" vim: ts:et:sw=2:sts=2:
