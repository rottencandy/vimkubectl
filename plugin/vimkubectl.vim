if exists('g:loaded_vimkubectl')
  finish
endif
let g:loaded_vimkubectl = 1

command -bar -bang -complete=custom,vimkubectl#allResources -nargs=? Kget call vimkubectl#openResourceListView(<q-args>)
command -bar -bang -complete=custom,vimkubectl#allNamespaces -nargs=? Kns call vimkubectl#switchOrShowNamespace(<q-args>)
command -bar -bang -complete=custom,vimkubectl#allContexts -nargs=? Kctx call vimkubectl#switchOrShowContext(<q-args>)
command -bar -bang -complete=custom,vimkubectl#allResourcesAndObjects -nargs=+ Kedit call vimkubectl#editResourceObject(<q-args>)
command -bar -bang -complete=custom,vimkubectl#allResources -nargs=+ Kdoc call vimkubectl#viewResourceDoc(<q-args>)
command -bar -bang -nargs=0 -range=% Kapply <line1>,<line2>call vimkubectl#buf#applyActiveBuffer()
command -bar -nargs=+ K call vimkubectl#runCmd(<q-args>)

augroup vimkubectl_internal
  autocmd! *
  autocmd BufReadCmd kube://* nested call vimkubectl#hijackBuffer()
  autocmd BufDelete kube://* nested call vimkubectl#cleanupBuffer(expand('<abuf>'))
  autocmd BufReadCmd kubeDoc://* nested call vimkubectl#hijackDocBuffer()
  autocmd BufDelete kubeDoc://* nested call vimkubectl#cleanupBuffer(expand('<abuf>'))
augroup END

" vim: et:sw=2:sts=2:
