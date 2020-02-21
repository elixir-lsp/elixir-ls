defmodule ElixirLS.Mixfile do
  use Mix.Project

  def project do
    [
      version: "1.0.0",
      apps_path: "apps",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      build_per_environment: false,
      deps: deps(),
      elixir: ">= 1.9.0",
      releases: releases()
    ]
  end

  defp releases do
    [
      # TODO add debugger as separate or mixed in application?
      language_server: [
        applications: [language_server: :permanent],
#        steps: [:assemble, :tar] TODO enable, slows down development too much
      ]
    ]
  end

  defp deps do
    []
  end
end
