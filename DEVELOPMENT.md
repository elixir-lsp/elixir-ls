# Packaging

Bump the changelog
Bump the version numbers in `apps/debugger/mix.exs`, `apps/elixir_ls_utils/mix.exs`, and `apps/language_server/mix.exs`
Make PR
Merge PR
Make the tag from the new master
Push the tag
- `rm -rf _build release`
- `mix elixir_ls.release`
- `cd release`
- `zip elixir-ls.zip *`
- Attach elixir-ls.zip to the release on github https://github.com/elixir-lsp/elixir-ls/releases

# Debugging

If you're debugging a running server than `IO.inspect` is a good approach, any messages you create with it will be sent to your LSP client as a log message

To debug in tests you can use `IO.inspect(Process.whereis(:user), message, label: "message")` to send your output directly to the group leader of the test process.
