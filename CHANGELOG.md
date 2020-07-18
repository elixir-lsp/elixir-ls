### Unreleased

Potentially breaking changes:
- Do not format files that are not listed in `inputs` of `.formatter.exs` (thanks [Tan Jay Jun](https://github.com/jayjun)) [#315](https://github.com/elixir-lsp/elixir-ls/pull/315)

Improvements:
- Use ElixirSense's error tolerant parser for document symbols (thanks [Łukasz Samson](https://github.com/lukaszsamson)) [#322](https://github.com/elixir-lsp/elixir-ls/pull/322)

House keeping:
- Fix the link in the README to releases (thanks [RJ Dellecese](https://github.com/rjdellecese)) [#312](https://github.com/elixir-lsp/elixir-ls/pull/312)
- Update the dialyzer section in the readme (thanks [Serenity597](https://github.com/Serenity597)) [#323](https://github.com/elixir-lsp/elixir-ls/pull/323)

VSCode:
- Debugger does not successfully launch on Windows (thanks [Craig Tataryn](https://github.com/ctataryn)) [#115](https://github.com/elixir-lsp/vscode-elixir-ls/pull/115)

### v0.5.0: 28 June 2020

Improvements:
- Support completion of callback function definitions (thanks [Marlus Saraiva](https://github.com/msaraiva)) [#265](https://github.com/elixir-lsp/elixir-ls/pull/265)
- Support WorkspaceSymbols (go to symbol in workspace) without dialyzer being enabled (thanks [Jason Axelson](https://github.com/axelson)) [#263](https://github.com/elixir-lsp/elixir-ls/pull/263)
- Give more direct warnings when mix.exs cannot be found (thanks [Jason Axelson](https://github.com/axelson)) [#297](https://github.com/elixir-lsp/elixir-ls/pull/297)
- Add completions for `@moduledoc false` and `@doc false` (thanks [Jason Axelson](https://github.com/axelson)) [#288](https://github.com/elixir-lsp/elixir-ls/pull/288)

Changes:
- Major improvement/change: Improve autocomplete and signature help (thanks [Marlus Saraiva](https://github.com/msaraiva)) [#273](https://github.com/elixir-lsp/elixir-ls/pull/273)
  - Don't insert arguments when completing a function call (almost always had to be deleted)
  - Autocomplete triggers signature help
  - Don't insert a `()` around the function call if the formatter configuration does not require it
  - Further autocomplete refinements (thanks [Marlus Saraiva](https://github.com/msaraiva)) [#300](https://github.com/elixir-lsp/elixir-ls/pull/300)
- No longer always return a static list of keywords for completion (thanks [Jason Axelson](https://github.com/axelson)) [#259](https://github.com/elixir-lsp/elixir-ls/pull/259)

Bug Fixes:
- Formatting was returning invalid floating point number (thanks [Thanabodee Charoenpiriyakij](https://github.com/wingyplus)) [#250](https://github.com/elixir-lsp/elixir-ls/pull/250)
- Fix detection of empty hover hints (thanks [Dmitry Gutov](https://github.com/dgutov)) [#279](https://github.com/elixir-lsp/elixir-ls/pull/279)
- Debugger doesn't fail when modules cannot be interpretted (thanks [Łukasz Samson](https://github.com/lukaszsamson)) (such as nifs) [#283](https://github.com/elixir-lsp/elixir-ls/pull/283)
- Do not advertise `workspaceFolders` support (thanks [Jason Axelson](https://github.com/axelson)) [#298](https://github.com/elixir-lsp/elixir-ls/pull/298)
- Do not try to create gitignore when project dir not set (thanks [Łukasz Samson](https://github.com/lukaszsamson)) [#306](https://github.com/elixir-lsp/elixir-ls/pull/306)
- Only call DocumentSymbols (outline pane) for .ex and .exs files (thanks [Marlus Saraiva](https://github.com/msaraiva)) [#262](https://github.com/elixir-lsp/elixir-ls/pull/262)

House keeping:
- Server runs with a unique id (and uses it to disambiguate commands) (thanks [Alessandro Tagliapietra](https://github.com/alex88)) [#278](https://github.com/elixir-lsp/elixir-ls/pull/278)
- Improvements to the reliability of the test suite (thanks [Jason Axelson](https://github.com/axelson)) [#270](https://github.com/elixir-lsp/elixir-ls/pull/270), [#271](https://github.com/elixir-lsp/elixir-ls/pull/271)
- Rename debugger app so that it does not conflict with otp debugger app (thanks [Łukasz Samson](https://github.com/lukaszsamson)) [#280](https://github.com/elixir-lsp/elixir-ls/pull/280)
- Vendor Jason library to prevent conflicts with user's code (thanks [Jason Axelson](https://github.com/axelson)) [#253](https://github.com/elixir-lsp/elixir-ls/pull/253)
- Switch to new supervisor format (thanks [Jason Axelson](https://github.com/axelson)) [#260](https://github.com/elixir-lsp/elixir-ls/pull/260)
- Display the version of Elixir used to compile ELixirLS (thanks [Jason Axelson](https://github.com/axelson)) [#264](https://github.com/elixir-lsp/elixir-ls/pull/264)

VSCode:
- Support workspaces with multiple elixir projects (thanks [Alessandro Tagliapietra](https://github.com/alex88)) [#70](https://github.com/elixir-lsp/vscode-elixir-ls/pull/70)
  - Support per-folder configuration for many settings (makes the multi-workspace support more powerful) (thanks [AJ Foster](https://github.com/aj-foster)) [#110](https://github.com/elixir-lsp/vscode-elixir-ls/pull/110)
- Improved support for phoenix templates (thanks [Marlus Saraiva](https://github.com/msaraiva)) [#93](https://github.com/elixir-lsp/vscode-elixir-ls/pull/93)
  - Shows errors in `.eex` and `.leex` files (instead of associated `.ex` file)
- Improve syntax highlighting following pipes (thanks [Dusty Pomerleau](https://github.com/dustypomerleau)) [#81](https://github.com/elixir-lsp/vscode-elixir-ls/pull/81)
- Make `%` a dedicated punctuation scope in elixir syntax file (thanks [Dusty Pomerleau](https://github.com/dustypomerleau)) [#72](https://github.com/elixir-lsp/vscode-elixir-ls/pull/72)
- Migrate generated tasks.json to 2.0.0 syntax (thanks [Dusty Pomerleau](https://github.com/dustypomerleau)) [#71](https://github.com/elixir-lsp/vscode-elixir-ls/pull/71)
- Improve development instructions (thanks [Tan Jay Jun](https://github.com/jayjun)) [#97](https://github.com/elixir-lsp/vscode-elixir-ls/pull/97)
- Activate extension whenever workspace contains elixir files (thanks [Jason Axelson](https://github.com/axelson)) [#107](https://github.com/elixir-lsp/vscode-elixir-ls/pull/107)
- Make heredocs and most sigils auto-close when used with quotes and triple quotes (thanks [Jarrod Davis](https://github.com/jarrodldavis)) [#101](https://github.com/elixir-lsp/vscode-elixir-ls/pull/101)
- Set a default for `elixirLS.projectDir` (thanks [Łukasz Samson](https://github.com/lukaszsamson)) [#112](https://github.com/elixir-lsp/vscode-elixir-ls/pull/112)

### v0.4.0: 16 May 2020

Improvements:
- Add autocompletion of struct fields on a binding when we know for sure what type of struct it is. (thanks [Łukasz Samson](https://github.com/lukaszsamson)) [#202](https://github.com/elixir-lsp/elixir-ls/pull/202)
  - For details see the [Code Completion section of the readme](https://github.com/elixir-lsp/elixir-ls/tree/a2a1f38bf0f47e074ec5d50636d669fae03a3d5e#code-completion)
- Normalize compiler warnings and associate them with templates (thanks [Marlus Saraiva](https://github.com/msaraiva)) [#241](https://github.com/elixir-lsp/elixir-ls/pull/241)
- Add all core elixir apps to the Dialyzer PLT. (thanks [Eric Entin](https://github.com/ericentin)) [#225](https://github.com/elixir-lsp/elixir-ls/pull/225)
- Change "did not receive workspace/didChangeConfiguration" log level from warning to info (thanks [Jason Axelson](https://github.com/axelson)) [#222](https://github.com/elixir-lsp/elixir-ls/pull/222)
- Automatically create a `.gitignore` file inside the `.elixir-ls` dir so that users do not need to manually add it to their gitignore (thanks [Thanabodee Charoenpiriyakij](https://github.com/wingyplus)) [#232](https://github.com/elixir-lsp/elixir-ls/pull/232)
- Dialyzer provider shouldn't track removed files and modules (thanks [Michał Szajbe](https://github.com/szajbus)) [#237](https://github.com/elixir-lsp/elixir-ls/pull/237)
- Load all modules after first build (thanks [Akash Hiremath](https://github.com/akash-akya)) [#227](https://github.com/elixir-lsp/elixir-ls/pull/227)

Bug Fixes:
- Dialyzer: Get beam file for preloaded modules. (thanks [Łukasz Samson](https://github.com/lukaszsamson)) [#218](https://github.com/elixir-lsp/elixir-ls/pull/218)
- Warn when using the debugger on Elixir 1.10.0-1.10.2. (thanks [Jason Axelson](https://github.com/axelson)) [#221](https://github.com/elixir-lsp/elixir-ls/pull/221)
- Don't return snippets to clients that don't declare `snippetSupport` for function completions (thanks [Jeffrey Xiao](https://github.com/jeffrey-xiao)) [#223](https://github.com/elixir-lsp/elixir-ls/pull/223)

VSCode:
- Add basic support for `.html.leex` files for Phoenix LiveView (thanks [oskarkook](https://github.com/oskarkook)) [#82](https://github.com/elixir-lsp/vscode-elixir-ls/pull/82)
- Add filetype and watcher for `.html.leex` files for Phoenix LiveView (thanks [Byron Hambly](https://github.com/delta1)) [#83](https://github.com/elixir-lsp/vscode-elixir-ls/pull/83)
- Better phoenix templates support (thanks [Marlus Saraiva](https://github.com/msaraiva)) [#93](https://github.com/elixir-lsp/vscode-elixir-ls/pull/93)

VSCode potentially breaking changes:
- Change language id to be lowercase kebab-case in accordance with [VSCode guidelines](https://code.visualstudio.com/docs/languages/identifiers#_new-identifier-guidelines). This also fixes an issue displaying the elixir logo for html.eex files. (thanks [Matt Furden](https://github.com/zolrath)) [#87](https://github.com/elixir-lsp/vscode-elixir-ls/pull/87)
  - This changes the language id's `EEx`->`eex` and `HTML (EEx)`->`html-eex`
  - If you have customized your emmet configuration configuration then you need to update it:
  - Open VSCode and hit `Ctrl+Shift+P` or `Cmd+Shift+P` and type `"Preference: Open Settings (JSON)"`
  - Add or edit your `emmet.includedLanguages` to include the new Language Id:
```json
"emmet.includeLanguages": {
  "html-eex": "html"
}
```

If you have eex file associations in your settings.json then remove them:
```
"files.associations": {
  "*.html.eex": "HTML (EEx)", // remove this
  "*.html.leex": "HTML (EEx)" // remove this
},
```

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
