" Wrapper over async.vim https://github.com/prabirshrestha/async.vim
" Run the `cmd` asynchronously, and call `callback` everytime STDOUT is
" written to(Does not run when STDOUT is empty).
" `output` defines the data type, either 'string'(default), 'array' or 'raw'
" 'string' is noop in vim, 'array' is noop in nvim
" 'raw' will mean array for nvim and string for vim
fun! s:asyncRun(cmd, callback, output = 'string') abort
  let HandleOut = { jobId, data, event -> len(data) ? a:callback(data) : 0 }
  let HandleErr = { jobId, data, event -> len(data) ? vimkubectl#util#printError(data) : 0 }
  let HandleExit = { -> 0 }

  call async#job#start(a:cmd, {
        \ 'on_stdout': l:HandleOut,
        \ 'on_stderr': l:HandleErr,
        \ 'on_exit': l:HandleExit,
        \ 'normalize': a:output
        \ })
endfun

" Create command using g:vimkubectl_command
fun! s:craftCmd(command, namespace = '') abort
  let nsFlag = len(a:namespace) ? '-n ' . a:namespace : ''
  let timeoutFlag = '--request-timeout=' . get(g:, 'vimkubectl_timeout', 5) . 's'
  return join([get(g:, 'vimkubectl_command', 'kubectl'), a:command, l:nsFlag, l:timeoutFlag])
endfun

fun! s:asyncCmd(command) abort
  return ['bash', '-c', a:command]
endfun

" Fetch list of all namespaces
" returns string of space-separated values
fun! vimkubectl#kube#fetchNamespaces() abort
  return system(s:craftCmd('get ns -o custom-columns=":metadata.name"'))
endfun

" Fetch list of resource types
" Note: This uses --cached
" returns string of space-separated values
fun! vimkubectl#kube#fetchResourceTypes() abort
  return system(s:craftCmd(join(['api-resources', '--cached', '-o name'])))
endfun

" Fetch list of resources of a given type
" returns array of `resourceType/resourceName`
fun! vimkubectl#kube#fetchResourceList(resourceType, namespace) abort
  return systemlist(s:craftCmd(join(['get', a:resourceType, '-o name']), a:namespace))
endfun

" Same as above but returns only list of `resourceName`
" returns string of space-separated values
fun! vimkubectl#kube#fetchPureResourceList(resourceType, namespace) abort
  return system(s:craftCmd(join(['get', a:resourceType, '-o custom-columns=":metadata.name"']), a:namespace))
endfun

" Fetch manifest of resource
" returns array of strings of each line
fun! vimkubectl#kube#fetchResourceManifest(resourceType, resource, namespace) abort
  return systemlist(s:craftCmd(join(['get', a:resourceType, a:resource, '-o yaml']), a:namespace))
endfun

" Delete resource
fun! vimkubectl#kube#deleteResource(resourceType, resource, namespace) abort
  return system(s:craftCmd(join(['delete', a:resourceType, a:resource]), a:namespace))
endfun

" Apply string
fun! vimkubectl#kube#applyString(stringData, namespace) abort
  return system(s:craftCmd('apply -f -', a:namespace), a:stringData)
endfun

" Get currently active namespace
fun! vimkubectl#kube#fetchActiveNamespace() abort
  return system(s:craftCmd('config view --minify -o ''jsonpath={..namespace}'''))
endfun

" Set active namespace for current context
" This function is blocking
fun! vimkubectl#kube#setNsSync(ns) abort
  const l:fetchNsCmd = s:craftCmd('config set-context --current --namespace=' . a:ns)
  call system(l:fetchNsCmd)
endfun

" Same as above but async
fun! vimkubectl#kube#setNs(ns, onSet) abort
  const l:fetchNsCmd = s:craftCmd('config set-context --current --namespace=' . a:ns)
  call s:asyncRun(s:asyncCmd(l:fetchNsCmd), a:onSet)
endfun

" vim: et:sw=2:sts=2:
