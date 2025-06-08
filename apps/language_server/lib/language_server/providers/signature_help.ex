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
          %GenLSP.Structures.SignatureHelp{
            active_signature: 0,
            active_parameter: active_param,
            signatures: Enum.map(signatures, &signature_response/1)
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
    params_info = for param <- params, do: %GenLSP.Structures.ParameterInformation{label: param}

    label = "#{name}(#{Enum.join(params, ", ")})"
    
    base_signature = %GenLSP.Structures.SignatureInformation{
      label: label,
      parameters: params_info
    }

    base_signature =
      case signature do
        %{active_param: active_param} ->
          %{base_signature | active_parameter: active_param}

        _ ->
          base_signature
      end

    case {spec, documentation} do
      {"", ""} ->
        put_metadata(base_signature, metadata)

      {"", _} ->
        put_documentation(base_signature, documentation)
        |> put_metadata(metadata)

      {_, _} ->
        spec_str = SourceFile.format_spec(spec, line_length: 42)

        put_documentation(base_signature, "#{documentation}\n#{spec_str}")
        |> put_metadata(metadata)
    end
  end

  defp put_documentation(signature = %GenLSP.Structures.SignatureInformation{}, documentation) do
    %{signature | documentation: %GenLSP.Structures.MarkupContent{
      kind: GenLSP.Enumerations.MarkupKind.markdown(),
      value: documentation
    }}
  end

  defp put_metadata(signature = %GenLSP.Structures.SignatureInformation{}, metadata) do
    if metadata do
      metadata_md = MarkdownUtils.get_metadata_md(metadata)

      if metadata_md != "" do
        current_docs = case signature.documentation do
          %GenLSP.Structures.MarkupContent{value: value} -> value
          _ -> ""
        end
        put_documentation(signature, metadata_md <> "\n\n" <> current_docs)
      else
        signature
      end
    else
      signature
    end
  end
end
