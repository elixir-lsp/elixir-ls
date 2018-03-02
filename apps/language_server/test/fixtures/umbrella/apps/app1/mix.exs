defmodule App1.Mixfile do
  use Mix.Project

  def project do
    [app: :app1, version: "0.1.0", deps: deps()]
  end

  def application do
    []
  end

  defp deps do
    [{:app2, in_umbrella: true}]
  end
end
