Vimkubectl
======

Manage Kubernetes resources from Vim.


Installation
------------

Use your favourite plugin manager.

Or use Vim8's built-in package support:
```sh
mkdir -p ~/.vim/pack/local/start
cd ~/.vim/pack/local/start
git clone github.com/rottencandy/vimkubectl.git
```

Help tag files can be generated with `:helptags ALL`.


Usage
-----

Make sure you are logged in to your cluster using `kubectl` or a similar command.

Use `g:vimkubectl_command` to specify the command to use. (default: `kubectl`)

- `:KGet {resource_type}`

  Get a list of all resources that match `{resource_type}`. If `{resource_type}` is not given, `pod` is used.

  You can also use `<Tab>` to cycle through possible resource types.

  - `gr` to refresh/update the list of resources.

  - `ii` (think, "insert mode") to open and edit the manifest of the resource under cursor, in the current window(opens in `YAML` format)

  - `is` to open in a split.

  - `iv` to open in a vertical split..

  - `it` to open in a new tab.

  - `dd` to delete the resource under cursor. (Prompts for confirmation)

- The manifest can be edited just like a regular file, except that it gets applied on every save.

  The following mappings are available in this buffer:

  - `gr` to refresh/update the manifest. Note that this will disregard any unsaved local changes.

  - `:KSave {filename}` to save the manifest to a file. If `{filename}` is not given, the resource name is used.

- `:KNamespace {name}`

  Switch the currently selected namespace to `{name}`. If `{name}` is not given, prints the current namespace.

  `<Tab>` can be used to cycle through available namespaces.

License
-------

MIT
