defmodule ElixirLS.LanguageServer.Providers.SignatureHelp do
  @moduledoc """
  Provider handling textDocument/signatureHelp
  """
  alias ElixirLS.LanguageServer.{SourceFile, Parser}

  def trigger_characters(), do: ["(", ","]

  def signature(%Parser.Context{source_file: %SourceFile{} = source_file, metadata: metadata}, line, character) do
    {line, character} = SourceFile.lsp_position_to_elixir(source_file.text, {line, character})

    response =
      case ElixirSense.signature(source_file.text, line, character, if(metadata, do: [metadata: metadata], else: [])) do
        %{active_param: active_param, signatures: signatures} ->
          %{
            "activeSignature" => 0,
            "activeParameter" => active_param,
            "signatures" => Enum.map(signatures, &signature_response/1)
          }

        :none ->
          nil
      end

    {:ok, response}
  end

  defp signature_response(
         %{documentation: documentation, name: name, params: params, spec: spec} = signature
       ) do
    params_info = for param <- params, do: %{"label" => param}

    label = "#{name}(#{Enum.join(params, ", ")})"
    response = %{"label" => label, "parameters" => params_info}

    response =
      case signature do
        %{active_param: active_param} ->
          Map.put(response, "activeParameter", active_param)

        _ ->
          response
      end

    case {spec, documentation} do
      {"", ""} ->
        response

      {"", _} ->
        put_documentation(response, documentation)

      {_, _} ->
        spec_str = SourceFile.format_spec(spec, line_length: 42)
        put_documentation(response, "#{documentation}\n#{spec_str}")
    end
  end

  defp put_documentation(response, documentation) do
    Map.put(response, "documentation", %{"kind" => "markdown", "value" => documentation})
  end
end
