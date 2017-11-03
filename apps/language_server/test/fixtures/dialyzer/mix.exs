defmodule ElixirLS.LanguageServer.Fixtures.Dialyzer.Mixfile do
  use Mix.Project

  def project do
    [app: :els_dialyzer_test, version: "0.1.0"]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    # Specify extra applications you'll use from Erlang/Elixir
    []
  end
end
