" COMMAND FUNCTIONS
" -----------------

" :K
" Runs any arbitrary command
fun! vimkubectl#runCmd(cmd) abort
  if len(a:cmd)
    call vimkubectl#util#showMessage("Running...")
    call vimkubectl#kube#runCmd(
          \ a:cmd,
          \ { out -> vimkubectl#util#printMessage(trim(out)) }
          \ )
  endif
endfun

" :Kns
" If `name` is provided, switch to using it as active namespace.
" Else print currently active namespace.
fun! vimkubectl#switchOrShowNamespace(name) abort
  if len(a:name)
    call vimkubectl#kube#setNs(
          \ a:name,
          \ { -> vimkubectl#util#printMessage('Switched to ' . a:name) }
          \ )
  else
    call vimkubectl#util#printMessage(
          \ 'Active NS: ' . vimkubectl#kube#fetchActiveNamespace()
          \ )
  endif
endfun

" :Kget
" Open or if already existing, switch to view buffer and load the list
" of `res` resources.
" If `res` is not provided, 'pods' is assumed.
fun! vimkubectl#openResourceListView(res) abort
  " TODO: support multiple resource types simultaneously
  const resource = len(a:res) ? split(a:res)[0] : 'pods'

  call vimkubectl#buf#view_load(l:resource)
endfun

" :Kedit
" Open an edit buffer with the resource manifest loaded
fun! vimkubectl#editResourceObject(fullResource) abort
  " TODO: make this work even with spaces instead of /
  const resource = split(a:fullResource, '/')
  "TODO: provide config option for default open method
  call vimkubectl#buf#edit_load('split', l:resource[0], l:resource[1])
endfun

fun! vimkubectl#hijackBuffer() abort
  const resource = substitute(expand('%'), '^kube://', '', '')
  const parsedResource = split(l:resource, '/')
  if len(parsedResource) ==# 1
    call vimkubectl#buf#view_prepare()
  else
    call vimkubectl#buf#edit_prepare()
  endif
endfun

fun! vimkubectl#cleanupBuffer(buf) abort
  call vimkubectl#buf#view_cleanup()
endfun

" COMPLETION FUNCTIONS
" --------------------

" Completion function for namespaces
fun! vimkubectl#allNamespaces(A, L, P) abort
  const namespaces = vimkubectl#kube#fetchNamespaces()
  if v:shell_error !=# 0
    return ''
  endif
  return l:namespaces
endfun

" Completion function for resource types only
fun! vimkubectl#allResources(A, L, P) abort
  const availableResources = vimkubectl#kube#fetchResourceTypes()
  if v:shell_error !=# 0
    return ''
  endif
  return l:availableResources
endfun

" Completion function for resource types and resource objects
function! vimkubectl#allResourcesAndObjects(arg, line, pos) abort
  const arguments = split(a:line, '\s\+')
  if len(arguments) > 2 || len(arguments) > 1 && a:arg =~# '^\s*$'
    const objectList = vimkubectl#kube#fetchPureResourceList(
          \ arguments[1],
          \ vimkubectl#kube#fetchActiveNamespace()
          \ )
  else
    const objectList = vimkubectl#kube#fetchResourceTypes()
  endif
  if v:shell_error !=# 0
    return ''
  endif
  return l:objectList
endfunction

" vim: et:sw=2:sts=2:
