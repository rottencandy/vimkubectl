Vimkubectl
======

_Manage any Kubernetes resource from Vim._

![Screenshot](https://i.imgur.com/etLfz3x.png)

Vimkubectl is a plugin for Vim8.1+ and NeoVim which provides a set of commands and mappings to view and manipulate any valid Kubernetes resource from inside Vim.


Installation
------------

Use your favourite plugin manager.

Or use Vim8's built-in package support:
```sh
git clone git@github.com/rottencandy/vimkubectl.git ~/.vim/pack/plugins/start/vimkubectl
```

Help tag files can be generated inside Vim using `:helptags ALL`.


Usage
-----

Make sure your Kubernetes cluster is reachable and configured using `kubectl` or a similar command.(see [configuration](#configuration))

- `:Kget {resource}`

  Get a list of all objects of type `{resource}`. If `{resource}` is not given, `pod` is used.

  You can also use `<Tab>` for completion and to cycle through possible resources.

  - `gr` to refresh/update the list of resources.

  - `ii` (think, "insert mode") to open and edit the manifest of the resource under cursor, in the current window(opens in `YAML` format)

  - `is` to open in a split.

  - `iv` to open in a vertical split.

  - `it` to open in a new tab.

  - `dd` to delete the resource under cursor. (Prompts for confirmation)

- `:Kedit {resource} {object}`

  Open a split containing the manifest of `{object}` of type `{resource}`. Also has `<Tab>` completion.

- The opened manifest can be edited just like a regular file, except that it gets applied on every save.

  The following mappings are available in these buffers:

  - `gr` to refresh/update the manifest. Note that this will disregard any unsaved local changes.

  - `:Ksave {filename}` to save the manifest locally. If `{filename}` is not given, the resource object name is used.

- `:Knamespace {name}`

  Change the currently selected namespace to `{name}`. If `{name}` is not given, prints the currently used namespace.

  `<Tab>` completion can be used to cycle through available namespaces.

- `:{range}Kapply`

  Apply file contents. When used with a selection(`{range}`), applies the selected content, else applies the entire file.
  Can be used on any open buffer.

Configuration
------------

If your `kubectl` command is under a different name, or you are using an alternate command, it can be specified with `g:vimkubectl_command`.

For example to specify OpenShift's `oc` as the command, add this to your `vimrc`:
```
let g:vimkubectl_command = 'oc'
```

The maximum wait time, or the amount of time to wait for the cluster to return, can be specified with `g:vimkubectl_timeout`. The default timeout limit is `5` seconds.

For example, to change the wait time to `10` seconds:
```
let g:vimkubectl_timeout = 10
```


License
-------

MIT
