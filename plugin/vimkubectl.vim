if exists('g:loaded_vimkubectl')
  finish
endif
let g:loaded_vimkubectl = 1

command -bar -bang -complete=custom,vimkubectl#allResources -nargs=? Kget call vimkubectl#openResourceListView(<q-args>)
command -bar -bang -complete=custom,vimkubectl#allNamespaces -nargs=? Knamespace call vimkubectl#switchOrShowNamespace(<q-args>)
command -bar -bang -complete=custom,vimkubectl#allResourcesAndObjects -nargs=+ Kedit call vimkubectl#editResourceObject(<q-args>)
command -bar -bang -nargs=0 -range=% Kapply <line1>,<line2>call vimkubectl#applyActiveBuffer()

augroup vimkubectl_internal
  autocmd! *
  autocmd BufReadCmd kube://* nested call vimkubectl#overrideBuffer()
augroup END
