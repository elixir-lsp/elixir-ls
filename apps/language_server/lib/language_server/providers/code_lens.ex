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
  alias ElixirSense.Core.Parser
  alias ElixirSense.Core.State
  alias Erl2ex.Convert.{Context, ErlForms}
  alias Erl2ex.Pipeline.{Parse, ModuleData, ExSpec}
  import ElixirLS.LanguageServer.Protocol

  defmodule ContractTranslator do
    def translate_contract(fun, contract, is_macro) do
      # FIXME: Private module
      {[%ExSpec{specs: [spec]} | _], _} =
        "-spec foo#{contract}."
        # FIXME: Private module
        |> Parse.string()
        |> hd()
        |> elem(0)
        # FIXME: Private module
        |> ErlForms.conv_form(%Context{
          in_type_expr: true,
          # FIXME: Private module
          module_data: %ModuleData{}
        })

      spec
      |> Macro.postwalk(&tweak_specs/1)
      |> drop_macro_env(is_macro)
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

    defp drop_macro_env(ast, false), do: ast

    defp drop_macro_env({:"::", [], [{:foo, [], [_env | rest]}, res]}, true) do
      {:"::", [], [{:foo, [], rest}, res]}
    end
  end

  def spec_code_lens(server_instance_id, uri, text) do
    resp =
      for {_, line, {mod, fun, arity}, contract, is_macro} <- Server.suggest_contracts(uri),
          SourceFile.function_def_on_line?(text, line, fun),
          spec = ContractTranslator.translate_contract(fun, contract, is_macro) do
        build_code_lens(
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

  def test_code_lens(uri, src) do
    file_path = SourceFile.path_from_uri(uri)

    if imports?(src, ExUnit.Case) do
      test_calls = calls_to(src, :test)
      describe_calls = calls_to(src, :describe)

      calls_lenses =
        for {line, _col} <- test_calls ++ describe_calls do
          test_filter = "#{file_path}:#{line}"

          build_code_lens(line, "Run test", "elixir.test.run", test_filter)
        end

      file_lens = build_code_lens(1, "Run test", "elixir.test.run", file_path)

      {:ok, [file_lens | calls_lenses]}
    end
  end

  @spec imports?(String.t(), [atom()] | atom()) :: boolean()
  defp imports?(buffer, modules) do
    buffer_file_metadata =
      buffer
      |> Parser.parse_string(true, true, 1)

    imports_set =
      buffer_file_metadata.lines_to_env
      |> get_imports()
      |> MapSet.new()

    modules
    |> List.wrap()
    |> MapSet.new()
    |> MapSet.subset?(imports_set)
  end

  defp get_imports(lines_to_env) do
    %State.Env{imports: imports} =
      lines_to_env
      |> Enum.max_by(fn {k, _v} -> k end)
      |> elem(1)

    imports
  end

  @spec calls_to(String.t(), atom() | {atom(), integer()}) :: [{pos_integer(), pos_integer()}]
  defp calls_to(buffer, function) do
    buffer_file_metadata =
      buffer
      |> Parser.parse_string(true, true, 1)

    buffer_file_metadata.calls
    |> Enum.map(fn {_k, v} -> v end)
    |> List.flatten()
    |> Enum.filter(fn call_info -> call_info.func == function end)
    |> Enum.map(fn call -> call.position end)
  end

  def build_code_lens(line, title, command, argument) do
    %{
      "range" => range(line - 1, 0, line - 1, 0),
      "command" => %{
        "title" => title,
        "command" => command,
        "arguments" => [argument]
      }
    }
  end
end
