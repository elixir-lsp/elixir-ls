defmodule ElixirLS.Utils.Mixfile do
  use Mix.Project

  def project do
    [app: :elixir_ls_utils,
     version: "0.2.1",
     build_path: "../../_build",
     config_path: "../../config/config.exs",
     deps_path: "../../deps",
     elixirc_paths: ["lib", "test/support"],
     lockfile: "../../mix.lock",
     elixir: "~> 1.6.0-dev",
     build_embedded: false,
     start_permanent: false,
     build_per_environment: false,
     consolidate_protocols: false,
     deps: deps()]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    # Specify extra applications you'll use from Erlang/Elixir
    [applications: []]
  end

  # Dependencies can be Hex packages:
  #
  #   {:my_dep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:my_dep, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
  #
  # To depend on another app inside the umbrella:
  #
  #   {:my_app, in_umbrella: true}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [{:poison, "~> 3.0"},
     {:mix_task_archive_deps, "~> 0.4.0"}]
  end
end
