defmodule ElixirLS.LanguageServer.Providers.SignatureHelp do
  alias ElixirLS.LanguageServer.SourceFile

  def trigger_characters(), do: ["("]

  def signature(%SourceFile{} = source_file, line, character) do
    response =
      case ElixirSense.signature(source_file.text, line + 1, character + 1) do
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

  defp signature_response(%{documentation: documentation, name: name, params: params, spec: spec}) do
    params_info = for param <- params, do: %{"label" => param}

    label = "#{name}(#{Enum.join(params, ", ")})"
    response = %{"label" => label, "parameters" => params_info}

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
