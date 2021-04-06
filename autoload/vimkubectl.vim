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


" K8S UTILS
" ---------

" Create command using g:vimkubectl_command
fun! s:craftCommand(command, namespace) abort
  if !exists('g:vimkubectl_command') || !exists('g:vimkubectl_timeout')
    call s:printWarning('Configuration options not specified.')
    return
  endif
  let specifyNamespace = len(a:namespace) ? '-n ' . a:namespace : ''
  return g:vimkubectl_command . ' ' . a:command . ' ' . l:specifyNamespace . ' --request-timeout=' . g:vimkubectl_timeout . 's'
endfun

" Fetch list of `resourceType` resources
fun! s:fetchResourceList(resourceType, namespace) abort
  return systemlist(s:craftCommand('get ' . a:resourceType . ' -o name', a:namespace))
endfun

" Fetch manifest of resource
fun! s:fetchResourceManifest(resourceType, resource, namespace) abort
  return systemlist(s:craftCommand('get ' . a:resourceType . ' ' . a:resource . ' -o yaml', a:namespace))
endfun

" Delete resource
fun! s:deleteResource(resourceType, resource, namespace) abort
  return system(s:craftCommand('delete ' . a:resourceType . ' ' . a:resource, a:namespace))
endfun

" Apply string
fun! s:applyString(stringData, namespace) abort
  return system(s:craftCommand('apply -f -', a:namespace), a:stringData)
endfun

" Get currently active namespace context
" (Taken from kubectl's bash_completion file)
fun! s:fetchActiveNamespace() abort
  return system(s:craftCommand('config view --minify -o ''jsonpath={..namespace}''', ''))
endfun


" UTILS
" -----

" Clear all undo history
" Source: https://vi.stackexchange.com/a/16915/22360
fun! s:resetUndo() abort
  let old_undo = &undolevels
  set undolevels=-1
  silent! exec "normal a \<BS>\<Esc>"
  let &undolevels = old_undo
endfun

" TODO: find a way to store namespace state somewhere else
let s:currentNamespace = ''

fun! s:getActiveNamespace() abort
  if !len(s:currentNamespace)
    let s:currentNamespace = s:fetchActiveNamespace()
  endif
  return s:currentNamespace
endfun

fun! s:setActiveNamespace(namespace) abort
  let s:currentNamespace = a:namespace
endfun

" Print a message with warning highlight
fun! s:printWarning(message) abort
  echohl WarningMsg | echom '[Vimkubectl] Error: ' . a:message | echohl None
endfun

" Apply the contents of the active buffer,
fun! s:applyActiveBuffer(startLine, endLine) abort
  let manifest = getline(a:startLine, a:endLine)
  return s:applyString(l:manifest, s:getActiveNamespace())
endfun

" TODO: Figure out better way to create namespaces
" Namespace for functions that are intended to be run from edit buffers
" let s:editBuffer = {}

" Save buffer file contents to local file
fun! s:editBuffer_saveToFile(name) abort
  let fileName = a:name
  if !len(a:name)
    let l:fileName = substitute(expand('%'), '\v\/', '_', '') . '.yaml'
  endif
  let manifest = getline('1', '$')
  call writefile(l:manifest, l:fileName)
  echom 'Saved to ' . l:fileName
endfun

" Fetch the manifest of the resource and fill up the buffer,
" after discarding any existing content
fun! s:editBuffer_refreshEditBuffer() abort
  let fullResource = trim(expand('%'), 'kube://', 1)
  let resource = split(l:fullResource, '/')

  echo 'Fetching manifest...'
  let updatedManifest = s:fetchResourceManifest(l:resource[0], l:resource[1], s:getActiveNamespace())
  echon "\r\r"
  echon ''
  if v:shell_error !=# 0
    call s:printWarning(join(l:updatedManifest, "\n"))
    return
  endif
  silent! execute '%d'
  call setline('.', l:updatedManifest)
  call s:resetUndo()
  setlocal nomodified
endfun

" Apply the buffer contents
fun! s:editBuffer_applyBuffer() range abort
  echo 'Applying resource...'
  silent let result = s:applyActiveBuffer(a:firstline, a:lastline)
  if v:shell_error !=# 0
    call s:printWarning(l:result)
    return
  endif
  echom l:result
  echo 'Successful. Updating manifest...'
  call s:editBuffer_refreshEditBuffer()
  echom 'Updated manifest'
endfun

