defmodule ElixirLsMain.MixProject do
  use Mix.Project

  def project do
    [
      app: :elixir_ls_main,
      version: "0.1.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: "~> 1.10",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {ElixirLsMain.Application, []},
      extra_applications: [:logger],
      bundled_applications: [:debugger, :language_server]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:language_server, in_umbrella: true},
      {:debugger, in_umbrella: true}
    ]
  end
end
