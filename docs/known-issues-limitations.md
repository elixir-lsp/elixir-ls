# Known Issues / Limitations

* `.exs` files don't return compilation errors
* "Fetching n dependencies" sometimes get stuck (remove the `.elixir_ls` directory to fix)
* Debugger doesn't work in Elixir 1.10.0 - 1.10.2 (but it should work in 1.10.3 when [this fix](https://github.com/elixir-lang/elixir/pull/9864) is released)
* "Go to definition" does not work within the `scope` of a Phoenix router
* On-hover docs do not work with erlang modules or functions (better support of EEP-48 is needed)
* On first launch dialyzer will cause high CPU usage for a considerable time
* ElixirLS requires a workspace to be opened. Editing single-files is not supported [#307](https://github.com/elixir-lsp/elixir-ls/issues/307)
