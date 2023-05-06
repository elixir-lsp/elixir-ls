defmodule ElixirLS.Utils.Mixfile do
  use Mix.Project

  @version __DIR__
           |> Path.join("../../VERSION")
           |> File.read!()
           |> String.trim()

  def project do
    [
      app: :elixir_ls_utils,
      version: @version,
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      elixirc_paths: elixirc_paths(Mix.env()),
      lockfile: "../../mix.lock",
      elixir: ">= 1.12.0",
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
    [applications: []]
  end

  defp deps do
    [
      {:jason_v, github: "elixir-lsp/jason", ref: "c81537e2a5e1acacb915cf339fe400357e3c2aaa"},
      {:mix_task_archive_deps, github: "elixir-lsp/mix_task_archive_deps"},
      {:dialyxir_vendored, github: "elixir-lsp/dialyxir", ref: "896fa45817c6a1be8ec408577c88ab52c27f6851", runtime: false}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
