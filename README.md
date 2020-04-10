# Elixir Language Server (ElixirLS)

The Elixir Language Server provides a server that runs in the background, providing IDEs, editors, and other tools with information about Elixir Mix projects. It adheres to the [Language Server Protocol](https://github.com/Microsoft/language-server-protocol), a standard for frontend-independent IDE support. Debugger integration is accomplished through the similar [VS Code Debug Protocol](https://code.visualstudio.com/docs/extensionAPI/api-debugging).

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

## Supported versions

Elixir:

- 1.7.0 minimum

Erlang:

- OTP 20 minimum

You may want to install Elixir and Erlang from source, using the [kiex](https://github.com/taylor/kiex) and [kerl](https://github.com/kerl/kerl) tools. This will let you go-to-definition for core Elixir and Erlang modules.

## IDE plugins

| IDE      | Plugin                                                                        | Support                                        |
| -------- | ----------------------------------------------------------------------------- | ---------------------------------------------- |
| VS Code  | [elixir-lsp/vscode-elixir-ls](https://github.com/elixir-lsp/vscode-elixir-ls) | Supports all ElixirLS features                 |
| Atom IDE | [JakeBecker/ide-elixir](https://github.com/JakeBecker/ide-elixir)             | Does not support debugger or @spec suggestions |
| Vim      | [ALE](https://github.com/w0rp/ale)                                            | Does not support debugger or @spec suggestions |
| Neovim   | [ALE](https://github.com/w0rp/ale)                                            | Does not support debugger                      |
| Neovim   | [coc.nvim](https://github.com/neoclide/coc.nvim)                              | Does not support debugger                      |
| Emacs    | [lsp-mode](https://github.com/emacs-lsp/lsp-mode) |      Supports debugger via [dap-mode](https://github.com/yyoncho/dap-mode) |
| Emacs    | [eglot](https://github.com/joaotavora/eglot)                                  |                                                |

Feel free to create and publish your own client packages and add them to this list!

## Debugger support

ElixirLS includes debugger support adhering to the [VS Code debugger protocol](https://code.visualstudio.com/docs/extensionAPI/api-debugging) which is closely related to the Language Server Protocol. At the moment, only line breakpoints are supported.

When debugging in Elixir or Erlang, only modules that have been "interpreted" (using `:int.ni/1` or `:int.i/1`) will accept breakpoints or show up in stack traces. The debugger in ElixirLS automatically interprets all modules in the Mix project and dependencies prior to launching the Mix task, so you can set breakpoints anywhere in your project or dependency modules.

In order to debug modules in `.exs` files (such as tests), they must be specified under `requireFiles` in your launch configuration so they can be loaded and interpreted prior to running the task. For example, the default launch configuration for "mix test" in the VS Code plugin looks like this:

```
{
  "type": "mix_task",
  "name": "mix test",
  "request": "launch",
  "task": "test",
  "taskArgs": ["--trace"],
  "projectDir": "${workspaceRoot}",
  "requireFiles": [
    "test/**/test_helper.exs",
    "test/**/*_test.exs"
  ]
}
```

## Automatic builds and error reporting

Builds are performed automatically when files are saved. If you want this to happen automatically when you type, you can turn on "autosave" in your IDE.

Starting in Elixir 1.6, Mix compilers adhere to the [Mix.Task.Compiler](https://hexdocs.pm/mix/master/Mix.Task.Compiler.html) behaviour and return their error and warning diagnostics in a standardized way. Errors and warnings will be shown inline in your code as well as in the "Problems" pane in the IDE. If you're using an earlier version of Elixir, you'll need to look at the text log from the extension to see the errors and warnings.

## Dialyzer integration

ElixirLS will automatically analyze your project with Dialyzer after each successful build. It maintains a "manifest" file in `.elixir_ls/dialyzer_manifest` that stores the results of the analysis. The initial analysis for a project can take a few minutes, but after that's completed, modules are re-analyzed only if necessary, so subsequent analyses are typically very fast -- often less than a second. It also looks at your modules' abstract code to determine whether they reference any modules that haven't been analyzed and includes them automatically.

You can control which warnings are shown using the `elixirLS.dialyzerWarnOpts` setting in your project or IDE's `settings.json`. To disable it completely, set `elixirLS.dialyzerEnabled` to false.

ElixirLS's Dialyzer integration uses internal, undocumented Dialyzer APIs, and so it won't be robust against changes to these APIs in future Erlang versions.

## Workspace Symbols

With Dialyzer integration enabled ElixirLS will build an index of symbols (modules, functions, types and callbacks). The symbols are taken from the current workspace, all dependencies and stdlib (Elixir and erlang). This feature enables quick navigation to symbol definitions. However due to sheer number of different symbols and fuzzy search utilized by the provider, ElixirLS uses query prefixes to improve search results relevance.

Use the following rules when navigating to workspace symbols:
* no prefix - search for modules
  * `:erl`
  * `Enu`
* `f ` prefix - search for functions
  * `f inse`
  * `f :ets.inse`
  * `f Enum.cou`
  * `f count/0`
* `t ` prefix - search for types
  * `t t/0`
  * `t :erlang.time_u`
  * `t DateTime.`
* `c ` prefix - search for callbacks
  * `c handle_info`
  * `c GenServer.in`
  * `c :gen_statem`

## Troubleshooting

Basic troubleshooting steps:
* Restart your editor (which will restart ElixirLS)
* After stopping your editor, remove the entire `.elixir_ls` directory, then restart your editor
  * NOTE: This will cause you to have to re-run the entire dialyzer build

If your code doesn't compile in ElixirLS, it may be because ElixirLS compiles code with `MIX_ENV=test` (by default). So if you are missing some configuration in the test environment, your code may not compile.

## Known Issues

* `.exs` files don't return compilation errors
* `workspaceSymbolProvider` capability currently requires enabled dialyzer
* "Fetching n dependencies" sometimes get stuck (remove the `.elixir_ls` directory to fix)
* Debugger doesn't work in Elixir 1.10.0 - 1.10.2 (but it should work in 1.10.3 when [this fix](https://github.com/elixir-lang/elixir/pull/9864) is released)
* "Go to definition" does not work within the `scope` of a Phoenix router

## Building and running

Run `mix compile`, then `mix elixir_ls.release -o <release_dir>`. This builds the language server and debugger as a set of `.ez` archives and creates `.sh` and `.bat` scripts to launch them.

If you're packaging these archives in an IDE plugin, make sure to build using the minimum supported OTP version for the best backwards-compatibility. Alternatively, you can use a [precompiled release](https://github.com/JakeBecker/elixir-ls/releases).

## Acknowledgements and related projects

ElixirLS isn't the first frontend-independent server for Elixir language support. The original was [Alchemist Server](https://github.com/tonini/alchemist-server/), which powers the [Alchemist](https://github.com/tonini/alchemist.el) plugin for Emacs. Another project, [Elixir Sense](https://github.com/msaraiva/elixir_sense), builds upon Alchemist and powers the [Elixir plugin for Atom](https://github.com/msaraiva/atom-elixir) as well as another VS Code plugin, [VSCode Elixir](https://github.com/fr1zle/vscode-elixir). ElixirLS uses Elixir Sense for several code insight features. Credit for those projects goes to their respective authors.

## License

ElixirLS source code is released under Apache License 2.0.

See [LICENSE](LICENSE) for more information.
