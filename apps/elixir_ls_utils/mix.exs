defmodule ElixirLS.Utils.Mixfile do
  use Mix.Project

  def project do
    [
      app: :elixir_ls_utils,
      version: "0.3.0",
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
    [applications: [],
     included_applications: [:eels]]
  end

  defp deps do
    [
      {:jason, "~> 1.1"},
      {:mix_task_archive_deps, github: "JakeBecker/mix_task_archive_deps"},
      # We include eels as a dependency so that we get it bundled in the release
      {:eels, path: "../../eels"}
    ]
  end
end
