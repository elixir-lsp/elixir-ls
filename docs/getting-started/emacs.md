# Emacs

## Setup

### Homebrew

If you use [Homebrew](https://brew.sh), you can install `elixir-ls` by running

```bash
brew update
brew install elixir-ls
```

This also makes the server's init script available on `PATH`

If you are using [lsp-mode](https://emacs-lsp.github.io/lsp-mode/), use a configuration similar to this:

```elisp
(use-package lsp-mode
  :commands lsp
  :ensure t
  :diminish lsp-mode
  :hook (elixir-mode . lsp)
  :config
  (setq lsp-elixir-server-command '("elixir-ls")
		lsp-elixir-suggest-specs t))
```

### Manual

Download the latest release:
`https://github.com/elixir-lsp/elixir-ls/releases/latest` and unzip it into a directory (this is the directory referred to as the `"path-to-elixir-ls/release"` below)

If using [lsp-mode](https://emacs-lsp.github.io/lsp-mode/) add this configuration:
```elisp
(use-package lsp-mode
  :commands lsp
  :ensure t
  :diminish lsp-mode
  :hook
  (elixir-mode . lsp)
  :init
  (add-to-list 'exec-path "path-to-elixir-ls/release"))
```

For `eglot` users:
```elisp
(require 'eglot)
;; This is optional. It automatically runs `M-x eglot` for you whenever you are in `elixir-mode`
(add-hook 'elixir-mode-hook 'eglot-ensure)
;; Make sure to edit the path appropriately, use the .bat script instead for Windows
(add-to-list 'eglot-server-programs '(elixir-mode "path-to-elixir-ls/release/language_server.sh"))
```

The official `lsp-mode` package includes a client for the Elixir
Language Server.

Whenever opening a project for the first time, you will be prompted by
`emacs-lsp` to select the correct project root. In that occasion, you
also have the opportunity to _blacklist_ projects. Information about
projects is stored in a file pointed by the `lsp-session-file`
variable. Its default location is `~/.emacs.d/.lsp-session-v1`. You
may need to prune or amend this file if you change your mind about
blacklisting a project or if you erroneously select a project
root. For more information about the `lsp-session-file` and
`emacs-lsp` in general, please refer to the [official
documentation](https://emacs-lsp.github.io/lsp-mode/).

Remember that ElixirLS requires **Erlang/OTP 22** and **Elixir 1.10.0** or
higher to run, so ensure that Erlang and Elixir are available in your `PATH`.
This can be achieved, for example, by using the
[exec-path-from-shell](https://github.com/purcell/exec-path-from-shell)
Emacs package.

## Restarting the language server

You may want to quickly restart the language server for a given
workspace (e.g. after an update or in case of a server crash). To do
so:

```
M-x lsp-workspace-restart
```

## Troubleshooting

To be sure that you don't have outdated or incompatible packages
installed, you may also want to rename your `~/.emacs.d` directory
while you are troubleshooting your ElixirLS Emacs setup.

Also, ensure that Erlang, Elixir (i.e. `erl`, `escript` and friends) and the
`language_server.sh` script are all available in your `PATH`. If they are
not, you can try the following:

```elisp
;; Ensure your Emacs environment looks like your user's shell one
(package-require 'exec-path-from-shell)
(exec-path-from-shell-initialize)
```

Finally, to enable logging on the client-side, just:

```elisp
(setq lsp-log-io t)
```

You can then follow the client logs for the current workspace by doing:

```
M-x lsp-workspace-show-log
```

## Tips and Tricks

### Shortcuts for code lenses and quick actions

You can run `M-x lsp-avy-lens` to show _letters_ next to code
lenses. You can then press those letters to trigger the respective
action.

If your `sideline` is enabled (`(setq lsp-ui-sideline-enable t)`), you
can also use `M-x lsp-execute-code-action` to trigger quick-fix
actions.
