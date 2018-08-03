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
