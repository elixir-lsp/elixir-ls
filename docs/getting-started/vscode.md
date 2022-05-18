# VSCode

## Setup

Install the official [ElixirLS extension](https://github.com/elixir-lsp/vscode-elixir-ls) and enable it.

## Debugger

ElixirLS includes debugger support adhering to the [VS Code debugger protocol](https://code.visualstudio.com/docs/extensionAPI/api-debugging) which is closely related to the Language Server Protocol. At the moment, only line breakpoints are supported.

When debugging in Elixir or Erlang, only modules that have been "interpreted" (using `:int.ni/1` or `:int.i/1`) will accept breakpoints or show up in stack traces. The debugger in ElixirLS automatically interprets all modules in the Mix project and dependencies prior to launching the Mix task, so you can set breakpoints anywhere in your project or dependency modules.

In order to debug modules in `.exs` files (such as tests), they must be specified under `requireFiles` in your launch configuration so they can be loaded and interpreted prior to running the task. For example, the default launch configuration for "mix test" in the VS Code plugin looks like this:

```json
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

In order to debug a single test or a single test file it is currently necessary to modify `taskArgs` and make sure no other tests are required in `requireFiles`.

```json
{
  "type": "mix_task",
  "name": "mix test",
  "request": "launch",
  "task": "test",
  "taskArgs": ["tests/some_test.exs:123"],
  "projectDir": "${workspaceRoot}",
  "requireFiles": [
    "test/**/test_helper.exs",
    "test/some_test.exs"
  ]
}
```

Please note that due to `:int` limitation NIF modules cannot be interpreted and need to be excluded via `excludeModules` option. This option can be also used to disable interpreting for some modules when it is not desirable e.g. when performance is not satisfactory.

```json
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
  ],
  "excludeModules": [
    ":some_nif",
    "Some.SlowModule"
  ]
}
```
