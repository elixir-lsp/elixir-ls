defmodule Eels.MixProject do
  use Mix.Project

  def project do
    [
      app: :eels,
      version: "0.1.0",
      elixir: "~> 1.7",
      start_permanent: false,
      description: "Embedded part of Elixir LSP Server",
      elixirc_paths: ["priv/lib"],
      package: package(),
      deps: deps()
    ]
  end

  def application do
    [
      applications: []
    ]
  end

  defp package do
    [
      licenses: ["Apache"],
      links: %{
        "github" => "https://github.com/elixir-lsp/elixir-ls"
      }
    ]
  end

  defp deps do
    [
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end
end
