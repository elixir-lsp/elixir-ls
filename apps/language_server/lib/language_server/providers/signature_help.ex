defmodule ElixirLS.LanguageServer.Providers.SignatureHelp do
  def signature(source_file, line, character) do
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
      {"", ""} -> response
      {"", _} -> Map.put(response, "documentation", documentation)
      {_, _} -> Map.put(response, "documentation", "#{spec}\n#{documentation}")
    end
  end
end
