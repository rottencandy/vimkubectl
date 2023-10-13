Vimkubectl
==========
[![CI badge](https://github.com/rottencandy/vimkubectl/actions/workflows/vint.yml/badge.svg)](https://github.com/rottencandy/vimkubectl/actions/workflows/vint.yml)

A Vim/Neovim plugin to manipulate Kubernetes resources.

![Screenshot of plugin in use](https://i.imgur.com/PwDD7pS.png)

This plugin is a `kubectl` wrapper providing commands and mappings to perform actions on Kubernetes resources.

The following has been implemented so far:
- Fetch and view lists of kubernetes resources
- Edit resource manifests in YAML form
- Apply any file or buffer to the cluster
- Switch namespace
- Delete resources

Installation
------------

This plugin follows the standard runtime path structure,
you can install it with your favourite plugin manager.

Plugin Manager  | Instructions
--------------- | --------------------------------------------------
[NeoBundle][0] | `NeoBundle 'rottencandy/vimkubectl'`
[Vundle][1]    | `Plugin 'rottencandy/vimkubectl'`
[Plug][2]      | `Plug 'rottencandy/vimkubectl'`
[Pathogen][3]  | `git clone https://github.com/rottencandy/vimkubectl ~/.vim/bundle`
Manual          | Copy all of the files into your `~/.vim` directory

Usage
-----

This plugin assumes your Kubernetes cluster is reachable and logged in with [kubectl][4] or [oc][5].(see [configuration](#configuration))

- `:Kget {resource}`

  Get a list of all objects of type `{resource}`. If `{resource}` is not given, `pod` is used.

  You can also use `<Tab>` for completion and to cycle through possible resources.

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

- `:Kns {name}`

  Change the currently selected namespace to `{name}`. If `{name}` is not given, prints the currently used namespace.

  `<Tab>` completion can be used to cycle through available namespaces.

- `:{range}Kapply`

  Apply file contents. When used with a selection(`{range}`), applies the selected content, else applies the entire file.
  Can be used on any open buffer.

- `:K`

  Run any arbitrary `kubectl` command.

Configuration
-------------

- `g:vimkubectl_command`

  **Default: 'kubectl'**

  If you are using an alternate Kubernetes client, it can be specified with `g:vimkubectl_command`.

  For example to use OpenShift's `oc` as the command, add this to your `vimrc`:
  ```
  let g:vimkubectl_command = 'oc'
  ```

- `g:vimkubectl_timeout`

  **Default: 5**

  The maximum time to wait for the cluster to respond to requests.

  For example, to change the wait time to `10` seconds:
  ```
  let g:vimkubectl_timeout = 10
  ```

License
-------

[MIT](LICENSE)

[0]: https://github.com/Shougo/neobundle.vim
[1]: https://github.com/gmarik/vundle
[2]: https://github.com/junegunn/vim-plug
[3]: https://github.com/tpope/vim-pathogen
[4]: https://github.com/kubernetes/kubectl
[5]: https://github.com/openshift/oc