" Configure current buffer with appropriate options and default mappings for edit
fun! s:editBuffer_prepareBuffer() abort
  setlocal buftype=acwrite
  setlocal bufhidden=delete
  setlocal filetype=yaml
  setlocal noswapfile

  nnoremap <silent><buffer> gr :call <SID>editBuffer_refreshEditBuffer()<CR>
  command! -buffer -bar -bang -nargs=? Ksave :call <SID>editBuffer_saveToFile(<q-args>)

  augroup vimkubectl_internal_editBufferOnSave
    autocmd! *
    autocmd BufWriteCmd <buffer> 1,$call <SID>editBuffer_applyBuffer()
  augroup END
endfun

" Create or switch to edit buffer(kube://{resourceType}/{resourceName})
fun! s:openEditBuffer(openMethod, resourceType, resourceName) abort
  let existing = bufwinnr('^kube://' . a:resourceType . '/' . a:resourceName . '$')
  if l:existing ==# -1
    " TODO verify if openMethod is correct
    " TODO warn before redrawing with unsaved changes
    silent! exec a:openMethod . ' kube://' . a:resourceType . '/' . a:resourceName
  else
    silent! execute l:existing . 'wincmd w'
    " refresh needs to be done explicitly because buffer override will not
    " happen to exising buffers (due to BufReadCmd)
    call s:editBuffer_refreshEditBuffer()
  endif
endfun

" Namespace for functions that are intended to be run from view buffers
"let s:viewBuffer = {}

" Get the resource under cursor line,
" If cursor is on header, or blank space, return ''
" TODO: range support
fun! s:viewBuffer_resourceUnderCursor() abort
  let headerLength = len(s:viewBuffer_headerText('', ''))
  if getpos('.')[1] <=# l:headerLength
    return ''
  endif
  let resource = split(getline('.'))
  if len(l:resource)
    return l:resource[0]
  endif
  return ''
endfun

" Open edit buffer for resource under cursor,
" `opemMethod` can be one of [edit, sp, vs, tabe]
fun! s:viewBuffer_editResource(openMethod) abort
  let fullResource = s:viewBuffer_resourceUnderCursor()
  if !len(l:fullResource)
    return
  endif

  let resource = split(l:fullResource, '/')
  call s:openEditBuffer(a:openMethod, l:resource[0], l:resource[1])
endfun

" Delete the resource under cursor, after confirmation prompt
fun! s:viewBuffer_deleteResource() abort
  let fullResource = s:viewBuffer_resourceUnderCursor()
  let resource = split(l:fullResource, '/')
  if len(l:resource) !=# 2
    return
  endif

  let choice = confirm('Are you sure you want to delete ' . l:resource[1] . ' ?', "&Yes\n&No")
  if l:choice !=# 1
    return
  endif

  echo 'Deleting...'
  let result = s:deleteResource(l:resource[0], l:resource[1], s:getActiveNamespace())
  if v:shell_error !=# 0
    call s:printWarning(l:result)
  else
    call s:viewBuffer_refreshViewBuffer()
    echom l:result
  endif
endfun

" Create header text to be shown at the top of the buffer
fun! s:viewBuffer_headerText(namespace, resource) abort
  return [
        \ 'Namespace: ' . a:namespace,
        \ 'Resource: ' . a:resource,
        \ '',
        \ ]
endfun

" Fetch the resources related to buffer and fill it up,
" after discarding any existing content
fun! s:viewBuffer_refreshViewBuffer() abort
  let resourceType = trim(expand('%'), 'kube://', 1)
  let namespace = s:getActiveNamespace()

  echo 'Fetching resources...'
  let resourceList = s:fetchResourceList(l:resourceType, l:namespace)
  echon "\r\r"
  echon ''
  if v:shell_error != 0
    call s:printWarning(join(l:resourceList, "\n"))
    " TODO: close buffer if already empty
    return
  endif

  setlocal modifiable
  silent! execute '%d'
  call append(0, s:viewBuffer_headerText(l:namespace, l:resourceType))
  call setline('.', l:resourceList)
  call s:resetUndo()
  setlocal nomodifiable
endfun

