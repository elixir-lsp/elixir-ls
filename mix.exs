defmodule ElixirLS.Mixfile do
  use Mix.Project

  @dep_versions __DIR__
                |> Path.join("dep_versions.exs")
                |> Code.eval_file()
                |> elem(0)

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
    [
      # elixir_sense pins its own (older) toxic2 ref; overrides only apply from the top level,
      # so the umbrella-wide pin lives here (language_server declares the same ref).
      {:toxic2, github: "lukaszsamson/toxic2", ref: @dep_versions[:toxic2], override: true}
    ]
  end

  defp aliases do
    [
      test: "cmd mix test"
    ]
  end
end
