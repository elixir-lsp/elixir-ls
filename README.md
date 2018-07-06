# Elixir Language Server (ElixirLS)

The Elixir Language Server provides a server that runs in the background, providing IDEs, editors, and other tools with information about Elixir Mix projects. It adheres to the [Language Server Protocol](https://github.com/Microsoft/language-server-protocol), a standard for frontend-independent IDE support. Debugger integration is accomplished through the similar [VS Code Debug Protocol](https://code.visualstudio.com/docs/extensionAPI/api-debugging).

## Features

- Debugger support (requires Erlang >= OTP 19)
- Automatic, incremental Dialyzer analysis (requires Erlang OTP 20)
- Inline reporting of build warnings and errors (requires Elixir >= 1.6)
- Documentation lookup on hover
- Go-to-definition
- Code completion
- Code formatter (requries Elixir >= 1.6)
- Find references to functions and modules (Thanks to @mattbaker)
- Quick symbol lookup in file (Thanks to @mattbaker)

![Screenshot](images/screenshot.png?raw=true)

## Supported versions

Elixir:
- 1.6.0 minimum
- \>= 1.6.6 recommended

Erlang:
- OTP 18 minimum
- >= OTP 20 recommended

You may want to install Elixir and Erlang from source, using the [kiex](https://github.com/taylor/kiex) and [kerl](https://github.com/kerl/kerl) tools. This will let you go-to-definition for core Elixir and Erlang modules.

## IDE plugins

| IDE      | Plugin                                                                        | Support                                 |
|----------|-------------------------------------------------------------------------------|-----------------------------------------|
| VS Code  | [JakeBecker/vscode-elixir-ls](https://github.com/JakeBecker/vscode-elixir-ls) | Supports all ElixirLS features          |
| Atom IDE | [JakeBecker/ide-elixir](https://github.com/JakeBecker/ide-elixir)             | Does not support debugger or output log |

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

Starting in Elixir 1.6, Mix compilers adhere to the [Mix.Task.Compiler](https://hexdocs.pm/mix/master/Mix.Task.Compiler.html) behaviour and return their error and warning diagnostics in a standardized way. If you're using Elixir >= 1.6, errors and warnings will be shown inline in your code as well as in the "Problems" pane in the IDE. If you're using an earlier version of Elixir, you'll need to look at the text log from the extension to see the errors and warnings.

## Dialyzer integration

If you're using Erlang >= OTP 20, ElixirLS will automatically analyze your project with Dialyzer after each successful build. It maintains a "manifest" file in `.elixir_ls/dialyzer_manifest` that stores the results of the analysis. The initial analysis for a project can take a few minutes, but after that's completed, modules are re-analyzed only if necessary, so subsequent analyses are typically very fast -- often less than a second. It also looks at your modules' abstract code to determine whether they reference any modules that haven't been analyzed and includes them automatically.

You can control which warnings are shown using the `elixirLS.dialyzerWarnOpts` setting in your project or IDE's `settings.json`. To disable it completely, set `elixirLS.dialyzerEnabled` to false.

ElixirLS's Dialyzer integration uses internal, undocumented Dialyzer APIs, and so it won't be robust against changes to these APIs in future Erlang versions.


## Building and running

Run `mix compile`, then `mix elixir_ls.release -o <release_dir>`. This builds the language server and debugger as a set of `.ez` archives and creates `.sh` and `.bat` scripts to launch them.

If you're packaging these archives in an IDE plugin, make sure to build using Erlang/OTP 19, not OTP 20, because OTP 20 beam files are not backwards-compatible with earlier Erlang versions. Alternatively, you can use a [precompiled release](https://github.com/JakeBecker/elixir-ls/releases).

## Acknowledgements and related projects

ElixirLS isn't the first frontend-independent server for Elixir language support. The original was [Alchemist Server](https://github.com/tonini/alchemist-server/), which powers the [Alchemist](https://github.com/tonini/alchemist.el) plugin for Emacs. Another project, [Elixir Sense](https://github.com/msaraiva/elixir_sense), builds upon Alchemist and powers the [Elixir plugin for Atom](https://github.com/msaraiva/atom-elixir) as well as another VS Code plugin, [VSCode Elixir](https://github.com/fr1zle/vscode-elixir). ElixirLS uses Elixir Sense for several code insight features. Credit for those projects goes to their respective authors.
