# Elixir Language Server (ElixirLS) [![Actions Status](https://img.shields.io/github/actions/workflow/status/elixir-lsp/elixir-ls/ci.yml?branch=master)](github/actions/workflow/status/elixir-lsp/elixir-ls/ci.yml?branch=master)

The Elixir Language Server provides a server that runs in the background, providing IDEs, editors, and other tools with information about Elixir Mix projects. It adheres to the [Language Server Protocol](https://github.com/Microsoft/language-server-protocol), a standard for frontend-independent IDE support. Debugger integration is accomplished through the similar [VS Code Debug Protocol](https://code.visualstudio.com/docs/extensionAPI/api-debugging).

## This is the main elixir-ls repo

The [elixir-lsp](https://github.com/elixir-lsp)/[elixir-ls](https://github.com/elixir-lsp/elixir-ls) repo began as a fork when the original repo at [JakeBecker](https://github.com/JakeBecker)/[elixir-ls](https://github.com/JakeBecker/elixir-ls) became inactive for an extended period of time. So, we decided to start an active fork to merge dormant PR's and fix issues where possible. We also believe in an open and shared governance model to share the work instead of relying on one person to shoulder the whole burden.

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

Note: On its first run, Dialyzer will build a PLT cache.  This will take a considerable amount of CPU time (usually 10+ minutes). After that is complete, the CPU usage will go back to normal. Alternatively, instead of waiting you can disable Dialyzer in the settings.

## IDE plugins

| IDE          | Plugin                                                                                             | Support                                                               |
| ------------ | -------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------- |
| BBEdit       | [bbpackage](https://github.com/chipotle/Elixir.bbpackage)                                          |                                                                            |
| Emacs        | [eglot](https://github.com/joaotavora/eglot)                                                       |                                                                            |
| Emacs        | [lsp-mode](https://github.com/emacs-lsp/lsp-mode)                                                  | Supports debugger via [dap-mode](https://github.com/yyoncho/dap-mode) |
| Kakoune      | [kak-lsp](https://github.com/kak-lsp/kak-lsp)                                                      | [Limitations](https://github.com/kak-lsp/kak-lsp/#limitations)        |
| Kate         | [built-in LSP Client plugin](https://kate-editor.org/post/2020/2020-01-01-kate-lsp-client-status/) | Does not support debugger                                                  |
| Neovim       | [coc.nvim](https://github.com/neoclide/coc.nvim)                                                   | Does not support debugger                                                  |
| Neovim       | [nvim-dap](https://github.com/mfussenegger/nvim-dap)                                               | Supports debugger only                                                |
| Neovim       | [nvim-lspconfig](https://github.com/neovim/nvim-lspconfig)                                         | Does not support debugger                                                  |
| Nova         | [nova-elixir-ls](https://github.com/raulchedrese/nova-elixir-ls)                                   |                                                                            |
| Sublime Text | [LSP-elixir](https://github.com/sublimelsp/LSP-elixir)                                             | Does not support debugger                                                  |
| Vim/Neovim   | [ALE](https://github.com/w0rp/ale)                                                                 | Does not support debugger or @spec suggestions                             |
| Vim/Neovim   | [elixir-lsp/coc-elixir](https://github.com/elixir-lsp/coc-elixir)                                  | Does not support debugger                                                  |
| Vim/Neovim   | [vim-lsp](https://github.com/prabirshrestha/vim-lsp)                                               | Does not support debugger                                                  |
| VS Code      | [elixir-lsp/vscode-elixir-ls](https://github.com/elixir-lsp/vscode-elixir-ls)                      | Supports all ElixirLS features                                        |

Please feel free to create and publish your own client packages and add them to this list!

## Detailed Installation Instructions

The installation process for ElixirLS depends on your editor.

<details>
  <summary>VSCode</summary>

Please install the extension via the following link: https://marketplace.visualstudio.com/items?itemName=JakeBecker.elixir-ls

</details>

<details>
  <summary>Emacs Installation Instructions</summary>

Download the
[latest release](https://github.com/elixir-lsp/elixir-ls/releases/latest) and unzip it into a
directory. (This is the directory referred to as the `"path-to-elixir-ls/release"`, below.)

If you will be using `lsp-mode`, add this configuration:

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

For `eglot`, use:

```elisp
(require 'eglot)

;; This is optional. It automatically runs `M-x eglot` for you whenever you are in `elixir-mode`:
(add-hook 'elixir-mode-hook 'eglot-ensure)

;; Be sure to edit the path appropriately; use the `.bat` script instead for Windows:
(add-to-list 'eglot-server-programs '(elixir-mode "path-to-elixir-ls/release/language_server.sh"))
```

</details>

## Supported Elixir and OTP versions

Elixir itself supports five versions with security updates:
https://hexdocs.pm/elixir/compatibility-and-deprecations.html#content

OTP supports the last three versions:
http://erlang.2086793.n4.nabble.com/OTP-Versions-and-Maint-Branches-td4722416.html

ElixirLS generally aims to support the last three released versions of Elixir and the last three versions of OTP. However this is not a hard and fast rule and may change in the future.

### Support matrix

|  OTP Versions   | Elixir Versions | Supports ElixirLS |                          Issue(s)                          |
| :-------------: | :-------------: | :---------------: | :--------------------------------------------------------: |
|      any        |     <= 1.12     |        No         |                No support for Code.Fragment                |
|      22         |       1.13      |        Yes        |         Erlang docs not working (requires EIP 48)          |
|      23         |   1.13 - 1.14   |        Yes        |                            None                            |
|      24         |   1.13 - 1.15   |        Yes        |                            None                            |
|      25         |  1.13.4 - 1.15  |        Yes        |                            None                            |
| 26.0.0 - 26.0.1 |       any       |        No         | [#886](https://github.com/elixir-lsp/elixir-ls/issues/886) |
|   >= 26.0.2     |  1.14.5 - 1.15  |    *nix only      | https://github.com/elixir-lsp/elixir-ls/issues/927         |

### Version management

It is generally recommended to install Elixir and Erlang via [ASDF](https://github.com/asdf-vm/asdf) so that you can have different projects using different versions of Elixir without having to change your system-installed version. ElixirLS can detect and use the versions of Elixir and Erlang that you have configured in ASDF.

## Debugger support

ElixirLS provides debugger support adhering to the [Debug Adapter Protocol](https://microsoft.github.io/debug-adapter-protocol/), which is closely related to the Language Server Protocol.

When debugging in Elixir or Erlang, only modules that have been "interpreted" (using `:int.ni/1` or `:int.i/1`) will accept breakpoints or show up in stack traces. The debugger in ElixirLS automatically interprets all modules in the Mix project and its dependencies before launching the Mix task. Therefore, you can set breakpoints anywhere in your project or dependency modules.

Please note that there is currently a limit of 100 breakpoints.

To debug modules in `.exs` files (such as tests), they must be specified under `requireFiles` in your launch configuration so that they can be loaded and interpreted before running the task. For example, the default launch configuration for `mix test` in the VSCode plugin is shown below:

```json
{
  "type": "mix_task",
  "name": "mix test",
  "request": "launch",
  "task": "test",
  "taskArgs": ["--trace"],
  "startApps": true,
  "projectDir": "${workspaceRoot}",
  "requireFiles": ["test/**/test_helper.exs", "test/**/*_test.exs"]
}
```

Currently, to debug a single test or a single test file, it is necessary to modify `taskArgs` and ensure that no other tests are required in `requireFiles`.

```json
{
  "type": "mix_task",
  "name": "mix test",
  "request": "launch",
  "task": "test",
  "taskArgs": ["tests/some_test.exs:123"],
  "startApps": true,
  "projectDir": "${workspaceRoot}",
  "requireFiles": ["test/**/test_helper.exs", "test/some_test.exs"]
}
```

### Debugging Phoenix apps

To debug Phoenix applications using ElixirLS, you can use the following launch configuration:

```json
{
  "type": "mix_task",
  "name": "phx.server",
  "request": "launch",
  "task": "phx.server",
  "projectDir": "${workspaceRoot}"
}
```

Please make sure that `startApps` is not set to `true`. To clarify, `startApps` is a configuration option in the ElixirLS debugger. It controls whether or not to start the applications in the Mix project before running the task. In the case of Phoenix applications, setting `startApps` to `true` can interfere with the application's normal startup process and cause issues.

If you are running tests in the Phoenix application, you may need to set `startApps` to true. This will ensure that the necessary applications are started before the tests run.

### NIF modules limitation

It's important to note that NIF (Native Implemented Function) modules cannot be interpreted due to limitations in `:int`. Therefore, these modules need to be excluded, using the `excludeModules` option. This option can also be used to disable interpretation for specific modules when it's not desirable, such as when performance is unsatisfactory.

```json
{
  "type": "mix_task",
  "name": "mix test",
  "request": "launch",
  "task": "test",
  "taskArgs": ["--trace"],
  "projectDir": "${workspaceRoot}",
  "requireFiles": ["test/**/test_helper.exs", "test/**/*_test.exs"],
  "excludeModules": [":some_nif", "Some.SlowModule"]
}
```

### Function breakpoints

Function breakpoints in ElixirLS allow you to break on the first line of every clause of a specific function. In order to set a function breakpoint, you need to specify the function in the format of MFA (module, function, arity).

For example, to set a function breakpoint on the `foo` function in the `MyModule` module that takes one argument, you would specify it as `MyModule.foo/1`.

Please note that function breakpoints only work for public functions and do not support breaking on private functions.

### Conditional breakpoints

Break conditions allow you to specify an expression that, when evaluated, determines whether the breakpoint should be triggered or not. The expression is evaluated within the context of the breakpoint, which includes all bound variables.

For example, you could set a breakpoint on a line of code that sets a variable `x`, adding a break condition of `x > 10`. This would cause the breakpoint to trigger when that line of code is executed, but only if the value of `x` is greater than `10` when that line of code is executed.

However, it's important to note that the expression evaluator used by ElixirLS has some limitations. For example, it doesn't support some Elixir language features, such as macros and some built-in functions. In addition, the expression evaluator is not as powerful as the one used by the Elixir interpreter, so some expressions that work in the interpreter may not work in ElixirLS.

### Hit conditions

A "hit condition" is an optional parameter that can be set on a breakpoint to control how many times a breakpoint should be hit before stopping the process. It is expressed as an integer and can be used to filter out uninteresting hits, allowing the process to continue until a certain condition is met.

For example, if you have a loop that runs 10 times and you want to stop the process only when the loop reaches the 5th iteration, you can set a breakpoint with a hit condition of five. This will cause the breakpoint to be hit only on the 5th iteration of the loop; the process will continue to run until then.

### Log points

"Log points" are a type of breakpoint that logs a message to the standard output without stopping program execution. When a log point is hit, the message is evaluated and printed to the console. The message can include interpolated expressions enclosed in curly braces `{}`, e.g. `my_var is {inspect(my_var)}`. These expressions will be evaluated in the context of the breakpoint. To escape the curly braces, you can use the escape sequence `\{` and `\}`.

It's important to note that as of version 1.51 of the Debug Adapter Protocol specification, log messages are not supported on function breakpoints.

### Expression evaluator

The debugger's expression evaluator has some limitations due to how the Erlang VM works. Specifically, the evaluator is implemented using `:int`, which works at the level of individual BEAM instructions. As a result, it returns multiple versions of variables in Static Single Assignment form, without indicating which one is valid in the current Elixir scope.

To work around this, the evaluator uses a heuristic to select the highest versions of variables. However this doesn't always behave correctly in all cases. For example, in the following code snippet:

```elixir
a = 4
if true do
  a = 5
end
some
```

If a breakpoint is set on the line with `some_function()`, the last bound value for `a` seen by the expression breakpoint evaluator will be `5`, even though it should be `4`.

Additionally, although all bound variables are accessible in the expression evaluator, the evaluator doesn't support accessing module attributes (because these are determined at compile time).

### Connecting to debugger

It may be useful to connect to a running debugger node via OTP distribution. This enables inspecting the running application and remotely triggering debugged functions. In order to do so, set `ELS_ELIXIR_OPTS` in the launch configuration and pass in the appropriate node `name/sname` and `cookie`.

```json
{
  "env": {
    "ELS_ELIXIR_OPTS": "--name mynode@localhost --cookie secret"
  }
}
```

## Automatic builds and error reporting

ElixirLS provides automatic builds and error reporting. By default, builds are triggered automatically when files are saved, but you can also enable "autosave" in your IDE to trigger builds as you type. If you prefer to disable automatic builds, you can set the `elixirLS.autoBuild` configuration option to `false`.

Internally, ElixirLS uses the `mix compile` task to compile Elixir code. When errors or warnings are encountered during compilation, they are returned as LSP diagnostics. Your IDE may display them inline in your code as well as in the "Problems" pane. This allows you to quickly identify and fix errors in your code as you work.

## Dialyzer integration

[Dialyzer](http://erlang.org/doc/apps/dialyzer/dialyzer_chapter.html) is a static analysis tool used to identify type discrepancies, unused code, unreachable code, and other warnings in Erlang and Elixir code. ElixirLS provides automatic integration with Dialyzer to help catch issues early on in the development process.

After each successful build, ElixirLS automatically analyzes the project with Dialyzer and maintains a "manifest" file in .elixir_ls/dialyzer_manifest to store the results of the analysis. The initial analysis of a project can take a few minutes, but subsequent analyses are usually very fast, often taking less than a second. ElixirLS also looks at your modules' abstract code to determine whether they reference any modules that haven't been analyzed and includes them automatically.

You can control which warnings are shown by using the `elixirLS.dialyzerWarnOpts` setting in your project or IDE's `settings.json`. You can find available options in [dialyzer documentation](http://erlang.org/doc/man/dialyzer.html), under the section "Warning options".

To disable Dialyzer completely, set `elixirLS.dialyzerEnabled` to false.

If Dialyzer gets stuck and emits incorrect or outdated warnings, it's best to restart the language server.

## Code completion

ElixirLS provides an advanced code completion provider, which is built on top of the [Elixir Sense](https://github.com/elixir-lsp/elixir_sense) library. This provider uses two main mechanisms to provide suggestions to the user.

The first mechanism is reflection, which involves getting information about compiled modules from the Erlang and Elixir APIs. This mechanism provides precise results, but it is not well suited for on-demand completion of symbols from the currently edited file. The compiled version of the code may be outdated or the file may not even compile, which can lead to inaccurate results.

The second mechanism used by the code completion provider is AST analysis of the current text buffer. This mechanism helps in cases where reflection is not accurate enough (e.g., completing symbols from the currently edited file). However, it also has its limitations. Due to the metaprogramming-heavy nature of Elixir, it is infeasible to be 100% accurate with AST analysis.

The completions include:

- keywords
- special form snippets
- functions
- macros
- modules
- variables
- sigils
- struct fields (only if the struct type is explicitly stated or can be inferred from the variable binding)
- atom map keys (if map keys can be inferred from variable binding)
- attributes
- binary modifiers
- types (in typespecs)
- behaviour callbacks (inside the body of implementing module)
- protocol functions (inside the body of implementing module)
- keys in keyword functions arguments (if defined in spec)
- function returns (if defined in spec)

## Workspace Symbols

With Dialyzer integration enabled, ElixirLS will build an index of symbols (modules, functions, types, and callbacks). The symbols are taken from the current workspace, all dependencies, and stdlib (Elixir and Erlang). This feature enables quick navigation to symbol definitions.

## ElixirLS configuration settings

Below is a list of configuration options supported by the ElixirLS language server. Please refer to your editor's documentation to determine how to configure language servers.

<dl>
<dt>elixirLS.autoBuild</dt><dd>Trigger ElixirLS build when code is saved.</dd>
<dt>elixirLS.dialyzerEnabled</dt><dd>Run ElixirLS's rapid Dialyzer when code is saved.</dd>
<dt>elixirLS.dialyzerWarnOpts</dt><dd>Dialyzer options to enable or disable warnings - See Dialyzer's documentation for options. Note that the `race_conditions` option is unsupported.</dd>
<dt>elixirLS.dialyzerFormat</dt><dd>Formatter to use for Dialyzer warnings</dd>
<dt>elixirLS.envVariables</dt><dd>Environment variables to use for compilation</dd>
<dt>elixirLS.mixEnv</dt><dd>Mix environment to use for compilation</dd>
<dt>elixirLS.mixTarget</dt><dd>Mix target to use for compilation</dd>
<dt>elixirLS.projectDir</dt><dd>Subdirectory containing the Mix project, if it is not in the project root</dd>
<dt>elixirLS.fetchDeps</dt><dd>Automatically fetch project dependencies when compiling.</dd>
<dt>elixirLS.suggestSpecs</dt><dd>Suggest `@spec` annotations inline, using Dialyzer's inferred success typings (Requires Dialyzer).</dd>
<dt>elixirLS.trace.server</dt><dd>Traces communication between VS Code and the Elixir language server.</dd>
<dt>elixirLS.autoInsertRequiredAlias</dt><dd>Enable auto-insert required alias - By default, this option is true (enabled).</dd>
<dt>elixirLS.signatureAfterComplete</dt><dd>Show signature help after confirming autocomplete.</dd>
<dt>elixirLS.enableTestLenses</dt><dd>Show code lenses to run tests in terminal.</dd>
<dt>elixirLS.additionalWatchedExtensions</dt><dd>Additional file types capable of triggering a build on change</dd>
<dt>elixirLS.languageServerOverridePath</dt><dd>Absolute path to an alternative ElixirLS release that will override the packaged release</dd>
</dl>

## Debugger configuration options

Below is a list of configuration options supported by the ElixirLS Debugger. Configuration options can be supplied via the debugger launch configuration. Please refer to your editor's documentation on how to configure debugger adapters.

<dl>
  <dt>startApps</dt><dd>Run `mix app.start` before launching the debugger. Some tasks (such as Phoenix tests) expect apps to already be running before the test files are required.</dd>
  <dt>task</dt><dd>Mix task to run with debugger - Defaults to task set under `:default_task` key in mixfile.</dd>
  <dt>taskArgs</dt><dd>A list of arguments to mix task</dd>
  <dt>debugAutoInterpretAllModules</dt><dd>Auto interpret all modules from project build path. Defaults to `true`.</dd>
  <dt>env</dt><dd>An object with environment variables - To set Object keys, specify environment variables; values should be strings.</dd>
  <dt>stackTraceMode</dt><dd>Debugger stacktrace mode - Allowed values are `all`, `no_tail`, and `false`.</dd>
  <dt>requireFiles</dt><dd>A list of additional files that should be required and interpreted - This is especially useful for debugging tests.</dd>
  <dt>debugInterpretModulesPatterns</dt><dd>A list of globs specifying modules that should be interpreted</dd>
  <dt>projectDir</dt><dd>An absolute path to the directory where `mix.exs` is located - In VSCode, `${workspaceRoot}` can be used.</dd>
  <dt>excludeModules</dt><dd>A list of modules that should not be interpreted</dd>
  <dt>exitAfterTaskReturns</dt><dd>Should the debug session stop when mix task returns. Tasks that return early while the code continues running asynchronously require `false` setting. Defaults to `true`.</dd>
</dl>

## Troubleshooting

Basic troubleshooting steps:

- Make sure you have `hex` and `git` installed.
- Make sure `github.com` and `hex.pm` are accessible. You may need to configure an HTTPS proxy. If your setup uses TLS man-in-the-middle inspection, you may need to set `HEX_UNSAFE_HTTPS=1`.
- If ElixirLS fails to start, you can try cleaning the `Mix.install` directory (location on your system can be obtained by calling `Path.join(Mix.Utils.mix_cache(), "installs")` from `iex` session)
- Restart ElixirLS with the custom command `restart`.
- Run `mix clean` or `mix clean --deps` in ElixirLS with the custom command `mixClean`.
- Restart your editor (which will restart ElixirLS).
- After stopping your editor, remove the entire `.elixir_ls` directory, then restart your editor.
  - NOTE: This will cause you to have to re-run the entire dialyzer build.

You may need to set `elixirLS.mixEnv`, `elixirLS.mixTarget`, and `elixirLS.projectDir` if your project requires this. By default, ElixirLS compiles code with `MIX_ENV=test` and `MIX_TARGET=host`; it assumes that `mix.exs` is located in the workspace root directory.

If you get an error like the following immediately on startup:

```
[Warn  - 1:56:04 PM] ** (exit) exited in: GenServer.call(ElixirLS.LanguageServer.JsonRpc, {:packet, %{...snip...}}, 5000)
    ** (EXIT) no process: the process is not alive or there's no process currently associated with the given name, possibly because its application isn't started
```

and you installed Elixir and Erlang from the Erlang Solutions repository, you may not have a full installation of Erlang. This can be solved with `sudo apt-get install esl-erlang`. (This was originally reported in [#208](https://github.com/elixir-lsp/elixir-ls/issues/208).)

On Fedora Linux, if you only install the Elixir package you will not have a full Erlang installation. This can be fixed by running `sudo dnf install erlang` (This was reported in [#231](https://github.com/elixir-lsp/elixir-ls/issues/231).)

If you are seeing the message "Invalid beam file or no abstract code", you need to make sure that your Mix project is set to use the `elixirc` compiler option `--debug-info`, which can be done by adding the following line to your `mix.exs` `project` section:

```
elixirc_options: [debug_info: Mix.env() == :dev]
```

For example:

```
defmodule MyApp.MixProject do
  use Mix.Project

  def project do
    [
      app: :my_app,
      version: "0.1.0",
      elixir: "~> 1.11",
      elixirc_paths: elixirc_paths(Mix.env()),
      elixirc_options: [debug_info: Mix.env() == :dev],
    ...
```

If you are using Emacs with `lsp-mode`, there's a possibility that you have set the
wrong directory as the project root (especially if that directory does not have
a `mix.exs` file). To fix that, you should remove the project and re-initialize:
https://github.com/elixir-lsp/elixir-ls/issues/364#issuecomment-829589139

## Known Issues/Limitations

- `.exs` files don't return compilation errors.
- "Fetching n dependencies" sometimes get stuck (remove the `.elixir_ls` directory to fix).
- "Go to definition" does not work within the `scope` of a Phoenix router.
- On first launch, Dialyzer will cause high CPU usage for a considerable time.
- Dialyzer does not pick up changes involving remote types (https://github.com/elixir-lsp/elixir-ls/issues/502)

## Building and running

There are two ways of building the release: `Mix.install` based (recommended) and `.ez` archives (deprecated).

### `Mix.install` based release

```bash
mix deps.get
MIX_ENV=prod mix compile
MIX_ENV=prod mix elixir_ls.release2 -o <release_dir>
```

This copies language server and debugger adapter launch scripts to the `<release_dir>` and includes a `VERSION` manifest file. The launch scripts install a release specified by the version manifest via `Mix.install` and then launch it. This ensures that ElixirLS is built with the correct combination of Elixir and OTP.

### Deprecated `.ez` archives release

```bash
mix deps.get
MIX_ENV=prod mix compile
MIX_ENV=prod mix elixir_ls.release -o <release_dir>
```

This builds the language server and debugger as a set of `.ez` archives and creates `.sh` and `.bat` scripts to launch them.

If you're packaging these archives in an IDE plugin, be sure to build using the minimum supported OTP version. This will provide the best backwards compatibility.

### Local setup

This section provides additional information on how to set up the ElixirLS locally.

When launching ElixirLS from an IDE that is itself launched from a graphical shell, the environment may not be complete enough to find or run the correct Elixir/OTP version. To address this on Unix or Linux, the ElixirLS wrapper scripts try to configure [ASDF](https://github.com/asdf-vm/asdf) (a version manager for Elixir and other languages), but that may not always be what is needed.

To ensure that the correct environment is set up, you can create a setup script at `$XDG_CONFIG_HOME/elixir_ls/setup.sh` (for Unix-based systems) or `%APPDATA%\elixir_ls\setup.bat` (for Windows).

In the setup script, the environment variable `ELS_MODE` is available and set to either `debugger` or `language_server` to help you decide what to do.

Note: The setup script must not read from `stdin` or write to `stdout`. On Unix, Linux, and macOS
this might be accomplished by adding `>/dev/null` at the end of any line that produces
output; for a Windows batch script, you will want to add `@echo off` at the top and use `>nul`.

### Development

Please refer to [DEVELOPMENT.md](DEVELOPMENT.md).

## Environment variables

ElixirLS supports the following environment variables.

<dl>

  <dt>ELS_INSTALL_PREFIX</dt><dd>(not supported on Windows) The folder where the language server was installed - If set, this makes maintaining multiple versions/instances on the same host much easier. If it is not set or empty, a heuristic will be used to discover the install location.</dd>

  <dt>ELS_LOCAL</dt><dd>If set to `1`, this will make ElixirLS run a local release. If this is not set, a published release matching `VERSION` will be used (default).</dd>

  <dt>ELS_ELIXIR_OPTS</dt><dd>Optional parameters to pass to elixir CLI - May be used to set a node name and cookie.</dd>

  <dt>ELS_ERL_OPTS</dt><dd>Optional parameters to pass to the erl CLI</dd>

  <dt>ASDF_DIR</dt><dd>(not supported on Windows) If this is set, ElixirLS will look for the [ASDF](https://github.com/asdf-vm/asdf) script in a directory given by that variable.</dd>

</dl>

## Acknowledgements and related projects

ElixirLS isn't the first frontend-independent server for Elixir language support. The original was [Alchemist Server](https://github.com/tonini/alchemist-server/), which powers the [Alchemist](https://github.com/tonini/alchemist.el) plugin for Emacs. Another project, [Elixir Sense](https://github.com/elixir-lsp/elixir_sense), builds upon Alchemist and powers the [Elixir plugin for Atom](https://github.com/msaraiva/atom-elixir) as well as another VS Code plugin, [VSCode Elixir](https://github.com/fr1zle/vscode-elixir). ElixirLS uses Elixir Sense for several code insight features. Credit for those projects goes to their respective authors.

## License

ElixirLS source code is released under Apache License 2.0.

See [LICENSE](LICENSE) for more information.
