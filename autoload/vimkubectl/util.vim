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
" Run the `cmd` asynchronously, and call `callback` everytime STDOUT is
" written to(Does not run when STDOUT is empty).
" Print error message in case of non-zero return.
" `output` defines the data type, either 'string'(default), 'array' or 'raw'
" 'string' is noop in vim, 'array' is noop in nvim
" 'raw' will mean array for nvim and string for vim
fun! vimkubectl#util#asyncRun(cmd, callback, output = 'string', ctx = {}) abort
  " needed because lambdas for some reason can't use a: _default_ vars from outer scope
  const outType = a:output
  const ctx = a:ctx
  const HandleOut = { jobId, data, event ->
        \ len(data) ?
        \   a:callback(data, l:ctx) :
        \   0
        \ }

  const HandleErr = { jobId, data, event ->
        \ len(data) ?
        \   l:outType ==# 'string' ?
        \     vimkubectl#util#printError(data) :
        \     len(data[0]) ?
        \       vimkubectl#util#printError(join(data, '\n'))
        \       : 0
        \   : 0
        \ }

  const HandleExit = { -> 0 }

  return async#job#start(a:cmd, {
        \ 'on_stdout': l:HandleOut,
        \ 'on_stderr': l:HandleErr,
        \ 'on_exit': l:HandleExit,
        \ 'normalize': a:output
        \ })
endfun

fun! vimkubectl#util#asyncLoop(callback, interval = 5, ctx = {}) abort
  call a:callback()
  const cmd = [
        \ 'bash', '-c',
        \ 'while true; do sleep ' . a:interval . ' && echo 1; done'
        \ ]
  return vimkubectl#util#asyncRun(l:cmd, a:callback, 'string', a:ctx)
endfun

" vim: et:sw=2:sts=2:
