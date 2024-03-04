" LEGACY SYNCHRONOUS FUNCTIONS
" Check exit code for failure after calling these functions
" TODO: migrate these to async api
" ----------------------------

" Fetch list of all namespaces
" returns string of space-separated values
fun! vimkubectl#kube#fetchNamespaces() abort
  return system(s:craftCmd('get ns -o custom-columns=":metadata.name"'))
endfun

" Fetch list of resource types
" Note: This uses --cached so mostly doesn't fail
" returns string of space-separated values
fun! vimkubectl#kube#fetchResourceTypes() abort
  return system(s:craftCmd(join(['api-resources', '--cached', '-o name'])))
endfun

" Same as above but returns only list of `resourceName`
" returns string of space-separated values
fun! vimkubectl#kube#fetchPureResourceList(resourceType, namespace) abort
  return system(s:craftCmd(
        \ join(['get', a:resourceType, '-o custom-columns=":metadata.name"']),
        \ a:namespace
        \ ))
endfun

" Get currently active namespace
fun! vimkubectl#kube#fetchActiveNamespace() abort
  return system(
        \ s:craftCmd('get sa default -o ''jsonpath={.metadata.namespace}''')
        \ )
endfun

" Get currently active context
fun! vimkubectl#kube#fetchActiveContext() abort
  return system(
        \ s:craftCmd('config current-context')
        \ )
endfun

" Fetch all contexts
" returns string of space-separated values
fun! vimkubectl#kube#fetchContexts() abort
  return system(
        \ s:craftCmd('config get-contexts -o name')
        \ )
endfun

" ASYNCHRONOUS FUNCTIONS
" ----------------------

" Create command using g:vimkubectl_command
fun! s:craftCmd(command, namespace = '') abort
  let nsFlag = len(a:namespace) ? '-n ' . a:namespace : ''
  let timeoutFlag =
        \ '--request-timeout='
        \ . get(g:, 'vimkubectl_timeout', 5)
        \ . 's'
  return join([
        \ get(g:, 'vimkubectl_command', 'kubectl'),
        \ a:command,
        \ l:nsFlag,
        \ l:timeoutFlag
        \ ])
endfun

fun! s:asyncCmd(command) abort
  return ['bash', '-c', a:command]
endfun

fun! s:asyncLoopCmd(command, interval = 5) abort
  return [
        \ 'bash',
        \ '-c',
        \ 'while true; do ' . a:command . '; sleep ' . a:interval . '; done'
        \ ]
endfun

" Fetch manifest of resource
" callback gets array of strings of each line
fun! vimkubectl#kube#fetchResourceManifest(
      \ resourceType,
      \ resource,
      \ namespace,
      \ callback
      \ ) abort
  let cmd = s:craftCmd(
        \ join(['get', a:resourceType, a:resource, '-o yaml']),
        \ a:namespace
        \ )
  return vimkubectl#util#asyncExec(s:asyncCmd(l:cmd), a:callback, 'array')
endfun

" Apply string
fun! vimkubectl#kube#applyString(stringData, onApply) abort
  let cmd = 'echo "$1" | ' . s:craftCmd('apply -f -')
  " arg 2 sets $0, name of shell
  " arg 3 stringData is supplied to cmd as $1 by bash
  " See bash(1)
  return vimkubectl#util#asyncExec(
        \ ['bash', '-c', l:cmd, 'apply', a:stringData],
        \ a:onApply
        \ )
endfun

" Delete resource
fun! vimkubectl#kube#deleteResource(resType, res, ns, onDel) abort
  let cmd = s:craftCmd(join(['delete', a:resType, a:res]), a:ns)
  return vimkubectl#util#asyncExec(s:asyncCmd(l:cmd), a:onDel)
endfun

" Set active context
fun! vimkubectl#kube#setContext(ctx, onSet) abort
  const cmd = s:craftCmd('config use-context ' . a:ctx)
  return vimkubectl#util#asyncExec(s:asyncCmd(l:cmd), a:onSet)
endfun

" Set active namespace for current context
fun! vimkubectl#kube#setNs(ns, onSet) abort
  const cmd = s:craftCmd('config set-context --current --namespace=' . a:ns)
  return vimkubectl#util#asyncExec(s:asyncCmd(l:cmd), a:onSet)
endfun

" Fetch list of resources of a given type
" returns array of `resourceType/resourceName`
fun! vimkubectl#kube#fetchResourceList(
      \ resourceType,
      \ namespace,
      \ callback,
      \ ctx = {}
      \ ) abort
  const cmd = s:craftCmd(join(['get', a:resourceType, '-o name']), a:namespace)
  return vimkubectl#util#asyncExec(
        \ s:asyncCmd(l:cmd),
        \ a:callback,
        \ 'array',
        \ a:ctx
        \ )
endfun

" Same as fetchResourceList but keep polling every 5 seconds
fun! vimkubectl#kube#fetchResourceListLoop(
      \ resourceType,
      \ namespace,
      \ callback,
      \ ctx = {}
      \ ) abort
  const cmd = s:craftCmd(join(['get', a:resourceType, '-o name']), a:namespace)
  return vimkubectl#util#asyncRun(
        \ s:asyncLoopCmd(l:cmd),
        \ a:callback,
        \ 'array',
        \ a:ctx
        \ )
endfun

" Fetch doc
" returns doc
fun! vimkubectl#kube#fetchDoc(
      \ resourceSpec,
      \ namespace,
      \ callback,
      \ ctx = {}
      \ ) abort
  const cmd = s:craftCmd(join(['explain', a:resourceSpec ]), a:namespace)
  return vimkubectl#util#asyncRun(
        \ s:asyncCmd(l:cmd),
        \ a:callback,
        \ 'array',
        \ a:ctx
        \ )
endfun



" Runs arbitrary command
fun! vimkubectl#kube#runCmd(cmd, callback) abort
  const cmd = s:craftCmd(a:cmd)
  return vimkubectl#util#asyncExec(s:asyncCmd(l:cmd), a:callback)
endfun

" vim: et:sw=2:sts=2:
