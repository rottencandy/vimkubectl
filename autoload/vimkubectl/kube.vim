" Create command using g:vimkubectl_command
fun! vimkubectl#kube#craftCommand(command, namespace) abort
  let nsFlag = len(a:namespace) ? '-n ' . a:namespace : ''
  let timeoutFlag = '--request-timeout=' . get(g:, 'vimkubectl_timeout', 5) . 's'
  return join([get(g:, 'vimkubectl_command', 'kubectl'), a:command, l:nsFlag, l:timeoutFlag])
endfun

" Fetch list of all namespaces
" returns string of space-separated values
fun! vimkubectl#kube#fetchNamespaces() abort
  return system(vimkubectl#kube#craftCommand('get ns -o custom-columns=":metadata.name"', ''))
endfun

" Fetch list of resource types
" Note: This uses --cached
" returns string of space-separated values
fun! vimkubectl#kube#fetchResourceTypes() abort
  return system(vimkubectl#kube#craftCommand(join(['api-resources', '--cached', '-o name']), ''))
endfun

" Fetch list of resources of a given type
" returns array of `resourceType/resourceName`
fun! vimkubectl#kube#fetchResourceList(resourceType, namespace) abort
  return systemlist(vimkubectl#kube#craftCommand(join(['get', a:resourceType, '-o name']), a:namespace))
endfun

" Same as above but returns only list of `resourceName`
" Note: This uses --cached
" returns string of space-separated values
fun! vimkubectl#kube#fetchPureResourceList(resourceType, namespace) abort
  return system(vimkubectl#kube#craftCommand(join(['get', a:resourceType, '-o custom-columns=":metadata.name"']), a:namespace))
endfun

" Fetch manifest of resource
" returns array of strings of each line
fun! vimkubectl#kube#fetchResourceManifest(resourceType, resource, namespace) abort
  return systemlist(vimkubectl#kube#craftCommand(join(['get', a:resourceType, a:resource, '-o yaml']), a:namespace))
endfun

" Delete resource
fun! vimkubectl#kube#deleteResource(resourceType, resource, namespace) abort
  return system(vimkubectl#kube#craftCommand(join(['delete', a:resourceType, a:resource]), a:namespace))
endfun

" Apply string
fun! vimkubectl#kube#applyString(stringData, namespace) abort
  return system(vimkubectl#kube#craftCommand('apply -f -', a:namespace), a:stringData)
endfun

" Get currently active namespace
fun! vimkubectl#kube#fetchActiveNamespace() abort
  return system(vimkubectl#kube#craftCommand('config view --minify -o ''jsonpath={..namespace}''', ''))
endfun

" vim: et:sw=2:sts=2:
