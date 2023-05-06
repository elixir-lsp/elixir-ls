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
      elixir: ">= 1.12.0",
      dialyzer: [
        plt_add_apps: [:dialyxir_vendored, :debugger, :dialyzer, :ex_unit, :hex],
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
    []
  end

  defp aliases do
    [
      test: "cmd mix test"
    ]
  end
end
