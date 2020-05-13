defmodule ElixirLS.LanguageServer.Fixtures.BuildErrorsOnExternalResource.Mixfile do
  use Mix.Project

  def project do
    [app: :els_build_errors_test, version: "0.1.0"]
  end

  def application do
    []
  end
end
