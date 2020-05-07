defmodule ElixirLS.Utils.Mixfile do
  use Mix.Project

  def project do
    [
      app: :elixir_ls_utils,
      version: "0.3.3",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      elixirc_paths: ["lib", "test/support"],
      lockfile: "../../mix.lock",
      elixir: ">= 1.7.0",
      build_embedded: false,
      start_permanent: false,
      build_per_environment: false,
      consolidate_protocols: false,
      deps: deps()
    ]
  end

  def application do
    # We must NOT start ANY applications as this is taken care in code.
    [applications: []]
  end

  defp deps do
    [
      {:jason, "~> 1.2"},
      {:mix_task_archive_deps, github: "JakeBecker/mix_task_archive_deps"}
    ]
  end
end
