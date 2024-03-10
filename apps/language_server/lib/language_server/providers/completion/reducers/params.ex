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
  alias ElixirSense.Core.State
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

    %State.Env{
      imports: imports,
      requires: requires,
      aliases: aliases,
      module: module,
      scope: scope
    } = env

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
             imports,
             requires,
             if(elixir_prefix, do: [], else: aliases),
             module,
             scope,
             mods_funs,
             metadata_types,
             {1, 1}
           ) do
      list =
        if Code.ensure_loaded?(mod) do
          TypeInfo.extract_param_options(mod, fun, npar)
          |> Kernel.++(TypeInfo.extract_param_options(mod, :"MACRO-#{fun}", npar + 1))
          |> options_to_suggestions(mod)
          |> Enum.filter(&Matcher.match?(&1.name, hint))
        else
          # TODO metadata?
          []
        end

      {:cont, %{acc | result: acc.result ++ list}}
    else
      _ ->
        {:cont, acc}
    end
  end

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
