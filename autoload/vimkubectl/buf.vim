let b:jobid = 0

fun! s:headerText(resource, resourceCount) abort
  return [
        \ 'Namespace: ' . vimkubectl#kube#fetchActiveNamespace(),
        \ 'Resource: ' . a:resource . ' (' . a:resourceCount . ')',
        \ 'Help: g?',
        \ '',
        \ ]
endfun

" Get the resource under cursor line,
" If cursor is on header, or blank space, return ''
" TODO: range support
fun! s:resourceUnderCursor() abort
  let headerLength = len(s:headerText('', 0))
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
fun! s:editResource(openMethod) abort
  let fullResource = s:resourceUnderCursor()
  if !len(l:fullResource)
    return
  endif

  let resource = split(l:fullResource, '/')
  call vimkubectl#buf#edit_load(a:openMethod, l:resource[0], l:resource[1])
endfun

" Delete the resource under cursor, after confirmation prompt
fun! s:deleteResource() abort
  let fullResource = s:resourceUnderCursor()
  let resource = split(l:fullResource, '/')
  if len(l:resource) !=# 2
    return
  endif

  let choice = confirm('Are you sure you want to delete ' . l:resource[1] . ' ?', "&Yes\n&No")
  if l:choice !=# 1
    return
  endif

  call vimkubectl#util#showMessage('Deleting...')
  call vimkubectl#kube#deleteResource(l:resource[0], l:resource[1], vimkubectl#kube#fetchActiveNamespace(), { res -> vimkubectl#util#printMessage(trim(l:res)) })
endfun

fun! s:refresh(data, ctx) abort
  call filter(a:data, { i, x -> len(x) })

  if !len(a:data)
    return
  endif

  const header = s:headerText(a:ctx.resourceType, len(a:data))

  call setbufvar(a:ctx.bufnr, '&modifiable', 1)
  call deletebufline(a:ctx.bufnr, 1, '$')
  call setbufline(a:ctx.bufnr, 1, l:header)
  call setbufline(a:ctx.bufnr, len(l:header) + 1, a:data)
  "call vimkubectl#util#resetUndo(a:ctx.bufnr)
  call setbufvar(a:ctx.bufnr, '&modifiable', 0)
endfun

fun! vimkubectl#buf#view_prepare() abort
  call vimkubectl#util#showMessage('Loading...')

  setlocal buftype=nowrite
  setlocal bufhidden=delete
  setlocal filetype=kubernetes
  setlocal noswapfile

  nnoremap <silent><buffer> g? :help vimkubectl-mapping<CR>
  nnoremap <silent><buffer> ii :call <SID>editResource('edit')<CR>
  nnoremap <silent><buffer> is :call <SID>editResource('sp')<CR>
  nnoremap <silent><buffer> iv :call <SID>editResource('vs')<CR>
  nnoremap <silent><buffer> it :call <SID>editResource('tabe')<CR>
  nnoremap <silent><buffer> dd :call <SID>deleteResource()<CR>

  const ns = vimkubectl#kube#fetchActiveNamespace()
  const resourceType = substitute(expand('%'), '^kube://', '', '')
  const ctx = {
        \ 'bufnr': bufnr(),
        \ 'resourceType': l:resourceType,
        \ }

  let b:jobid = vimkubectl#util#asyncLoop({ -> vimkubectl#kube#fetchResourceList(l:resourceType, l:ns, function('s:refresh'), l:ctx) }, 5, l:ctx)
endfun

" Create or switch to view buffer(kube://{resourceType})
fun! vimkubectl#buf#view_load(resourceType) abort
  let existing = bufwinnr('^kube://' . a:resourceType . '$')
  if l:existing ==# -1
    execute 'split kube://' . a:resourceType
  else
    execute l:existing . 'wincmd w'
  endif
endfun

" Create or switch to edit buffer(kube://{resourceType}/{resourceName})
fun! vimkubectl#buf#edit_load(openMethod, resourceType, resourceName) abort
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

fun! vimkubectl#buf#view_cleanup() abort
  const jid = get(b:, 'jobid')
  if l:jid
    call async#job#stop(b:jobid)
  endif
endfun

" vim: et:sw=2:sts=2:
