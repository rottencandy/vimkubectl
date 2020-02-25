command -bar -bang -complete=custom,vimctl#completionList -nargs=? KGet :call vimctl#getResource(<f-args>)
