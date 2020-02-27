" Copyright (c) 2020 Mohammed Saud
"
" MIT License
"
" Permission is hereby granted, free of charge, to any person obtaining
" a copy of this software and associated documentation files (the
" "Software""), to deal in the Software without restriction, including
" without limitation the rights to use, copy, modify, merge, publish,
" distribute, sublicense, and/or sell copies of the Software, and to
" permit persons to whom the Software is furnished to do so, subject to
" the following conditions:
"
" The above copyright notice and this permission notice shall be
" included in all copies or substantial portions of the Software.
"
" THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
" EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
" MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
" NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
" LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
" OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
" WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE."


if !exists('g:vimctl_command')
  let g:vimctl_command = 'kubectl'
endif


" Edit mode functions
" ------------------------------------------------------------------------

let s:currentResourceName = ''

fun! s:applyManifest() abort
  echo 'Applying resource...'
  let manifest = getline('1', '$')
  silent let result = systemlist(g:vimctl_command . ' apply -n ' . s:currentNamespce . ' -f -', l:manifest)
  if v:shell_error ==# 0
    echom join(l:result, "\n")
    call s:updateEditBuffer()
  else
    echohl WarningMsg | echom 'Error: ' . join(l:result, "\n") | echohl None
  endif
endfun

fun! s:saveToFile(name='') abort
  let fileName = a:name
  if a:name ==# ''
    let l:fileName = substitute(s:currentResourceName, '\v\/', '_', '') . '.yaml'
  endif
  let manifest = getline('1', '$')
  call writefile(l:manifest, l:fileName)
  echom 'Saved to ' . l:fileName
endfun

fun! s:setupEditBuffer(bufType) abort
  silent! execute a:bufType . ' __' . s:currentResourceName
  setlocal buftype=acwrite
  setlocal bufhidden=wipe
  setlocal ft=yaml
  autocmd BufWriteCmd <buffer> call <SID>applyManifest()
  nnoremap <silent><buffer> gr :call <SID>updateEditBuffer()<CR>
  command -buffer -bar -bang -nargs=? KSave :call <SID>saveToFile(<f-args>)
endfun

fun! s:redrawEditBuffer(resourceManifest) abort
  silent! execute '%d'
  call setline('.', a:resourceManifest)
  setlocal nomodified
endfun

fun! s:updateEditBuffer() abort
  let updatedManifest = s:fetchManifest(s:currentResourceName)
  if v:shell_error ==# 0
    call s:redrawEditBuffer(updatedManifest)
    echom 'Updated manifest'
  endif
endfun

fun! s:resourceUnderCursor() abort
  let resource = getline('.')
  if len(l:resource)
    return l:resource
  endif
  return ''
endfun

fun! s:fetchManifest(resource) abort
  let manifest = systemlist(g:vimctl_command . ' get ' . a:resource . ' -o yaml --request-timeout=5s -n ' . s:currentNamespace)
  if v:shell_error !=# 0
    echohl WarningMsg | echom 'Error: ' . join(l:manifest, "\n") | echohl None
    return
  endif
  return l:manifest
endfun

fun! s:editResource(openAs='edit') abort
  let resource = s:resourceUnderCursor()
  if len(l:resource)
    let manifest = s:fetchManifest(l:resource)
    if v:shell_error ==# 0
      let s:currentResourceName = l:resource
      setlocal modifiable
      call s:setupEditBuffer(a:openAs)
      call s:redrawEditBuffer(l:manifest)
    endif
  endif
endfun

fun! s:deleteResource() abort
  let resource = s:resourceUnderCursor()
  if len(l:resource)
    let choice = confirm('Are you sure you want to delete ' . l:resource . ' ?', "&Yes\n&No")
    if l:choice ==# 1
      let result = systemlist(g:vimctl_command . ' delete ' . l:resource . ' -n ' . s:currentNamespace)
      if v:shell_error !=# 0
        echohl WarningMsg | echom 'Error: ' . join(l:result, "\n") | echohl None
      else
        call s:updateViewBuffer()
        echom join(l:result, "\n")
      endif
    endif
  endif
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
    nnoremap <silent><buffer> ii :call <SID>editResource()<CR>
    nnoremap <silent><buffer> is :call <SID>editResource('sp')<CR>
    nnoremap <silent><buffer> iv :call <SID>editResource('vs')<CR>
    nnoremap <silent><buffer> it :call <SID>editResource('tabe')<CR>
    nnoremap <silent><buffer> dd :call <SID>deleteResource()<CR>
    nnoremap <silent><buffer> gr :call <SID>updateViewBuffer()<CR>
  else
    silent! execute l:existing . 'wincmd w'
  endif
endfun

fun! s:redrawViewBuffer() abort
  call s:setupViewBuffer()
  setlocal modifiable
  silent! execute '%d'
  call setline('.', s:resourcesList)
  setlocal nomodifiable
endfun

fun! s:updateResourcesList() abort
  echo 'Fetching resources...'
  silent let newResources = systemlist(g:vimctl_command . ' get ' . s:currentResource . ' -o name --request-timeout=5s -n ' . s:currentNamespace)
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
  if s:currentNamespace ==# ''
    call s:fetchCurrentNamespace()
  endif
  let s:currentResource = a:res
  call s:updateResourcesList()
  if v:shell_error !=# 0
    return
  endif
  call s:setupViewBuffer()
  call s:redrawViewBuffer()
endfun

let s:currentNamespace = ''

fun! s:fetchCurrentNamespace() abort
  let namespace = system(g:vimctl_command . ' config view --minify -o ''jsonpath={..namespace}'' --request-timeout=5s')
  if v:shell_error !=# 0
    echohl WarningMsg | echom 'Error: ' . l:namespace | echohl None
    return
  endif
  let s:currentNamespace = l:namespace
endfun

fun! vimctl#switchNamespace(name='') abort
  if a:name ==# ''
    if s:currentNamespace ==# ''
      call s:fetchCurrentNamespace()
    endif
  else
    let s:currentNamespace = a:name
    if bufwinnr('__KUBERNETES__') !=# -1
      call s:updateViewBuffer()
    endif
  endif
  echom 'Using namespace: ' . s:currentNamespace
endfun

" Custom command completion functions
" ------------------------------------------------------------------------

fun! vimctl#allNamespaces(A, L, P)
  let namespaces = system(g:vimctl_command . ' get ns -o name --request-timeout=5s | awk -F "/" ''{print $2}''')
  if v:shell_error !=# 0
    return ''
  endif
  return l:namespaces
endfun

fun! vimctl#allResources(A, L, P)
  let availableResources = system(g:vimctl_command . ' api-resources -o name --cached --request-timeout=5s --verbs=get | awk -F "." ''{print $1}''')
  if v:shell_error !=# 0
    return ''
  endif
  return availableResources
endfun

" vim: ts:et:sw=2:sts=2:
