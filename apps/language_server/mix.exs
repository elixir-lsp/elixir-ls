defmodule ElixirLS.LanguageServer.Mixfile do
  use Mix.Project

  def project do
    [
      app: :language_server,
      version: "0.14.2",
      elixir: ">= 1.12.0",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      aliases: aliases(),
      elixirc_paths: elixirc_paths(Mix.env()),
      build_embedded: false,
      start_permanent: true,
      build_per_environment: false,
      consolidate_protocols: Mix.env() != :test,
      deps: deps()
    ]
  end

  def application do
    [mod: {ElixirLS.LanguageServer, []}, extra_applications: [:mix, :logger]]
  end

  defp deps do
    [
      {:elixir_ls_utils, in_umbrella: true},
      {:elixir_sense, github: "elixir-lsp/elixir_sense"},
      {:erl2ex, github: "dazuma/erl2ex"},
      {:sourceror, "0.11.2"},
      {:dialyxir_vendored, github: "elixir-lsp/dialyxir", branch: "vendored", runtime: false},
      {:jason_vendored, github: "elixir-lsp/jason", branch: "vendored"},
      {:stream_data, "~> 0.5", only: [:dev, :test], runtime: false},
      {:path_glob_vendored, github: "elixir-lsp/path_glob", branch: "vendored"},
      {:patch, "~> 0.12.0", only: [:dev, :test], runtime: false},
      {:benchee, "~> 1.0", only: :dev, runtime: false}
    ]
  end

  defp aliases do
    [
      test: "test --no-start"
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
