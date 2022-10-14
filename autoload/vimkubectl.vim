" Namespace for functions that are intended to be run from edit buffers
" let s:editBuffer = {}
" TODO: Figure out better way to create namespaces

" Save buffer file contents to local file
fun! s:editBuffer_saveToFile(name) abort
  let fileName = a:name
  if !len(a:name)
    let l:fileName = substitute(expand('%'), '\v\/', '_', '') . '.yaml'
  endif
  let manifest = getline('1', '$')
  call writefile(l:manifest, l:fileName)
  call vimkubectl#util#printMessage('Saved to ' . l:fileName)
endfun

" Fetch the manifest of the resource and fill up the buffer,
" after discarding any existing content
fun! s:editBuffer_refreshEditBuffer() abort
  let fullResource = substitute(expand('%'), '^kube://', '', '')
  let resource = split(l:fullResource, '/')

  call vimkubectl#util#showMessage('Fetching manifest...')
  let updatedManifest = vimkubectl#kube#fetchResourceManifest(l:resource[0], l:resource[1], vimkubectl#kube#fetchActiveNamespace())
  call vimkubectl#util#clearCmdLine()
  if v:shell_error !=# 0
    call vimkubectl#util#printWarning(join(l:updatedManifest, "\n"))
    return
  endif
  silent! execute '%d'
  call setline('.', l:updatedManifest)
  call vimkubectl#util#resetUndo()
  setlocal nomodified
endfun

" Apply the buffer contents
fun! s:editBuffer_applyBuffer() range abort
  call vimkubectl#util#showMessage('Applying resource...')
  silent let result = vimkubectl#util#applyActiveBuffer(a:firstline, a:lastline)
  if v:shell_error !=# 0
    call vimkubectl#util#printWarning(l:result)
    return
  endif
  call vimkubectl#util#printMessage(trim(l:result))
  call vimkubectl#util#showMessage('Successful. Updating manifest...')
  call s:editBuffer_refreshEditBuffer()
  call vimkubectl#util#printMessage('Updated manifest')
endfun

" Configure current buffer with appropriate options and default mappings for edit
fun! s:editBuffer_prepareBuffer() abort
  setlocal buftype=acwrite
  setlocal bufhidden=delete
  setlocal filetype=yaml
  setlocal noswapfile

  " TODO warn before redrawing with unsaved changes
  nnoremap <silent><buffer> gr :call <SID>editBuffer_refreshEditBuffer()<CR>
  command! -buffer -bar -bang -nargs=? Ksave :call <SID>editBuffer_saveToFile(<q-args>)

  augroup vimkubectl_internal_editBufferOnSave
    autocmd! *
    autocmd BufWriteCmd <buffer> 1,$call <SID>editBuffer_applyBuffer()
  augroup END
endfun

" Create or switch to edit buffer(kube://{resourceType}/{resourceName})
fun! s:openEditBuffer(openMethod, resourceType, resourceName) abort
  " TODO verify if openMethod is valid
  let existing = bufwinnr('^kube://' . a:resourceType . '/' . a:resourceName . '$')
  if l:existing ==# -1
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
  let headerLength = len(s:viewBuffer_headerText('', 0))
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

  call vimkubectl#util#showMessage('Deleting...')
  let result = vimkubectl#kube#deleteResource(l:resource[0], l:resource[1], vimkubectl#kube#fetchActiveNamespace())
  if v:shell_error !=# 0
    call vimkubectl#util#printWarning(l:result)
  else
    call s:viewBuffer_refreshViewBuffer()
    call vimkubectl#util#printMessage(trim(l:result))
  endif
endfun

" Create header text to be shown at the top of the buffer
fun! s:viewBuffer_headerText(resource, resourceCount) abort
  return [
        \ 'Namespace: ' . vimkubectl#kube#fetchActiveNamespace(),
        \ 'Resource: ' . a:resource . ' (' . a:resourceCount . ')',
        \ 'Help: g?',
        \ '',
        \ ]
