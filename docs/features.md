# Features

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

## Automatic builds and error reporting

Builds are performed automatically when files are saved. If you want this to happen automatically when you type, you can turn on "autosave" in your IDE.

Starting in Elixir 1.6, Mix compilers adhere to the [Mix.Task.Compiler](https://hexdocs.pm/mix/master/Mix.Task.Compiler.html) behaviour and return their error and warning diagnostics in a standardized way. Errors and warnings will be shown inline in your code as well as in the "Problems" pane in the IDE. If you're using an earlier version of Elixir, you'll need to look at the text log from the extension to see the errors and warnings.

## Dialyzer integration

ElixirLS will automatically analyze your project with [Dialyzer](http://erlang.org/doc/apps/dialyzer/dialyzer_chapter.html) after each successful build. It maintains a "manifest" file in `.elixir_ls/dialyzer_manifest` that stores the results of the analysis. The initial analysis for a project can take a few minutes, but after that's completed, modules are re-analyzed only if necessary, so subsequent analyses are typically very fast -- often less than a second. It also looks at your modules' abstract code to determine whether they reference any modules that haven't been analyzed and includes them automatically.

You can control which warnings are shown using the `elixirLS.dialyzerWarnOpts` setting in your project or IDE's `settings.json`. Find available options in Erlang [docs](http://erlang.org/doc/man/dialyzer.html) at section "Warning options".

To disable Dialyzer completely, set `elixirLS.dialyzerEnabled` to false.

Check usage details in Dialyxir docs on [GitHub](https://github.com/jeremyjh/dialyxir#usage) and [hexdocs](https://hexdocs.pm/dialyxir/readme.html).

ElixirLS's Dialyzer integration uses internal, undocumented Dialyzer APIs, and so it won't be robust against changes to these APIs in future Erlang versions.

## Code completion

ElixirLS bundles an advanced code completion provider. The provider builds on [Elixir Sense](https://github.com/elixir-lsp/elixir_sense) library and utilizes two main mechanisms. The first one is reflection - getting information about compiled modules from Erlang and Elixir APIs. The second one is AST analysis of the current text buffer. While reflection gives precise results, it is not well suited for on demand completion of symbols from the currently edited file. The compiled version is likely to be outdated or the file may not compile at all. AST analysis helps in that case but it has its limitations. Unfortunately it is infeasible to be 100% accurate, especially with Elixir being a metaprogramming heavy language.

The completions include:

- keywords
- special form snippets
- functions
- macros
- modules
- variables
- struct fields (only if the struct type is explicitly stated or can be inferred from the variable binding)
- atom map keys (if map keys can be inferred from variable binding)
- attributes
- types (in typespecs)
- behaviour callbacks (inside the body of implementing module)
- protocol functions (inside the body of implementing module)
- keys in keyword functions arguments (if defined in spec)
- function returns (if defined in spec)

## Workspace Symbols

With Dialyzer integration enabled ElixirLS will build an index of symbols (modules, functions, types and callbacks). The symbols are taken from the current workspace, all dependencies and stdlib (Elixir and erlang). This feature enables quick navigation to symbol definitions.

