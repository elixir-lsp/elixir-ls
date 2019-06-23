defmodule ElixirLS.LanguageServer.Providers.CodeLens do
  @moduledoc """
  Collects the success typings inferred by Dialyzer, translates the syntax to Elixir, and shows them
  inline in the editor as @spec suggestions.

  The server, unfortunately, has no way to force the client to refresh the @spec code lenses when new
  success typings, so we let this request block until we know we have up-to-date results from
  Dialyzer. We rely on the client being able to await this result while still making other requests
  in parallel. If the client is unable to perform requests in parallel, the client or user should
  disable this feature.
  """

  alias ElixirLS.LanguageServer.{Server, SourceFile}
  alias Erl2ex.Convert.{Context, ErlForms}
  alias Erl2ex.Pipeline.{Parse, ModuleData, ExSpec}
  import ElixirLS.LanguageServer.Protocol

  defmodule ContractTranslator do
    def translate_contract(fun, contract) do
      {[%ExSpec{specs: [spec]} | _], _} =
        "-spec foo#{contract}."
        |> Parse.string()
        |> hd()
        |> elem(0)
        |> ErlForms.conv_form(%Context{
          in_type_expr: true,
          module_data: %ModuleData{}
        })

      spec
      |> Macro.postwalk(&tweak_specs/1)
      |> Macro.to_string()
      |> String.replace("()", "")
      |> Code.format_string!(line_length: :infinity)
      |> IO.iodata_to_binary()
      |> String.replace_prefix("foo", to_string(fun))
    end

    defp tweak_specs({:list, _meta, args}) do
      case args do
        [{:{}, _, [{:atom, _, []}, {wild, _, _}]}] when wild in [:_, :any] -> quote do: keyword()
        list -> list
      end
    end

    defp tweak_specs({:nonempty_list, _meta, args}) do
      case args do
        [{:any, _, []}] -> quote do: [...]
        _ -> args ++ quote do: [...]
      end
    end

    defp tweak_specs({:%{}, _meta, fields}) do
      fields =
        Enum.map(fields, fn
          {:map_field_exact, _, [key, value]} -> {key, value}
          {key, value} -> quote do: {optional(unquote(key)), unquote(value)}
          field -> field
        end)
        |> Enum.reject(&match?({{:optional, _, [{:any, _, []}]}, {:any, _, []}}, &1))

      fields
      |> Enum.find_value(fn
        {:__struct__, struct_type} when is_atom(struct_type) -> struct_type
        _ -> nil
      end)
      |> case do
        nil -> {:%{}, [], fields}
        struct_type -> {{:., [], [struct_type, :t]}, [], []}
      end
    end

    # Undo conversion of _ to any() when inside binary spec
    defp tweak_specs({:<<>>, _, children}) do
      children =
        Macro.postwalk(children, fn
          {:any, _, []} -> quote do: _
          other -> other
        end)

      {:<<>>, [], children}
    end

    defp tweak_specs({:_, _, _}) do
      quote do: any()
    end

    defp tweak_specs({:when, [], [spec, substitutions]}) do
      substitutions = Enum.reject(substitutions, &match?({:_, {:any, _, []}}, &1))

      case substitutions do
        [] -> spec
        _ -> {:when, [], [spec, substitutions]}
      end
    end

    defp tweak_specs(node) do
      node
    end
  end

  def code_lens(uri, text) do
    resp =
      for {_, line, {mod, fun, arity}, contract} <- Server.suggest_contracts(uri),
          SourceFile.function_def_on_line?(text, line, fun),
          spec = ContractTranslator.translate_contract(fun, contract) do
        %{
          "range" => range(line - 1, 0, line - 1, 0),
          "command" => %{
            "title" => "@spec #{spec}",
            "command" => "spec",
            "arguments" => [
              %{
                "uri" => uri,
                "mod" => to_string(mod),
                "fun" => to_string(fun),
                "arity" => arity,
                "spec" => spec,
                "line" => line
              }
            ]
          }
        }
      end

    {:ok, resp}
  end
end
