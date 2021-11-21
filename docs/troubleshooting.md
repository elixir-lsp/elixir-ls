# Troubleshooting

Basic troubleshooting steps:

* Restart your editor (which will restart ElixirLS)
* After stopping your editor, remove the entire `.elixir_ls` directory, then restart your editor
  * NOTE: This will cause you to have to re-run the entire dialyzer build

If your code doesn't compile in ElixirLS, it may be because ElixirLS compiles code with `MIX_ENV=test` (by default). So if you are missing some configuration in the test environment, your code may not compile.

If you get an error like the following immediately on startup:

```
[Warn  - 1:56:04 PM] ** (exit) exited in: GenServer.call(ElixirLS.LanguageServer.JsonRpc, {:packet, %{...snip...}}, 5000)
    ** (EXIT) no process: the process is not alive or there's no process currently associated with the given name, possibly because its application isn't started
```

and you installed Elixir and Erlang from the Erlang Solutions repository, you may not have a full installation of erlang. This can be solved with `sudo apt-get install esl-erlang`. Originally reported in [#208](https://github.com/elixir-lsp/elixir-ls/issues/208).

On fedora if you only install the elixir package you will not have a full erlang installation, this can be fixed by running `sudo dnf install erlang` (reported in [#231](https://github.com/elixir-lsp/elixir-ls/issues/231))

If you are using Emacs with lsp-mode there's a possibility that you have set the
wrong directory as the project root (especially if that directory does not have
a `mix.exs` file). To fix that you should remove the project and re-initialize:

https://github.com/elixir-lsp/elixir-ls/issues/364#issuecomment-829589139
