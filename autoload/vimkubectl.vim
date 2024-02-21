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

" :Kctx
" If `name` is provided, switch to using it as active context.
" Else print currently active context.
fun! vimkubectl#switchOrShowContext(name) abort
  if len(a:name)
    call vimkubectl#kube#setContext(
          \ a:name,
          \ { -> vimkubectl#util#printMessage('Switched to ' . a:name) }
          \ )
  else
    const ctx = vimkubectl#kube#fetchActiveContext()
    if v:shell_error !=# 0
      call vimkubectl#util#printError('Unable to fetch active context')
    else
      call vimkubectl#util#printMessage('Active context: ' . l:ctx)
    endif
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
" Args could either be in `res/obj` or `res obj` format
fun! vimkubectl#editResourceObject(args) abort
  const fullResource = split(a:args, '\s\+')
  if len(fullResource) > 1
    const resource = l:fullResource
  else
    const resource = split(a:args, '/')
  endif
  "TODO: provide config option for default open method
  call vimkubectl#buf#edit_load('split', l:resource[0], l:resource[1])
endfun

" :Kdoc
" Open a buffer with the resource manual loaded
" Args need to be in `res` or `res.spec` format. 
" Args directly supplied to kubectl/oc explain
fun! vimkubectl#viewResourceDoc(args) abort
  const resourceSpec = a:args
  call vimkubectl#buf#doc_load('split', l:resourceSpec)
endfun

" This one is determining if user is doing a Kedit or Kget
fun! vimkubectl#hijackBuffer() abort
  const resource = substitute(expand('%'), '^kube://', '', '')
  const parsedResource = split(l:resource, '/')
  if len(parsedResource) ==# 1
    call vimkubectl#buf#view_prepare()
  else
    call vimkubectl#buf#edit_prepare()
  endif
endfun

fun! vimkubectl#hijackDocBuffer() abort
  call vimkubectl#buf#doc_prepare()
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

" Completion function for contexts
fun! vimkubectl#allContexts(A, L, P) abort
  const contexts = vimkubectl#kube#fetchContexts()
  if v:shell_error !=# 0
    return ''
  endif
  return l:contexts
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