endfun

" Fetch the resources related to buffer and fill it up,
" after discarding any existing content
fun! s:viewBuffer_refreshViewBuffer() abort
  let resourceType = substitute(expand('%'), '^kube://', '', '')
  let namespace = vimkubectl#kube#fetchActiveNamespace()

  call vimkubectl#util#showMessage('Fetching resources...')
  let resourceList = vimkubectl#kube#fetchResourceList(l:resourceType, l:namespace)
  call vimkubectl#util#clearCmdLine()
  if v:shell_error != 0
    call vimkubectl#util#printWarning(join(l:resourceList, "\n"))
    " TODO: close buffer if already empty
    return
  endif

  setlocal modifiable
  silent! execute '%d'
  call append(0, s:viewBuffer_headerText(l:resourceType, len(l:resourceList)))
  call setline('.', l:resourceList)
  call vimkubectl#util#resetUndo()
  setlocal nomodifiable
endfun

" Configure current buffer with appropriate options and default mappings for view
fun! s:viewBuffer_prepareBuffer() abort
  setlocal buftype=nowrite
  setlocal bufhidden=delete
  setlocal filetype=kubernetes
  setlocal noswapfile

  nnoremap <silent><buffer> g? :help vimkubectl-mapping<CR>
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
    call vimkubectl#kube#setNs(a:name, { -> vimkubectl#util#printMessage('Switched to ' . a:name) })
  else
    " TODO: update any existing view buffers to use new namespace
    call vimkubectl#util#printMessage('Active NS: ' . vimkubectl#kube#fetchActiveNamespace())
  endif
endfun

" :Kget
" Open or if already existing, switch to view buffer and load the list of `res` resources.
" If `res` is not provided, 'pods' is assumed.
fun! vimkubectl#openResourceListView(res) abort
  let resource = len(a:res) ? split(a:res)[0] : 'pods'

  call s:openViewBuffer(l:resource)
endfun

" :Kedit
" Open an edit buffer with the resource manifest loaded
fun! vimkubectl#editResourceObject(fullResource) abort
  " TODO: make this work even with spaces instead of /
  let resource = split(a:fullResource, '/')
  "TODO: provide config option for default open method
  call s:openEditBuffer('split', l:resource[0], l:resource[1])
endfun

" :Kapply
" Apply the buffer contents.
" If range is used, apply only the selected section,
" else apply entire buffer
fun! vimkubectl#applyActiveBuffer() range abort
  call vimkubectl#util#showMessage('Applying resource...')
  silent let result = vimkubectl#util#applyActiveBuffer(a:firstline, a:lastline)
  if v:shell_error !=# 0
    call vimkubectl#util#printWarning(l:result)
    return
  endif
  call vimkubectl#util#printMessage(trim(l:result))
  call vimkubectl#util#showMessage('Successfully applied.')
endfun

fun! vimkubectl#hijackBuffer() abort
  let resource = substitute(expand('%'), '^kube://', '', '')
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
  let namespaces = vimkubectl#kube#fetchNamespaces()
  if v:shell_error !=# 0
    return ''
  endif
  return l:namespaces
endfun

" Completion function for resource types only
fun! vimkubectl#allResources(A, L, P) abort
  let availableResources = vimkubectl#kube#fetchResourceTypes()
  if v:shell_error !=# 0
    return ''
  endif
  return l:availableResources
endfun

" Completion function for resource types and resource objects
function! vimkubectl#allResourcesAndObjects(arg, line, pos) abort
  let arguments = split(a:line, '\s\+')
  if len(arguments) > 2 || len(arguments) > 1 && a:arg =~# '^\s*$'
    let objectList = vimkubectl#kube#fetchPureResourceList(arguments[1], vimkubectl#kube#fetchActiveNamespace())
  else
    let objectList = vimkubectl#kube#fetchResourceTypes()
  endif
  if v:shell_error !=# 0
    return ''
  endif
  return l:objectList
endfunction

" vim: et:sw=2:sts=2:
