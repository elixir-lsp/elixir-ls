defmodule ElixirLS.Utils.MixProject do
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
      app: :elixir_ls_utils,
      version: @version,
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      elixirc_paths: elixirc_paths(Mix.env()),
      lockfile: "../../mix.lock",
      elixir: ">= 1.14.0",
      build_embedded: false,
      start_permanent: false,
      build_per_environment: false,
      consolidate_protocols: false,
      deps: deps(),
      xref: [exclude: [JasonV, Logger, Hex]]
    ]
  end

  def application do
    # We must NOT start ANY applications as this is taken care in code.
    [applications: [:jason_v, :elixir_sense]]
  end

  defp deps do
    [
      {:elixir_sense, github: "elixir-lsp/elixir_sense", ref: @dep_versions[:elixir_sense]},
      {:jason_v, github: "elixir-lsp/jason", ref: @dep_versions[:jason_v]},
      {:dialyxir_vendored,
       github: "elixir-lsp/dialyxir", ref: @dep_versions[:dialyxir_vendored], runtime: false}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
