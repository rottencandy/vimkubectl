" UTILS
" -----
const s:msgPrefix = '[Vimkubectl] '

" Clear all undo history
" Adapted from: https://vi.stackexchange.com/a/16915/22360
fun! vimkubectl#util#resetUndo(bufnr) abort
  try
    const undo_setting = getbufvar(a:bufnr, '&undolevels')
    call setbufvar(a:bufnr, '&undolevels', -1)
    call appendbufline(a:bufnr, '$', '')
    call deletebufline(a:bufnr, '$')
  finally
    call setbufvar(a:bufnr, '&undolevels', l:undo_setting)
  endtry
endfun

" Print a message to cmdline
fun! vimkubectl#util#showMessage(message = '') abort
  echo s:msgPrefix . a:message
endfun

" Print a message to cmdline, and save to :messages history
fun! vimkubectl#util#printMessage(message = '') abort
  echom s:msgPrefix . a:message
endfun

" Print a message with warning highlight, and save to :messages history
fun! vimkubectl#util#printWarning(message = '') abort
  echohl WarningMsg | echom s:msgPrefix . a:message | echohl None
endfun

" Print a message with error highlight, and save to :messages history
fun! vimkubectl#util#printError(message = '') abort
  echohl ErrorMsg | echom s:msgPrefix . a:message | echohl None
endfun

" Clear the cmd line
" https://stackoverflow.com/a/33854736/7683374
fun! vimkubectl#util#clearCmdLine() abort
  echon "\r\r"
  echon ''
endfun

" Save buffer file contents to local file
" saves as `resourceType_resource.yaml` if name is not given
fun! vimkubectl#util#saveToFile(fname = '') abort
  let fileName = a:fname
  if !len(a:fname)
    let l:fileName = substitute(substitute(expand('%'), '\v^kube:\/\/', '', ''), '\v\/', '_', '') . '.yaml'
  endif
  const manifest = getline('1', '$')
  call writefile(l:manifest, l:fileName)
  call vimkubectl#util#printMessage('Saved to ' . l:fileName)
endfun

" Wrapper over async.vim https://github.com/prabirshrestha/async.vim
" Run the `cmd` asynchronously, and call `callback` ONLY once command has
" exited.
" written to(Does not run when STDOUT is empty).
" Print error message in case of non-zero return.
"
" Note on outType:
" `outType` defines the data type, either 'string'(default), 'array' or 'raw'
" 'string' is noop in vim, 'array' is noop in nvim
" 'raw' will mean array for nvim and string for vim
fun! vimkubectl#util#asyncExec(cmd, callback, outType = 'string', ctx = {}) abort
  let outData = a:outType ==# 'array' ? [] : ''
  let handlers = { 'normalize': a:outType }

  fun! handlers.on_stdout(jobId, data, event) closure abort
    if !len(a:data)
      return
    endif
    " Combine last line & first line to avoid s between stdout callbacks.
    " TODO: issue still exists for 'string',
    " substitute()ing does not seem to fix this
    if a:outType ==# 'array'
      if len(l:outData)
        let l:outData[-1] .= a:data[0]
      else
        let l:outData = [a:data[0]]
      endif
      call extend(l:outData, a:data[1:])
    else
      let l:outData .= a:data
    endif
  endfun

  fun! handlers.on_stderr(jobId, data, event) closure abort
    if len(a:data) > 0
      if a:outType ==# 'string'
        call vimkubectl#util#printError(a:data)
      else
        if len(a:data[0]) > 0
          call vimkubectl#util#printError(join(a:data, '\n'))
        endif
      endif
    endif
  endfun

  fun! handlers.on_exit(jobId, data, event) closure abort
    call a:callback(l:outData, a:ctx)
  endfun

  return async#job#start(a:cmd, handlers)
endfun

" Wrapper over async.vim https://github.com/prabirshrestha/async.vim
" Same as vimkubectl#util#asyncExec but calls `callback` everytime STDOUT is
" written to(Does not run when STDOUT is empty).
fun! vimkubectl#util#asyncRun(cmd, callback, outType = 'string', ctx = {}) abort
  let handlers = { 'normalize': a:outType }

  fun! handlers.on_stdout(jobId, data, event) closure abort
    if len(a:data)
      call a:callback(a:data, a:ctx)
    endif
  endfun

  fun! handlers.on_stderr(jobId, data, event) closure abort
    if len(a:data)
      if a:outType ==# 'string'
        call vimkubectl#util#printError(a:data)
      else
        if len(a:data[0]) > 0
          call vimkubectl#util#printError(join(a:data, '\n'))
        endif
      endif
    endif
  endfun

  fun! handlers.on_exit(jobId, data, event) closure abort
  endfun

  return async#job#start(a:cmd, handlers)
endfun

" vim: et:sw=2:sts=2:
