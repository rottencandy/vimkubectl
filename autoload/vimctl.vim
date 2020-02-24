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


let s:currentResourceManifest = []

fun! s:applyManifest() abort
  silent let return = systemlist(g:vimctl_command . ' apply -f -', s:currentResourceManifest)
  if v:shell_error ==# 0
    echom join(l:return)
  else
    echohl WarningMsg | echom 'Error: ' . join(l:return) | echohl None
  endif
endfun


fun! s:loadEditBuffer(resourceName, resourceManifest) abort
  silent! execute 'edit __' . a:resourceName
  setlocal buftype=nofile
  setlocal bufhidden=wipe
  setlocal ft=yaml
  let s:currentResourceManifest = a:resourceManifest

  let failed = append(0, split(a:resourceManifest, "\n"))
  silent! normal! ddgg
  command! -buffer -bar -bang -nargs=0 KApply :call <SID>applyManifest()
  cnoreabbrev <buffer> w KApply
endfun


fun! s:editResource(pos) abort
  let resourceName = s:resources[a:pos - 1]
  let manifest = system(g:vimctl_command . ' get ' . l:resourceName . ' -o yaml')
  call <SID>loadEditBuffer(l:resourceName, l:manifest)
endfun


let s:resources = []
fun! vimctl#getResource(res='pods') abort
  echo 'Fetching resources... (Ctrl-C to cancel)'
  silent let s:resources = systemlist(g:vimctl_command . ' get ' . a:res . ' -o name')
  redraw!

  if v:shell_error !=# 0
    echohl WarningMsg | echo 'Error: ' . join(s:resources) | echohl None
    let s:resources = []
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
