defmodule ElixirLS.LanguageServer.Providers.SignatureHelp do
  @moduledoc """
  Provider handling textDocument/signatureHelp
  """
  alias ElixirLS.LanguageServer.{SourceFile, Parser}
  alias ElixirLS.LanguageServer.Providers.SignatureHelp.Signature
  alias ElixirLS.LanguageServer.MarkdownUtils

  def trigger_characters(), do: ["(", ","]

  def signature(
        %Parser.Context{source_file: %SourceFile{} = source_file, metadata: metadata},
        line,
        character
      ) do
    response =
      case Signature.signature(source_file.text, line, character, metadata: metadata) do
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
         %{
           documentation: documentation,
           name: name,
           params: params,
           spec: spec,
           metadata: metadata
         } = signature
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
        put_metadata(response, metadata)

      {"", _} ->
        put_documentation(response, documentation)
        |> put_metadata(metadata)

      {_, _} ->
        spec_str = SourceFile.format_spec(spec, line_length: 42)

        put_documentation(response, "#{documentation}\n#{spec_str}")
        |> put_metadata(metadata)
    end
  end

  defp put_documentation(response, documentation) do
    Map.put(response, "documentation", %{"kind" => "markdown", "value" => documentation})
  end

  defp put_metadata(response, metadata) do
    if metadata do
      metadata_md = MarkdownUtils.get_metadata_md(metadata)

      if metadata_md != "" do
        current_docs = get_in(response, ["documentation", "value"]) || ""
        put_documentation(response, metadata_md <> "\n\n" <> current_docs)
      else
        response
      end
    else
      response
    end
  end
end
