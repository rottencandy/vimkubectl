if exists('b:current_syntax')
  finish
endif

syn match vkctlHeader '\v^[A-Z][a-z][^:]*: .*$' contains=vkctlIdentifier skipwhite
syn match vkctlHelpHeader '\v^Help:' nextgroup=vkctlHelpTag skipwhite
syn match vkctlResource '\v^[a-z \.]*\/[a-z \- 0-9 \.]*$' contains=vkctlResourcePrefix skipwhite

syn match vkctlHelpTag '\v\S+' contained
syn match vkctlResourcePrefix '\v^[a-z \.]*\/' contained
syn match vkctlIdentifier '\v [a-z 0-9 ()]*$' contained

hi def link vkctlHeader Label
hi def link vkctlHelpHeader vkctlHeader
hi def link vkctlIdentifier Function
hi def link vkctlHelpTag Tag
hi def link vkctlResourcePrefix Comment
hi def link vkctlResource Identifier

let b:current_syntax = 'vimkubectl'

" vim: et:sw=2:sts=2:
