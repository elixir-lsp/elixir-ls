# Elixir Language Server (ElixirLS)

<!-- markdown-toc start - Don't edit this section. Run M-x markdown-toc-refresh-toc -->
**Table of Contents**

- [Elixir Language Server (ElixirLS)](#elixir-language-server-elixirls)
    - [This is now the main elixir-ls repo](#this-is-now-the-main-elixir-ls-repo)
    - [Features](#features)
    - [Installing](#installing)
        - [Homebrew](#homebrew)
        - [Manual](#manual)
        - [Local setup](#local-setup)
    - [Environment variables](#environment-variables)
    - [Acknowledgements and related projects](#acknowledgements-and-related-projects)
    - [License](#license)

<!-- markdown-toc end -->

The Elixir Language Server provides a server that runs in the background, providing IDEs, editors, and other tools with information about Elixir Mix projects. It adheres to the [Language Server Protocol](https://github.com/Microsoft/language-server-protocol), a standard for frontend-independent IDE support. Debugger integration is accomplished through the similar [VS Code Debug Protocol](https://code.visualstudio.com/docs/extensionAPI/api-debugging).

Full feature overview, as well as detailed install instructions per editor are on the official docsite:

<https://elixir-lsp.github.io/elixir-ls/>

## This is now the main elixir-ls repo

The [elixir-lsp](https://github.com/elixir-lsp)/[elixir-ls](https://github.com/elixir-lsp/elixir-ls) repo began as a fork when the original repo at [JakeBecker](https://github.com/JakeBecker)/[elixir-ls](https://github.com/JakeBecker/elixir-ls) became inactive for an extended period of time. So we decided to start an active fork to merge dormant PR's and fix issues where possible. We also believe in an open and shared governance model to share the work instead of relying on one person to shoulder the whole burden.

The original repository has now been deprecated in favor of this one. Any IDE extensions that use ElixirLS should switch to using this repository.

## Features

- Debugger support
- Automatic, incremental Dialyzer analysis
- Automatic inline suggestion of @specs based on Dialyzer's inferred success typings
- Inline reporting of build warnings and errors
- Documentation lookup on hover
- Go-to-definition
- Code completion
- Code formatter
- Find references to functions and modules (Thanks to @mattbaker)
- Quick symbol lookup in file (Thanks to @mattbaker)
- Quick symbol lookup in workspace and stdlib (both Elixir and erlang) (@lukaszsamson)

![Screenshot](images/screenshot.png?raw=true)

Note: On first run Dialyzer will build a PLT cache which will take a considerable amount of CPU time (usually 10+ minutes). After that is complete the CPU usage will go back to normal. Alternatively instead of waiting you can disable Dialyzer in the settings.

## Installing

### Homebrew

If you use [Homebrew](https://brew.sh), you can install `elixir-ls` by running

```bash
brew update
brew install elixir-ls
```

Your editor will either find the Language Server automatically, or you have to configure your LSP plugin manually. Check the [editor specific install instructions](https://elixir-lsp.github.io/elixir-ls/getting-started/overview/) for more info.

### Manual

You can use a [precompiled release](https://github.com/elixir-lsp/elixir-ls/releases).

Alternatively, you can build from source:

```bash
MIX_ENV=prod mix compile
mix elixir_ls.release -o <release_dir>
```

This builds the language server and debugger as a set of `.ez` archives and creates `.sh` and `.bat` scripts to launch them.

If you're packaging these archives in an IDE plugin, make sure to build using the minimum supported OTP version for the best backwards-compatibility. 

### Local setup

Because ElixirLS may get launched from an IDE that itself got launched from a graphical shell, the environment may not
be complete enough to run or even find the correct Elixir/OTP version. The wrapper scripts try to configure `asdf-vm`
if available, but that may not be what you want or need. Therefore, prior to executing Elixir, the script will source
`$XDG_CONFIG_HOME/elixir_ls/setup.sh` (e.g. `~/.config/elixir_ls/setup.sh`), if available. The environment variable
`ELS_MODE` is set to either `debugger` or `language_server` to help you decide what to do inside the script, if needed.

Note: for windows the local setup script path is `%APPDATA%/elixir_ls/setup.bat` (which is often `C:\Users\<username>\AppData\Roaming\elixir_ls`)

Note: It is important that the setup script not print any output. On linux this might be
accomplished by adding `>/dev/null` and/or `2>/dev/null` at the end of any line that produces
output, and for a windows batch script you will want `@echo off` at the top and `>nul` on every
line.

## Environment variables

* `ELS_INSTALL_PREFIX`: The folder where the language server got installed to. If set eq. through a wrapper script, it makes maintaining multiple versions/instances on the same host much easier. If not set or empty, a heuristic will be used to discover the install location.

## Acknowledgements and related projects

ElixirLS isn't the first frontend-independent server for Elixir language support. The original was [Alchemist Server](https://github.com/tonini/alchemist-server/), which powers the [Alchemist](https://github.com/tonini/alchemist.el) plugin for Emacs. Another project, [Elixir Sense](https://github.com/elixir-lsp/elixir_sense), builds upon Alchemist and powers the [Elixir plugin for Atom](https://github.com/msaraiva/atom-elixir) as well as another VS Code plugin, [VSCode Elixir](https://github.com/fr1zle/vscode-elixir). ElixirLS uses Elixir Sense for several code insight features. Credit for those projects goes to their respective authors.

## License

ElixirLS source code is released under Apache License 2.0.

See [LICENSE](LICENSE) for more information.
