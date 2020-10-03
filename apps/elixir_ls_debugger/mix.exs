defmodule ElixirLS.Debugger.Mixfile do
  use Mix.Project

  def project do
    [
      app: :elixir_ls_debugger,
      version: "0.6.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: ">= 1.8.0",
      build_embedded: false,
      start_permanent: true,
      build_per_environment: false,
      consolidate_protocols: false,
      deps: deps()
    ]
  end

  def application do
    [mod: {ElixirLS.Debugger, []}, extra_applications: [:mix, :logger, :debugger]]
  end

  defp deps do
    [
      {:elixir_sense, github: "elixir-lsp/elixir_sense"},
      {:elixir_ls_utils, in_umbrella: true}
    ]
  end
end
