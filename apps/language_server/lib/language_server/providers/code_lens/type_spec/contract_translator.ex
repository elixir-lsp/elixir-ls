defmodule ElixirLS.LanguageServer.Providers.CodeLens.TypeSpec.ContractTranslator do
  @moduledoc false
  alias Erl2ex.Convert.{Context, ErlForms}
  alias Erl2ex.Pipeline.{Parse, ModuleData, ExSpec}

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
      [{:{}, _, [{:atom, _, []}, other]}] -> quote do: keyword(unquote(other))
      [{:any, _, []}] -> quote do: list()
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

    translate_map(fields)
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

  defp tweak_specs([{:->, _, [[{:..., _, _}], {:any, _, []}]}]) do
    quote do: fun()
  end

  defp tweak_specs(node) do
    node
  end

  defp drop_macro_env(ast, false), do: ast

  defp drop_macro_env({:"::", [], [{:foo, [], [_env | rest]}, res]}, true) do
    {:"::", [], [{:foo, [], rest}, res]}
  end

  defp translate_map([
         {:__struct__, {:atom, _, []}},
         {{:optional, _, [{:atom, _, []}]}, {:any, _, []}}
       ]) do
    quote do: struct()
  end

  defp translate_map([
         {{:optional, _, [{:any, _, []}]}, {:any, _, []}}
       ]) do
    quote do: map()
  end

  defp translate_map(fields) do
    struct_type =
      fields
      |> Enum.find_value(fn
        {:__struct__, struct_type} when is_atom(struct_type) -> struct_type
        _ -> nil
      end)

    translate_map(struct_type, fields)
  end

  defp translate_map(nil, fields) do
    {:%{}, [], fields}
  end

  defp translate_map(struct_type, fields) do
    struct_type_spec_exists =
      ElixirSense.Core.Normalized.Typespec.get_types(struct_type)
      |> Enum.any?(&match?({kind, {:t, _, []}} when kind in [:type, :opaque], &1))

    if struct_type_spec_exists do
      # struct_type.t/0 public/opaque type exists, assume it's a struct
      {{:., [], [struct_type, :t]}, [], []}
    else
      # translate map AST to struct AST
      fields = fields |> Enum.reject(&match?({:__struct__, _}, &1))
      map = {:%{}, [], fields}
      {:%, [], [struct_type, map]}
    end
  end
end
