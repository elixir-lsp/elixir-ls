defmodule ElixirLS.Mixfile do
  use Mix.Project

  def project do
    [
      apps_path: "apps",
      aliases: aliases(),
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      build_per_environment: false,
      deps: deps(),
      elixir: ">= 1.16.0",
      dialyzer: [
        plt_add_apps: [:dialyxir_vendored, :debugger, :dialyzer, :ex_unit, :hex, :mix],
        flags: [
          # enable only to verify error handling
          # :unmatched_returns,
          :error_handling,
          :unknown,
          :underspecs,
          :extra_return,
          :missing_return
        ]
      ]
    ]
  end

  defp deps do
    # spec_lint requires Elixir ~> 1.18
    if Version.match?(System.version(), ">= 1.18.0") do
      [{:spec_lint, "~> 0.1", only: [:dev, :test], runtime: false}]
    else
      []
    end
  end

  defp aliases do
    [
      test: "cmd mix test"
    ]
  end
end
