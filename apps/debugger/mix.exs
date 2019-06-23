defmodule ElixirLS.Debugger.Mixfile do
  use Mix.Project

  def project do
    [
      app: :debugger,
      version: "0.2.24",
      build_path: "../../_build",
      config_path: "config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: ">= 1.7.0",
      build_embedded: false,
      start_permanent: true,
      build_per_environment: false,
      consolidate_protocols: false,
      deps: deps()
    ]
  end

  def application do
    [mod: {ElixirLS.Debugger, []}, extra_applications: [:mix, :logger]]
  end

  defp deps do
    [
      {:elixir_sense, github: "elixir-lsp/elixir_sense"},
      {:elixir_ls_utils, in_umbrella: true}
    ]
  end
end
