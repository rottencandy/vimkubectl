Vimctl
======

View, edit and control Kubernetes resources from Vim.


Installation
------------

Use your favourite plugin manager

- Using [vim-plug](https://github.com/junegunn/vim-plug)
  1. Add `Plug 'junegunn/goyo.vim'` to .vimrc
  2. Run `:PlugInstall`

- As a Vim8 plugin
  ```sh
  mkdir -p ~/.vim/pack/local/start
  cd ~/.vim/pack/local/start
  git clone github.com/rottencandy/vimctl.git
  ```


Usage
-----

Make sure you are logged in to your cluster using `kubectl` or a similar tool.

- Use `g:vimctl_command` to specify the tool to use. (default: `kubectl`)

- `:KGet {resource_type}`
  Get a list of all resources that match `{resource_type}`. If `{resource_type}` is not specified, `pod` is assumed.

- `i` to edit resource under cursor.
