defmodule ElixirLS.LanguageServer.Fixtures.GenLSPDep.Mixfile do
  use Mix.Project

  def project do
    [app: :els_gen_lsp_dep_test, version: "0.1.0", deps: [{:gen_lsp, path: "gen_lsp"}]]
  end

  def application do
    []
  end
end
