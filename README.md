Vimctl
======

Manage Kubernetes resources from Vim.


Installation
------------

Use your favourite plugin manager

- As a Vim8 plugin
  ```sh
  mkdir -p ~/.vim/pack/local/start
  cd ~/.vim/pack/local/start
  git clone github.com/rottencandy/vimctl.git
  ```
  Help tag files can be generated with `:helptags ALL`.


Usage
-----

Make sure you are logged in to your cluster using `kubectl` or a similar tool.

- Use `g:vimctl_command` to specify the tool to use. (default: `kubectl`)

- `:KGet {resource_type}`

  Get a list of all resources that match `{resource_type}`. If `{resource_type}` is not given, `pod` is used.

  You can also use `<Tab>` to cycle through possible resource types.

- `gr` to refresh/update the list of resources.

- `i` to edit resource under cursor.

- `dd` to delete resource under cursor.
