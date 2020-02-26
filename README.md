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

Make sure you are logged in to your cluster using `kubectl` or a similar command.

Use `g:vimctl_command` to specify the command to use. (default: `kubectl`)

- `:KGet {resource_type}`

  Get a list of all resources that match `{resource_type}`. If `{resource_type}` is not given, `pod` is used.

  You can also use `<Tab>` to cycle through possible resource types.

  - `gr` to refresh/update the list of resources.

  - `ii` to open and edit the manifest of the resource under cursor, in the current window(opens in `YAML` format)

  - `is` to open in a split.

  - `iv` to open in a vertical split..

  - `it` to open in a new tab.

  - `dd` to delete the resource under cursor.

- The manifest can be edited just like a regular file, except that it gets applied on every save. The following mappings are available in this buffer:

  - `gr` to refresh/update the manifest. NOTE: This will disregard any unsaved local changes.
