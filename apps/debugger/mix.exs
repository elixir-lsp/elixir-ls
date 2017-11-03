defmodule ElixirLS.Debugger.Mixfile do
  use Mix.Project

  def project do
    [
      app: :debugger,
      version: "0.2.2",
      build_path: "../../_build",
      config_path: "config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.6.0-dev",
      build_embedded: false,
      start_permanent: true,
      build_per_environment: false,
      consolidate_protocols: false,
      deps: deps()
    ]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    # Specify extra applications you'll use from Erlang/Elixir
    [mod: {ElixirLS.Debugger, []}, extra_applications: [:mix, :logger]]
  end

  # Dependencies can be Hex packages:
  #
  #   {:my_dep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:my_dep, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
  #
  # To depend on another app inside the umbrella:
  #
  #   {:my_app, in_umbrella: true}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [{:elixir_sense, github: "msaraiva/elixir_sense"}, {:elixir_ls_utils, in_umbrella: true}]
  end
end
