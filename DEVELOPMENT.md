# Version Support Guidelines

Elixir itself supports 5 versions with security updates:
https://hexdocs.pm/elixir/compatibility-and-deprecations.html#content

OTP Supports the last 3 versions:
http://erlang.2086793.n4.nabble.com/OTP-Versions-and-Maint-Branches-td4722416.html

ElixirLS generally aims to support the last 3 versions of Elixir and the last 3 versions of OTP. However this is not a hard and fast rule and may change in the future.

# Packaging

Bump the changelog
Bump the version numbers in `apps/elixir_ls_debugger/mix.exs`, `apps/elixir_ls_utils/mix.exs`, and `apps/language_server/mix.exs`
Make PR
Merge PR
Pull down the latest master
Make the tag from the new master
Push the tag (`git push upstream --tags`)
- `rm -rf _build release`
- `cp .release-tool-versions .tool-version`
- `mix elixir_ls.release`
- `cd release`
- `zip elixir-ls.zip *`
- Attach elixir-ls.zip to the release on github https://github.com/elixir-lsp/elixir-ls/releases (edit the tag to make it into a release)

# Debugging

If you're debugging a running server than `IO.inspect` is a good approach, any messages you create with it will be sent to your LSP client as a log message

To debug in tests you can use `IO.inspect(Process.whereis(:user), message, label: "message")` to send your output directly to the group leader of the test process.
