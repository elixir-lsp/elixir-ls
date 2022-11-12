defmodule ElixirLS.Debugger.Mixfile do
  use Mix.Project

  def project do
    [
      app: :elixir_ls_debugger,
      version: "0.12.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: ">= 1.12.3",
      build_embedded: false,
      start_permanent: true,
      build_per_environment: false,
      consolidate_protocols: false,
      deps: deps(),
      xref: [exclude: [:int, :dbg_iserver]]
    ]
  end

  def application do
    [mod: {ElixirLS.Debugger, []}, extra_applications: [:mix]]
  end

  defp deps do
    [
      {:elixir_sense, github: "elixir-lsp/elixir_sense"},
      {:elixir_ls_utils, in_umbrella: true},
      {:dialyxir_vendored, github: "elixir-lsp/dialyxir", branch: "vendored", runtime: false}
    ]
  end
end
