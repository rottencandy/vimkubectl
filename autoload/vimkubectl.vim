" Copyright (c) Mohammed Saud
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


if !exists('g:vimkubectl_command')
  let g:vimkubectl_command = 'kubectl'
endif

if !exists('g:vimkubectl_timeout')
  let g:vimkubectl_timeout = 5
endif


fun! s:printWarning(message) abort
  echohl WarningMsg | echom 'Error: ' . a:message | echohl None
endfun
" Edit mode functions
" ------------------------------------------------------------------------

let s:currentResourceName = ''

fun! vimkubectl#applyBuffer(updateBuffer) range abort
  echo 'Applying resource...'
  call s:verifyNamespace()
  let manifest = getline(a:firstline, a:lastline)
  silent let result = systemlist(g:vimkubectl_command . ' apply -n ' . s:currentNamespace . ' -f -', l:manifest)
  if v:shell_error ==# 0
    echom join(l:result, "\n")
    if a:updateBuffer
      echo 'Successful. Updating manifest...'
      call s:updateEditBuffer()
    endif
  else
    call s:printWarning(join(l:result, "\n"))
  endif
endfun

fun! s:saveToFile(name) abort
  let fileName = a:name
  if !len(a:name)
    let l:fileName = substitute(s:currentResourceName, '\v\/', '_', '') . '.yaml'
  endif
  let manifest = getline('1', '$')
  call writefile(l:manifest, l:fileName)
  echom 'Saved to ' . l:fileName
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

fun! s:setupEditBuffer(bufType) abort
  silent! execute a:bufType . ' __' . s:currentResourceName
  setlocal buftype=acwrite
  setlocal bufhidden=wipe
  setlocal ft=yaml
  autocmd BufWriteCmd <buffer> 1,$call vimkubectl#applyBuffer(1)
  nnoremap <silent><buffer> gr :call <SID>updateEditBuffer()<CR>
  command -buffer -bar -bang -nargs=? Ksave :call <SID>saveToFile(<q-args>)
endfun

fun! s:resourceUnderCursor() abort
  if getpos('.')[1] <=# 3
    return ''
  endif
  let resource = split(getline('.'))
  if len(l:resource)
    return l:resource[0]
  endif
  return ''
endfun

fun! s:fetchManifest(resource) abort
  let manifest = systemlist(g:vimkubectl_command . ' get ' . a:resource . ' -o yaml --request-timeout=' . g:vimkubectl_timeout . 's -n ' . s:currentNamespace)
  if v:shell_error !=# 0
    call s:printWarning(join(l:manifest, "\n"))
    return
  endif
  return l:manifest
endfun

fun! s:editResource(openAs) abort
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
      let result = systemlist(g:vimkubectl_command . ' delete ' . l:resource . ' -n ' . s:currentNamespace)
      if v:shell_error !=# 0
        call s:printWarning(join(l:result, "\n"))
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
    nnoremap <silent><buffer> ii :call <SID>editResource('edit')<CR>
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
  let details = ['Namespace: ' . s:currentNamespace, 'Resource: ' . s:currentResource, '']
  call append(0, l:details)
  call setline('.', s:resourcesList)
  setlocal nomodifiable
endfun

fun! s:updateResourcesList() abort
  echo 'Fetching resources...'
  silent let newResources = systemlist(g:vimkubectl_command . ' get ' . s:currentResource . ' -o name --request-timeout=' . g:vimkubectl_timeout . 's -n ' . s:currentNamespace)
  echon "\r\r"
  echon ''
  if v:shell_error != 0
    call s:printWarning(join(l:newResources, "\n"))
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


fun! vimkubectl#getResource(res) abort
  call s:verifyNamespace()
  let s:currentResource = len(a:res) ? a:res : 'pods'
  call s:updateResourcesList()
  if v:shell_error !=# 0
    return
  endif
  call s:setupViewBuffer()
  call s:redrawViewBuffer()
endfun

let s:currentNamespace = ''

fun! s:fetchCurrentNamespace() abort
  let namespace = system(g:vimkubectl_command . ' config view --minify -o ''jsonpath={..namespace}'' --request-timeout=' . g:vimkubectl_timeout . 's')
  if v:shell_error !=# 0
    call s:printWarning('Error: ' . l:namespace)
    return
  endif
  let s:currentNamespace = l:namespace
endfun

fun! s:verifyNamespace() abort
  if !len(s:currentNamespace)
    call s:fetchCurrentNamespace()
  endif
endfun

fun! vimkubectl#switchNamespace(name) abort
  if !len(a:name)
    call s:verifyNamespace()
  else
    let s:currentNamespace = a:name
    if bufwinnr('__KUBERNETES__') !=# -1
      call s:updateViewBuffer()
    endif
  endif
  echom 'Using namespace: ' . s:currentNamespace
endfun

fun! vimkubectl#editResourceObject(resource) abort
  let manifest = s:fetchManifest(a:resource)
  if v:shell_error ==# 0
    let s:currentResourceName = join(split(a:resource), '/')
    call s:setupEditBuffer('split')
    call s:redrawEditBuffer(l:manifest)
  endif
endfun

" Custom command completion functions
" ------------------------------------------------------------------------

fun! vimkubectl#allNamespaces(A, L, P)
  " Command separated to allow clean detection of exit code
  let namespaces = system(g:vimkubectl_command . ' get ns -o custom-columns=":metadata.name" --request-timeout=' . g:vimkubectl_timeout . 's')
  if v:shell_error !=# 0
    return ''
  endif
  return l:namespaces
endfun

fun! vimkubectl#allResources(A, L, P)
  let availableResources = system(g:vimkubectl_command . ' api-resources -o name --cached --request-timeout=' . g:vimkubectl_timeout . 's --verbs=get | awk -F "." ''{print $1}''')
  if v:shell_error !=# 0
    return ''
  endif
  return l:availableResources
endfun

function! vimkubectl#allResourcesAndObjects(arg, line, pos)
  call s:verifyNamespace()
  let arguments = split(a:line, '\s\+')
  if len(arguments) > 2 || len(arguments) > 1 && a:arg=~ '^\s*$'
    let objectList = system(g:vimkubectl_command . ' get ' . arguments[1] . ' -o custom-columns=":metadata.name" --request-timeout=' . g:vimkubectl_timeout . 's -n ' . s:currentNamespace)
  else
    let objectList = vimkubectl#allResources('', '', '')
  endif
  if v:shell_error !=# 0
    return ''
  endif
  return l:objectList
endfunction

" vim: ts:et:sw=2:sts=2:
