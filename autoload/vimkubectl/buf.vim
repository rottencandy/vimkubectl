let b:vimkubectl_jobid = 0

fun! s:headerText(resource, resourceCount, ns) abort
  return [
        \ 'Namespace: ' . a:ns,
        \ 'Resource: ' . a:resource . ' (' . a:resourceCount . ')',
        \ 'Help: g?',
        \ '',
        \ ]
endfun

" Get the resource under cursor line,
" If cursor is on header, or blank space, return ''
" TODO: range support
fun! s:resourceUnderCursor() abort
  const headerLength = len(s:headerText('', 0, ''))
  if getpos('.')[1] <=# l:headerLength
    return ''
  endif
  const resource = split(getline('.'))
  if len(l:resource)
    return l:resource[0]
  endif
  return ''
endfun

" Open edit buffer for resource under cursor,
" `opemMethod` can be one of [edit, sp, vs, tabe]
fun! s:editResource(openMethod) abort
  const fullResource = s:resourceUnderCursor()
  if !len(l:fullResource)
    return
  endif

  const resource = split(l:fullResource, '/')
  call vimkubectl#buf#edit_load(a:openMethod, l:resource[0], l:resource[1])
endfun

" Delete the resource under cursor, after confirmation prompt
fun! s:deleteResource() abort
  const fullResource = s:resourceUnderCursor()
  const resource = split(l:fullResource, '/')
  if len(l:resource) !=# 2
    return
  endif

  const choice = confirm(
        \ 'Are you sure you want to delete ' . l:resource[1] . ' ?', "&Yes\n&No"
        \ )
  if l:choice !=# 1
    return
  endif

  call vimkubectl#util#showMessage('Deleting...')
  call vimkubectl#kube#deleteResource(
        \ l:resource[0],
        \ l:resource[1],
        \ vimkubectl#kube#fetchActiveNamespace(),
        \ { data -> vimkubectl#util#printMessage(trim(data))
        \ })
endfun

fun! s:refresh(data, ctx) abort
  if len(a:data) <=# 1 || !len(a:data[0])
    return
  endif

  call filter(a:data, {_, v -> len(v)})
  "call filter(a:data, 'v:val !=# ""')

  const header = s:headerText(a:ctx.resourceType, len(a:data), a:ctx.ns)

  call setbufvar(a:ctx.bufnr, '&modifiable', 1)
  call deletebufline(a:ctx.bufnr, 1, '$')
  call setbufline(a:ctx.bufnr, 1, l:header)
  call setbufline(a:ctx.bufnr, len(l:header) + 1, a:data)
  call vimkubectl#util#resetUndo(a:ctx.bufnr)
  call setbufvar(a:ctx.bufnr, '&modifiable', 0)
endfun

fun! vimkubectl#buf#view_prepare() abort
  if exists('b:vimkubectl_prepared')
    return
  endif
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
        \ 'ns': l:ns,
        \ }

  let b:vimkubectl_prepared = 1
  let b:vimkubectl_jobid = vimkubectl#kube#fetchResourceListLoop(
        \ l:resourceType, 
        \ l:ns, 
        \ function('s:refresh'), 
        \ l:ctx
        \ )
endfun

fun! s:fillBuffer(bufnr, data) abort
  if len(a:data) <=# 1
    return
  endif
  call deletebufline(a:bufnr, 1, '$')
  call setbufline(a:bufnr, 1, a:data)
  call vimkubectl#util#resetUndo(a:bufnr)
  call setbufvar(a:bufnr, '&modified', 0)
endfun

" Fetch the manifest of the resource and fill up the buffer,
" after discarding any existing content
fun! s:refreshEditBuffer() abort
  const fullResource = substitute(expand('%'), '^kube://', '', '')
  const resource = split(l:fullResource, '/')

  call vimkubectl#util#showMessage('Fetching manifest...')
  return vimkubectl#kube#fetchResourceManifest(
        \ l:resource[0],
        \ l:resource[1],
        \ vimkubectl#kube#fetchActiveNamespace(),
        \ { data -> s:fillBuffer(bufnr(), data) }
        \ )
endfun

" Apply the buffer contents
" If range is used, apply only the selected section,
" else apply entire buffer
fun! vimkubectl#buf#applyActiveBuffer() range abort
  call vimkubectl#util#showMessage('Applying...')

  " todo: use shellescape?
  const manifest = join(getline(a:firstline, a:lastline), "\n")
  return vimkubectl#kube#applyString(
        \ l:manifest,
        \ vimkubectl#kube#fetchActiveNamespace(),
        \ { result -> vimkubectl#util#showMessage(trim(result)) }
        \ )
endfun

" todo: this is very similar to above func
fun! s:applyAndUpdate() range abort
  call vimkubectl#util#showMessage('Applying...')

  fun! s:onApply(result, ...) abort
    call vimkubectl#util#showMessage(trim(a:result) . ' Updating manifest...')
    call s:refreshEditBuffer()
  endfun

  const manifest = join(getline(a:firstline, a:lastline), "\n")
  return vimkubectl#kube#applyString(
        \ l:manifest,
        \ vimkubectl#kube#fetchActiveNamespace(),
        \ function('s:onApply')
        \ )
endfun

fun! vimkubectl#buf#edit_prepare() abort
  if exists('b:vimkubectl_prepared')
    return
  endif
  call vimkubectl#util#showMessage('Loading...')

  setlocal buftype=acwrite
  setlocal bufhidden=delete
  setlocal filetype=yaml
  setlocal noswapfile

  " TODO warn before redrawing with unsaved changes
  nnoremap <buffer> gr :call <SID>refreshEditBuffer()<CR>
  command! -buffer -bar -bang -nargs=? -complete=file Ksave :call vimkubectl#util#saveToFile(<q-args>)

  augroup vimkubectl_internal_editBufferOnSave
    autocmd! *
    autocmd BufWriteCmd <buffer> 1,$call <SID>applyAndUpdate()
  augroup END

  let b:vimkubectl_prepared = 1
  return s:refreshEditBuffer()
endfun

" Create or switch to view buffer(kube://{resourceType})
fun! vimkubectl#buf#view_load(resourceType) abort
  const existing = bufwinnr('^kube://' . a:resourceType . '$')
  if l:existing ==# -1
    execute 'split kube://' . a:resourceType
  else
    execute l:existing . 'wincmd w'
  endif
endfun

" Create or switch to edit buffer(kube://{resourceType}/{resourceName})
fun! vimkubectl#buf#edit_load(openMethod, resourceType, resourceName) abort
  " TODO verify if openMethod is valid
  const existing = bufwinnr('^kube://' . a:resourceType . '/' . a:resourceName . '$')
  if l:existing ==# -1
    silent! exec a:openMethod . ' kube://' . a:resourceType . '/' . a:resourceName
  else
    silent! execute l:existing . 'wincmd w'
    " refresh needs to be done explicitly because buffer override will not
    " happen to exising buffers (due to BufReadCmd)
    call s:refreshEditBuffer()
  endif
endfun

fun! vimkubectl#buf#view_cleanup() abort
  const jid = get(b:, 'vimkubectl_jobid')
  if l:jid
    call async#job#stop(b:vimkubectl_jobid)
    let b:vimkubectl_jobid = 0
  endif
endfun

" vim: et:sw=2:sts=2:
