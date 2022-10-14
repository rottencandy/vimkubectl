" UTILS
" -----

" Clear all undo history
" Source: https://vi.stackexchange.com/a/16915/22360
fun! vimkubectl#util#resetUndo() abort
  try
    let undo_setting = &undolevels
    set undolevels=-1
    silent! exec "normal a \<BS>\<Esc>"
  finally
    let &undolevels = undo_setting
  endtry
endfun

" TODO: find a way to store namespace state somewhere else
let s:currentNamespace = ''

fun! vimkubectl#util#getActiveNamespace() abort
  if !len(s:currentNamespace)
    let s:currentNamespace = vimkubectl#kube#fetchActiveNamespace()
  endif
  return s:currentNamespace
endfun

fun! vimkubectl#util#setActiveNamespace(namespace) abort
  let s:currentNamespace = a:namespace
endfun

" Print a message to cmdline
fun! vimkubectl#util#showMessage(message) abort
  echom '[Vimkubectl] ' . a:message
endfun

" Print a message to cmdline, and save to :messages history
fun! vimkubectl#util#printMessage(message) abort
  echom '[Vimkubectl] ' . a:message
endfun

" Print a message with warning highlight, and save to :messages history
fun! vimkubectl#util#printWarning(message) abort
  echohl WarningMsg | echom '[Vimkubectl] ' . a:message | echohl None
endfun

" Print a message with error highlight, and save to :messages history
fun! vimkubectl#util#printError(message) abort
  echohl ErrorMsg | echom '[Vimkubectl] ' . a:message | echohl None
endfun

" Clear the cmd line
" https://stackoverflow.com/a/33854736/7683374
fun! vimkubectl#util#clearCmdLine() abort
  echon "\r\r"
  echon ''
endfun

" Apply the contents of the active buffer,
fun! vimkubectl#util#applyActiveBuffer(startLine, endLine) abort
  let manifest = getline(a:startLine, a:endLine)
  return vimkubectl#kube#applyString(l:manifest, vimkubectl#util#getActiveNamespace())
endfun

" vim: et:sw=2:sts=2:
