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
  command! -buffer -bar -bang -nargs=? Ksave :call <SID>vimkubectl#util#saveToFile(<q-args>)

  augroup vimkubectl_internal_editBufferOnSave
    autocmd! *
    autocmd BufWriteCmd <buffer> 1,$call <SID>editBuffer_applyBuffer()
  augroup END
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
    call vimkubectl#util#printMessage('Active NS: ' . vimkubectl#kube#fetchActiveNamespace())
  endif
endfun

" :Kget
" Open or if already existing, switch to view buffer and load the list of `res` resources.
" If `res` is not provided, 'pods' is assumed.
fun! vimkubectl#openResourceListView(res) abort
  " TODO: support multiple resource types simultaneously
  let resource = len(a:res) ? split(a:res)[0] : 'pods'

  call vimkubectl#buf#view_load(l:resource)
endfun

" :Kedit
" Open an edit buffer with the resource manifest loaded
fun! vimkubectl#editResourceObject(fullResource) abort
  " TODO: make this work even with spaces instead of /
  let resource = split(a:fullResource, '/')
  "TODO: provide config option for default open method
  call vimkubectl#buf#edit_load('split', l:resource[0], l:resource[1])
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
    call vimkubectl#buf#view_prepare()
  else
    call s:editBuffer_prepareBuffer()
    call s:editBuffer_refreshEditBuffer()
  endif
endfun

fun! vimkubectl#cleanupBuffer(buf) abort
  call vimkubectl#buf#view_cleanup()
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