" Configure current buffer with appropriate options and default mappings for view
fun! s:viewBuffer_prepareBuffer() abort
  setlocal buftype=nowrite
  setlocal bufhidden=delete
  setlocal filetype=kubernetes
  setlocal noswapfile

  nnoremap <silent><buffer> ii :call <SID>viewBuffer_editResource('edit')<CR>
  nnoremap <silent><buffer> is :call <SID>viewBuffer_editResource('sp')<CR>
  nnoremap <silent><buffer> iv :call <SID>viewBuffer_editResource('vs')<CR>
  nnoremap <silent><buffer> it :call <SID>viewBuffer_editResource('tabe')<CR>
  nnoremap <silent><buffer> dd :call <SID>viewBuffer_deleteResource()<CR>
  nnoremap <silent><buffer> gr :call <SID>viewBuffer_refreshViewBuffer()<CR>
endfun

" Create or switch to view buffer(kube://{resourceType})
fun! s:openViewBuffer(resourceType) abort
  let existing = bufwinnr('^kube://' . a:resourceType . '$')
  if l:existing ==# -1
    silent! exec 'split kube://' . a:resourceType
  else
    silent! execute l:existing . 'wincmd w'
    " refresh needs to be done explicitly because buffer override will not
    " happen to exising buffers (due to BufReadCmd)
    call s:viewBuffer_refreshViewBuffer()
  endif
  return winnr()
endfun


" COMMAND FUNCTIONS
" -----------------

" :Knamespace
" If `name` is provided, switch to using it as active namespace.
" Else print currently active namespace.
fun! vimkubectl#switchOrShowNamespace(name) abort
  if len(a:name)
    call s:setActiveNamespace(a:name)
  endif
  " TODO: update any existing view buffers to use new namespace
  echom 'Using namespace: ' . s:getActiveNamespace()
endfun

" :Kget
" Open or if already existing, switch to view buffer and load the list of `res` resources.
" If `res` is not provided, 'pods' is assumed.
fun! vimkubectl#openResourceListView(res) abort
  let resource = len(a:res) ? split(a:res)[0] : 'pods'
  let resourceType = split(resource, '/')[0]
  let namespace = s:getActiveNamespace()

  call s:openViewBuffer(l:resource)
endfun

" :Kedit
" Open an edit buffer with the resource manifest loaded
fun! vimkubectl#editResourceObject(fullResource) abort
  "TODO: validate fullResource
  let resource = split(a:fullResource, '/')
  "TODO: provide config option for default open method
  call s:openEditBuffer('split', l:resource[0], l:resource[1])
endfun

" :Kapply
" Apply the buffer contents.
" If range is used, apply only the selected section,
" else apply entire buffer
fun! vimkubectl#applyActiveBuffer() range abort
  echo 'Applying resource...'
  silent let result = s:applyActiveBuffer(a:firstline, a:lastline)
  if v:shell_error !=# 0
    call s:printWarning(l:result)
    return
  endif
  echom l:result
  echo 'Successfully applied.'
endfun

fun! vimkubectl#overrideBuffer() abort
  let resource = trim(expand('%'), 'kube://', 1)
  let parsedResource = split(l:resource, '/')
  if len(parsedResource) ==# 1
    call s:viewBuffer_prepareBuffer()
    call s:viewBuffer_refreshViewBuffer()
  else
    call s:editBuffer_prepareBuffer()
    call s:editBuffer_refreshEditBuffer()
  endif
endfun

" COMPLETION FUNCTIONS
" --------------------

" Completion function for namespaces
fun! vimkubectl#allNamespaces(A, L, P) abort
  let namespaces = system(s:craftCommand('get ns -o custom-columns=":metadata.name"', ''))
  if v:shell_error !=# 0
    return ''
  endif
  return l:namespaces
endfun

" Completion function for resource types only
fun! vimkubectl#allResources(A, L, P) abort
  " TODO: Escape from awk dependency
  let availableResources = system(s:craftCommand('api-resources -o name --cached --verbs=get', '') . ' | awk -F "." ''{print $1}''')
  if v:shell_error !=# 0
    return ''
  endif
  return l:availableResources
endfun

" Completion function for resource types and resource objects
function! vimkubectl#allResourcesAndObjects(arg, line, pos) abort
  let arguments = split(a:line, '\s\+')
  if len(arguments) > 2 || len(arguments) > 1 && a:arg =~# '^\s*$'
    let objectList = s:craftCommand('get ' . arguments[1] . ' -o custom-columns=":metadata.name" ', s:getActiveNamespace())
  else
    let objectList = vimkubectl#allResources('', '', '')
  endif
  if v:shell_error !=# 0
    return ''
  endif
  return l:objectList
endfunction

" vim: ts:et:sw=2:sts=2:
