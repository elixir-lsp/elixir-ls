Application.put_env(:elixir, :ansi_enabled, false)
Code.eval_file("#{__DIR__}/installer.exs")

Mix.start()

# Put mix into quiet mode so it does not print anything to standard out
# especially it makes it surface git command errors such as reported in
# https://github.com/elixir-lsp/vscode-elixir-ls/issues/320
# to standard error
# see implementation in
# https://github.com/elixir-lang/elixir/blob/6f96693b355a9b670f2630fd8e6217b69e325c5a/lib/mix/lib/mix/scm/git.ex#LL304C1-L304C1
Mix.shell(ElixirLS.Shell.Quiet)

ElixirLS.Installer.install_with_retry()
