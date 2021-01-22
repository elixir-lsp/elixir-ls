defmodule ElixirLS.LanguageServer.Providers.CodeLens.TypeSpec do
  @moduledoc """
  Collects the success typings inferred by Dialyzer, translates the syntax to Elixir, and shows them
  inline in the editor as @spec suggestions.

  The server, unfortunately, has no way to force the client to refresh the @spec code lenses when new
  success typings, so we let this request block until we know we have up-to-date results from
  Dialyzer. We rely on the client being able to await this result while still making other requests
  in parallel. If the client is unable to perform requests in parallel, the client or user should
  disable this feature.
  """

  alias ElixirLS.LanguageServer.Providers.CodeLens
  alias ElixirLS.LanguageServer.{Server, SourceFile}
  alias ElixirLS.LanguageServer.Providers.CodeLens.TypeSpec.ContractTranslator

  def code_lens(server_instance_id, uri, text) do
    resp =
      for {_, line, {mod, fun, arity}, contract, is_macro} <- Server.suggest_contracts(uri),
          SourceFile.function_def_on_line?(text, line, fun),
          spec = ContractTranslator.translate_contract(fun, contract, is_macro) do
        CodeLens.build_code_lens(
          line,
          "@spec #{spec}",
          "spec:#{server_instance_id}",
          %{
            "uri" => uri,
            "mod" => to_string(mod),
            "fun" => to_string(fun),
            "arity" => arity,
            "spec" => spec,
            "line" => line
          }
        )
      end

    {:ok, resp}
  end
end
