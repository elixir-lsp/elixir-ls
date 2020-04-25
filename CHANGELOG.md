### Unreleased

Improvements:
- Add autocompletion of struct fields on a binding when we know for sure what type of struct it is. (thanks [Łukasz Samson](https://github.com/lukaszsamson)) [#202](https://github.com/elixir-lsp/elixir-ls/pull/202)
  - For details see the [Code Completion section of the readme](https://github.com/elixir-lsp/elixir-ls/tree/a2a1f38bf0f47e074ec5d50636d669fae03a3d5e#code-completion)

Bug Fixes:
- Dialyzer: Get beam file for preloaded modules. (thanks [Łukasz Samson](https://github.com/lukaszsamson)) [#218](https://github.com/elixir-lsp/elixir-ls/pull/218)
- Warn when using the debugger on Elixir 1.10.0-1.10.2. (thanks [Jason Axelson](https://github.com/axelson)) [#221](https://github.com/elixir-lsp/elixir-ls/pull/221)

### v0.3.3: 15 Apr 2020

Meta:
- The original repository at [JakeBecker](https://github.com/JakeBecker)/[elixir-ls](https://github.com/JakeBecker/elixir-ls) has now been deprecated in favor of [elixir-lsp](https://github.com/elixir-lsp)/[elixir-ls](https://github.com/elixir-lsp/elixir-ls). Any IDE extensions that use ElixirLS should switch to using this repository. The ["ElixirLS Fork"](https://marketplace.visualstudio.com/items?itemName=elixir-lsp.elixir-ls) extension on the VS Code marketplace will be deprecated, and updates will continue at the [original ElixirLS extension](https://marketplace.visualstudio.com/items?itemName=JakeBecker.elixir-ls)

Improvements:
- Return the type of function/macro in DocumentSymbols provider (e.g. `def`, `defp`, `defmacro`) (thanks [Jason Axelson](https://github.com/axelson)) [#189](https://github.com/elixir-lsp/elixir-ls/pull/189)
- Return `deprecated` flag or completion tag on completion items for clints that declare `deprecatedSupport` or `tagSupport` in complete provider (thanks [Łukasz Samson](https://github.com/lukaszsamson)) [#180](https://github.com/elixir-lsp/elixir-ls/pull/180)

Bug Fixes:
- Fix `textDocument/documentSymbol` on a non-fully initialized server (thanks [Jason Axelson](https://github.com/axelson)) [#173](https://github.com/elixir-lsp/elixir-ls/pull/173)
- Don't return snippets to clients that don't declare `snippetSupport` for completions (thanks [Jason Axelson](https://github.com/axelson)) [#177](https://github.com/elixir-lsp/elixir-ls/pull/177)
- Handle an exception that was raised in the DocumentSymbols provider (thanks [Jason Axelson](https://github.com/axelson)) [#179](https://github.com/elixir-lsp/elixir-ls/pull/179)
- Fix support for environments (such as Docker Alpine linux) that do not have bash (thanks [Cees de Groot](https://github.com/cdegroot)) [#190](https://github.com/elixir-lsp/elixir-ls/pull/190)
- Handle syntax errors without raising an exception (thanks [Jason Axelson](https://github.com/axelson)) [#186](https://github.com/elixir-lsp/elixir-ls/pull/186) [#192](https://github.com/elixir-lsp/elixir-ls/pull/192)
- Workspace symbols handle module unloading during compilation without bringing down the server (thanks [Jason Axelson](https://github.com/axelson)) [#191](https://github.com/elixir-lsp/elixir-ls/pull/191)

VSCode:
- Change: Upgrade vscode-languageclient to 6.1.3 to support Language Server Protocol 3.15 (thanks [Łukasz Samson](https://github.com/lukaszsamson)) [#64](https://github.com/elixir-lsp/vscode-elixir-ls/pull/64)

### v0.3.2: 28 Mar 2020

Improvements:
- Bump ElixirSense
  - Fixes find all references doesn't work with argument defaults [#150](https://github.com/elixir-lsp/elixir-ls/issues/150)
  - Adds erlang edoc support [elixir_sense #86](https://github.com/elixir-lsp/elixir_sense/pull/86)
- Improvements to complete provider (thanks to [Łukasz Samson](https://github.com/lukaszsamson)) [#159](https://github.com/elixir-lsp/elixir-ls/pull/159)
  - Better handling when file fails to parse
  - Remove no longer necessary workaround that prevented completing default `@` (such as `@doc` or `@external_resource`)
  - Add more keywords
  - Trim spaces
- Use lower compression level to speed up dialyzer manifest writing (thanks to [hworld](https://github.com/hworld)) [#164](https://github.com/elixir-lsp/elixir-ls/pull/164)

Bug Fixes:
- Fix dialyzer errors not being reported for umbrella projects [#149](https://github.com/elixir-lsp/elixir-ls/pull/149) (thanks [hworld](https://github.com/hworld))
- Fix dialyzer checking files that have not changed which gives a good speedup [#165](https://github.com/elixir-lsp/elixir-ls/pull/165) (thanks [hworld](https://github.com/hworld))

VSCode:
- Change: No longer override default value of `editor.acceptSuggestionOnEnter` [vscode-elixir-ls #53](https://github.com/elixir-lsp/vscode-elixir-ls/pull/53)
- Change: Warn when incompatible extensions are installed [vscode-elixir-ls #57](https://github.com/elixir-lsp/vscode-elixir-ls/pull/57)

### v0.3.1: 3 Mar 2020

Improvements:

- Do not highlight function calls the same as function definitions [vscode-elixir-ls #40](https://github.com/elixir-lsp/vscode-elixir-ls/pull/40) (thanks [Jason Axelson](https://github.com/axelson))
- Code lens is returned in more situations [#122](https://github.com/elixir-lsp/elixir-ls/pull/122) (thanks [Łukasz Samson](https://github.com/lukaszsamson))
- Properly support requests without params (fixes shutdown in vim-lsc) [#139](https://github.com/elixir-lsp/elixir-ls/pull/139) (thanks [Brad Folkens](https://github.com/bfolkens))

Bug Fixes:
- Fix the debugger [#143](https://github.com/elixir-lsp/elixir-ls/pull/143)
- textDocumentSync save match spec (fixes error notice in vim-lsp) [#144](https://github.com/elixir-lsp/elixir-ls/pull/144) (thanks [N. G. Scheurich](https://github.com/ngscheurich))

### v0.3.0: 14 Feb 2020

Major Improvements:

- Add workspaceSymbol support to quickly navigate to modules, functions, callbacks etc (thanks to [Łukasz Samson](https://github.com/lukaszsamson)) [#110](https://github.com/elixir-lsp/elixir-ls/pull/110)
- Provide completions for protocol functions (thanks to [Łukasz Samson](https://github.com/lukaszsamson)) [#83](https://github.com/elixir-lsp/elixir-ls/pull/83)
- Upgrade ElixirSense (thanks to [Jason Axelson](https://github.com/axelson)) [#82](https://github.com/elixir-lsp/elixir-ls/pull/82)
  - Main changes: return results by arity, return all type signatures, typespec and dialyzer fixes

Improvements: 

- Update dialyxir to 1.0.0-rc.7
- Improvements to `textDocument/documentSymbol`, now `DocumentSymbol` is returned instead of the more simplistic `SymbolInformation` (thanks to [Łukasz Samson](https://github.com/lukaszsamson) and [kent-medin](https://github.com/kent-medin)) [#76](https://github.com/elixir-lsp/elixir-ls/pull/76)
- Support asdf-vm in wrapper scripts (thanks to [Cees de Groot](https://github.com/cdegroot)) [#78](https://github.com/elixir-lsp/elixir-ls/pull/78)
- Update startup message (thanks to [Ahmed Hamdy](https://github.com/shakram02)) [#85](https://github.com/elixir-lsp/elixir-ls/pull/85)
- Add didSave to server capabilities (thanks to [Jonáš Trantina](https://github.com/Coffei)) [#86](https://github.com/elixir-lsp/elixir-ls/pull/86)

Potentially Breaking Changes:

- `language_server.sh` and `debugger.sh` run bash instead of `sh` (this is expected to break very few setups, if any) [#118](https://github.com/elixir-lsp/elixir-ls/pull/118)

### v0.2.28: 16 Nov 2019

- Fix debugger tasks not continuing to run on Elixir 1.9 (thanks to [joshua-andrassy](https://github.com/joshua-andrassy) for doing the legwork)
  - Fixes [JakeBecker/elixir-ls#194](https://github.com/JakeBecker/elixir-ls/issues/194) and [JakeBecker/elixir-ls#185](https://github.com/JakeBecker/elixir-ls/issues/185)
- Improve supervision tree when writing dialyzer manifest files 

VSCode:

- Add syntax rules for function calls [vscode-elixir-ls #15](https://github.com/elixir-lsp/vscode-elixir-ls/pull/15) (thanks [CaiqueMitsuoka](https://github.com/CaiqueMitsuoka))

### v0.2.27: 14 Nov 2019

VSCode:

- Fix missing comma issue in the language configuration [#16](https://github.com/elixir-lsp/vscode-elixir-ls/pull/16)
- Add some basic configuration for HTML (EEx) files [#14](https://github.com/elixir-lsp/vscode-elixir-ls/pull/14) (thanks [@J3RN](https://github.com/J3RN))
- Fix exceptions raised when running on Erlang 20 and 21 [#65](https://github.com/elixir-lsp/elixir-ls/issues/65)

### v0.2.26: 4 Sept 2019

- Dialyxir new 1.0-rc formatting support
- `can_format/2` now case-insensitive (fixes formatting on Mac OS X)
- `defdelegate` snippet is now syntactically correct (was previously missing a comma)
- `workspace/didChangeConfiguration` handles `null` now (fixes [eglot](https://github.com/joaotavora/eglot) support)
- Update elixir_sense
- Watch LiveView .leex files
- Change 'dialyzerFormat' default setting to `"dialyxir_long"`

### v0.2.25: 23 May 2019

- Fix compatibility with Elixir 1.9
- Fix bug where Mix file is not reloaded on change if it had errors
- Remove unneccessary empty parens from suggested specs
- Add 'dialyzerFormat' setting to select which warning formatter to use. Options are `"dialyzer"` (default), `"dialyxir_short"`, `"dialyxir_long"` 
- (VS Code) Support syntax highlighting in Phoenix LiveView (.leex) files, including ~L sigil (Thanks to @rrichardsonv)
- (VS Code) Improved syntax highlighting and other automatic behavior (Thanks to @crbelaus)
- Fix crash when yecc grammar file has conflicts
- Dialyzer robustness improvements
- When autocompleting a function name with cursor immediately prior to a `(`, don't insert additional parens and argument list

### v0.2.24: 15 Oct 2018

- Fix debugger crash in new versions of VS Code (Thanks to @martin-watts)
- Minor improvements to logs and error messages

### v0.2.23: 05 Aug 2018

- Fix crashes caused by the new spec suggestions feature
- Fix showing of @spec suggestions on newly opened files

### v0.2.22: 03 Aug 2018

- Fix crash in Dialyzer when stale-checking beam files takes too long
- Fix documentation and arg names in suggestions for Elixir 1.7
- Formatter response is now incremental instead of replacing the entire document text
- New feature: Autocomplete suggestions for struct field names (Thanks to @msaraiva/elixir_sense)
- New feature: Suggest @spec annotations using Dialyzer's inferred success typings. To turn it off, set `elixirLS.suggestSpecs: false`

### v0.2.21: 13 Jul 2018

- Print PATH to developer console if "elixir" command fails
- Fix Dialyzer crash when some modules are undialyzable

### v0.2.20: 13 Jul 2018

- Skipped because I got my versions out of sync :/

### v0.2.19: 06 Jul 2018

- Fix compatibility issues with recent Elixir versions (1.7.0-dev) and Erlang OTP 21
- Go-to-definition now works for variables (thanks to [Elixir Sense](https://github.com/msaraiva/elixir_sense))
- Better error messages when server crashes or fails to launch

### v0.2.18: 19 Mar 2018

- Fix autocomplete bugs when typing in parentheses
- Copy latest syntax highlighting from fr1zle/vscode-elixir
- Handle `subdirectories` and `import_deps` in `.formatter.exs`. Requires the latest Elixir (1.6.5), which you can install via kiex with `kiex install master` prior to its release.

### v0.2.17: 9 Mar 2018

- New feature: Automatically fetch deps when compiling. Set `elixirLS.fetchDeps` to `false` to disable
- New feature: Incremental text synchronization
- Minor improvements to autocomplete and automatic block closing

### v0.2.16: 7 Mar 2018

- New feature: Smart automatic insertion of "end" when beginning a block. This replaces the autocomplete-based approach and fixes the very annoying completion of "->" with "end" when not appropriate
- ** ACCEPT AUTOCOMPLETE SUGGESTIONS WITH TAB INSTEAD OF ENTER.** See readme for an explanation of why. You can change it back if you really want.
- Change default settings to automatically trim trailing whitespace and add newline at end of file
- Don't trigger autocomplete on "\_" because you're usually just naming an unused variable

### v0.2.15: 6 Mar 2018

- Improve autocomplete and re-enable quickSuggestions by default

### v0.2.14: 3 Mar 2018

- Fix failures to launch in some projects

### v0.2.13: 2 Mar 2018

- New feature: Find references to modules and functions (Thanks to @mattbaker)
- New feature: Find symbols in document (Thanks to @mattbaker)
- Fix failure to launch if project prints anything to stdout in the mixfile

### v0.2.12: 22 Feb 2018

- Fix bug where Dialyzer warnings sometimes remain after being fixed
- Override build directory to ".elixir_ls/build" as [recommended by José Valim](https://github.com/elixir-lang/elixir/issues/7356#issuecomment-366644546)
- Fix restart button in debugger

### v0.2.11: 31 Jan 2018

- Improve syntax highlighting (Thanks to @TeeSeal)

### v0.2.10: 24 Jan 2018

- Fix builds and related features on Windows

### v0.2.9: 29 Nov 2017

- Fix autocomplete not firing after "."

### v0.2.8: 29 Nov 2017

- Add auto-indentation rules (copied from
  [fr1zle/vscode-elixir](https://github.com/fr1zle/vscode-elixir))
- Disable `editor.quickSuggestions` by default so autocomplete suggestions are
  triggered automatically only when after a ".". This is nice because the
  language server irritatingly tries to auto-complete things like "do" or "else"
  if they come at the end of a line.
- Add configuration option "mixEnv" to set the Mix environment used when
  compiling. It now defaults to "test" instead of "dev" to aid in TDD and to
  avoid interfering with the Phoenix dev server.
- Add configuration option "projectDir" for when your Mix project is in a
  subdirectory instead of the workspace root.
- Add debug launch configuration option "env" to set environment variables
  (including `MIX_ENV`)
- Add debug launch configuration option "excludeModules" to avoid interpreting
  modules. This is important if for modules that contain NIFs which can't be
  debugged.

### v0.2.7: 9 Nov 2017

- Read formatter options from `.formatter.exs` in project root instead of
  including line length in extension config options

### v0.2.6: 3 Nov 2017

- Don't focus Output pane on errors because request handler errors are common
  and recoverable

### v0.2.5: 3 Nov 2017

- Improve error output in debugger and fix failures to launch debugger

### v0.2.4: 25 Oct 2017

- Package ElixirLS as .ez archives instead of escripts. This should make `asdf`
  installs work.
- Fix debugger error logging when initialize fails
- Fix timeouts when calling back into the language server with build or dialyzer
  results

### v0.2.3: 24 Oct 2017

- Fix failing debugger launch
- Fix segfaults in OTP 20 caused by regexes precompiled in OTP 19

### v0.2.2: 19 Oct 2017

- Fix launch on Windows when there are spaces in the path

### v0.2.1: 19 Oct 2017

- Fix bug where deps are recompiled after every change
- Update README
- Update syntax highlighting (merged from fr1zle/vscode-elixir)

### v0.2.0: 17 Oct 2017

- Rewritten build system to make use of Elixir 1.6 compiler diagnostics
- Code formatting in Elixir 1.6
- Automatic dialyzer server in Erlang/OTP 20
- Lots and lots of refactoring

### v0.0.9: 23 Jun 2017

- Revert to building with Erlang OTP 19.2 instead of 20.0. It seems that
  escripts built with 20.0 won't run on 19.2 runtimes.
- Fix handling of Windows paths with non-default drive letter

### v0.0.8: 23 Jun 2017

- Enable setting breakpoints in Erlang modules

### v0.0.7: 12 Jun 2017

- Fix launching of debugger on OSX (when working directory is not set to the
  extension directory)
- Fix launching of language server when Elixir is installed with "asdf" tool.
  (Fix in 0.0.6 didn't actually work)

### v0.0.6: 12 Jun 2017

- Handle Elixir installations that were done via the "asdf" tool

### v0.0.5: 11 Jun 2017

- Windows support

### v0.0.4: 10 Jun 2017

- Updated ElixirLS to package its apps as escripts and updated client to handle
  it. This should fix the error `(Mix) Could not start application language_server: could not find application file: language_server.app`.
  Windows, however, is still broken.
- Began a changelog :)
