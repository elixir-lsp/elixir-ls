defmodule ElixirLS.Utils.Mixfile do
  use Mix.Project

  def project do
    [
      app: :elixir_ls_utils,
      version: "0.6.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      elixirc_paths: elixirc_paths(Mix.env()),
      lockfile: "../../mix.lock",
      elixir: ">= 1.8.0",
      build_embedded: false,
      start_permanent: false,
      build_per_environment: false,
      consolidate_protocols: false,
      deps: deps(),
      xref: [exclude: [JasonVendored, Logger]]
    ]
  end

  def application do
    # We must NOT start ANY applications as this is taken care in code.
    [applications: []]
  end

  defp deps do
    [
      {:jason_vendored, github: "elixir-lsp/jason", branch: "vendored"},
      {:mix_task_archive_deps, github: "JakeBecker/mix_task_archive_deps"}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
