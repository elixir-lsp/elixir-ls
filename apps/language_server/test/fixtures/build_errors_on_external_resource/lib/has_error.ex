defmodule ElixirLS.LanguageServer.Fixtures.BuildErrorsOnExternalResource.HasError do
  EEx.compile_file("lib/template.eex", line: 1)
end
