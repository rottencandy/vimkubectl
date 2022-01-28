if exists('b:current_syntax')
  finish
endif

syn match kubernetesHeader '\v^[A-Z][a-z][^:]*: .*$' skipwhite contains=kubernetesIdentifier
syn match kubernetesResource '\v^[a-z \.]*\/[a-z \- 0-9 \.]*$' skipwhite contains=kubernetesResourcePrefix

syn match kubernetesIdentifier '\v [a-z 0-9 ()]*$' contained
syn match kubernetesResourcePrefix '\v^[a-z \.]*\/' contained

hi def link kubernetesHeader Label
hi def link kubernetesIdentifier Function
hi def link kubernetesResourcePrefix Comment
hi def link kubernetesResource Identifier

let b:current_syntax = 'vimkubectl'

" vim: et:sw=2:sts=2:
