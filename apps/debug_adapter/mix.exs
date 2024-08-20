defmodule ElixirLS.DebugAdapter.MixProject do
  use Mix.Project

  @version __DIR__
           |> Path.join("../../VERSION")
           |> File.read!()
           |> String.trim()

  @dep_versions __DIR__
                |> Path.join("../../dep_versions.exs")
                |> Code.eval_file()
                |> elem(0)

  def project do
    [
      app: :debug_adapter,
      version: @version,
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      elixir: ">= 1.12.0",
      build_embedded: false,
      start_permanent: true,
      build_per_environment: false,
      # if we consolidate here debugged code will not work correctly
      # and debugged protocol implementation will not be available
      consolidate_protocols: false,
      deps: deps(),
      xref: [exclude: [:int, :dbg_iserver]]
    ]
  end

  def application do
    [mod: {ElixirLS.DebugAdapter.Application, []}, extra_applications: []]
  end

  defp deps do
    [
      {:elixir_sense, github: "elixir-lsp/elixir_sense", ref: @dep_versions[:elixir_sense]},
      {:elixir_ls_utils, in_umbrella: true},
      {:jason_v, github: "elixir-lsp/jason", ref: @dep_versions[:jason_v]},
      {:dialyxir_vendored,
       github: "elixir-lsp/dialyxir", ref: @dep_versions[:dialyxir_vendored], runtime: false}
    ]
  end
end
