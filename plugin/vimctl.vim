command -bar -bang -complete=customlist,vimctl#completionList -nargs=? KGet :call vimctl#getResource(<f-args>)
