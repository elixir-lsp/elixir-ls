# This code has originally been a part of https://github.com/elixir-lsp/elixir_sense

# Copyright (c) 2017 Marlus Saraiva
# Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the 'Software'), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
# The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

defmodule ElixirLS.LanguageServer.Providers.Completion.Reducers.Params do
  @moduledoc false

  alias ElixirSense.Core.Binding
  alias ElixirSense.Core.Introspection
  alias ElixirSense.Core.Metadata
  alias ElixirSense.Core.Source
  alias ElixirSense.Core.TypeInfo
  alias ElixirLS.Utils.Matcher

  @type param_option :: %{
          type: :param_option,
          name: String.t(),
          origin: String.t(),
          type_spec: String.t(),
          doc: String.t(),
          expanded_spec: String.t()
        }

  @doc """
  A reducer that adds suggestions of keyword list options.
  """
  def add_options(hint, env, buffer_metadata, cursor_context, acc) do
    prefix = cursor_context.text_before

    binding_env = Binding.from_env(env, buffer_metadata)

    %Metadata{mods_funs_to_positions: mods_funs, types: metadata_types} = buffer_metadata

    with %{
           candidate: {mod, fun},
           elixir_prefix: elixir_prefix,
           npar: npar
         } <-
           Source.which_func(prefix, binding_env),
         {mod, fun, true, :mod_fun} <-
           Introspection.actual_mod_fun(
             {mod, fun},
             env,
             mods_funs,
             metadata_types,
             cursor_context.cursor_position,
             not elixir_prefix
           ) do
      list = for {name, type} <- ElixirSense.Core.Options.get_param_options(mod, fun, npar + 1, buffer_metadata) do
        %{
          doc: "",
          expanded_spec: "",
          name: name |> Atom.to_string(),
          origin: inspect(mod),
          type: :param_option,
          type_spec: Introspection.to_string_with_parens(type)
        }
      end

      
      # list =
      #   if Code.ensure_loaded?(mod) do
      #     if function_exported?(mod, fun, npar + 1) do
      #       TypeInfo.extract_param_options(mod, fun, npar)
      #     else
      #       TypeInfo.extract_param_options(mod, :"MACRO-#{fun}", npar + 1)
      #     end
      #     |> options_to_suggestions(mod)
      #     |> Enum.filter(&Matcher.match?(&1.name, hint))
      #     |> dbg
      #   else
      #     # TODO metadata?
      #     dbg(buffer_metadata.specs)

      #     with %ElixirSense.Core.State.SpecInfo{specs: [spec | _]} = info <-
      #            buffer_metadata.specs[{mod, fun, npar + 1}],
      #          {:ok,
      #           {:@, _,
      #            [
      #              {:spec, _,
      #               [
      #                 {:"::", _,
      #                  [
      #                    {^fun, _, params},
      #                    _
      #                  ]}
      #               ]}
      #            ]}}
      #          when is_list(params) <- Code.string_to_quoted(spec),
      #          {:list, _, [options]} <- List.last(params) |> dbg do
      #       for {name, type} <- extract_options(options, []) do
      #         %{
      #           doc: "",
      #           expanded_spec: "",
      #           name: name |> Atom.to_string(),
      #           origin: inspect(mod),
      #           type: :param_option,
      #           type_spec: Introspection.to_string_with_parens(type)
      #         }
      #       end
      #       |> dbg
      #     else
      #       _ -> []
      #     end
      #   end

      {:cont, %{acc | result: acc.result ++ list}}
    else
      _ ->
        {:cont, acc}
    end
  end

  defp extract_options({:|, _, [{atom, type}, rest]}, acc) when is_atom(atom) do
    extract_options(rest, [{atom, type} | acc])
  end

  defp extract_options({:|, _, [_other, rest]}, acc) do
    extract_options(rest, acc)
  end

  defp extract_options({atom, type}, acc) when is_atom(atom) do
    [{atom, type} | acc]
  end

  defp extract_options(_other, acc), do: acc

  defp options_to_suggestions(options, original_module) do
    Enum.map(options, fn
      {mod, name, type} ->
        TypeInfo.get_type_info(mod, type, original_module)
        |> Map.merge(%{type: :param_option, name: name |> Atom.to_string()})

      {mod, name} ->
        %{
          doc: "",
          expanded_spec: "",
          name: name |> Atom.to_string(),
          origin: inspect(mod),
          type: :param_option,
          type_spec: ""
        }
    end)
  end
end
