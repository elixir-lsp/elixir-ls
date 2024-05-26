# This code has originally been a part of https://github.com/elixir-lsp/elixir_sense

# Copyright (c) 2017 Marlus Saraiva
# Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the 'Software'), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
# The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

defmodule ElixirLS.LanguageServer.Providers.Completion.Reducers.CompleteEngine do
  @moduledoc false

  alias ElixirSense.Core.Metadata
  alias ElixirSense.Core.Source
  alias ElixirSense.Core.State
  alias ElixirLS.Utils.CompletionEngine
  alias ElixirLS.LanguageServer.Providers.Completion.Reducer

  @type t() :: CompletionEngine.t()

  @doc """
  A reducer that populates the context with the suggestions provided by
  the `ElixirLS.Utils.CompletionEngine` module.

  The suggestions are grouped by type and saved in the context under the
  `:complete_engine_suggestions_by_type` key and can be accessed by any reducer
  that runs after.

  Available suggestions:

    * Modules
    * Functions
    * Macros
    * Variables
    * Module attributes
    * Variable fields

  """
  def populate(hint, env, buffer_metadata, context, acc, opts \\ []) do
    suggestions =
      find_mods_funcs(
        hint,
        context.cursor_position,
        env,
        buffer_metadata,
        context.text_before,
        opts
      )

    suggestions_by_type = Enum.group_by(suggestions, & &1.type)

    {:cont, Reducer.put_context(acc, :complete_engine, suggestions_by_type)}
  end

  @doc """
  A reducer that adds suggestions of existing modules.

  Note: requires populate/5.
  """
  def add_modules(_hint, _env, _file_metadata, _context, acc) do
    add_suggestions(:module, acc)
  end

  @doc """
  A reducer that adds suggestions of existing functions.

  Note: requires populate/5.
  """
  def add_functions(_hint, _env, _file_metadata, _context, acc) do
    add_suggestions(:function, acc)
  end

  @doc """
  A reducer that adds suggestions of existing macros.

  Note: requires populate/5.
  """
  def add_macros(_hint, _env, _file_metadata, _context, acc) do
    add_suggestions(:macro, acc)
  end

  @doc """
  A reducer that adds suggestions of variable fields.

  Note: requires populate/5.
  """
  def add_fields(_hint, _env, _file_metadata, _context, acc) do
    add_suggestions(:field, acc)
  end

  @doc """
  A reducer that adds suggestions of existing module attributes.

  Note: requires populate/5.
  """
  def add_attributes(_hint, _env, _file_metadata, _context, acc) do
    add_suggestions(:attribute, acc)
  end

  @doc """
  A reducer that adds suggestions of existing variables.

  Note: requires populate/5.
  """
  def add_variables(_hint, _env, _file_metadata, _context, acc) do
    add_suggestions(:variable, acc)
  end

  defp add_suggestions(type, acc) do
    suggestions_by_type = Reducer.get_context(acc, :complete_engine)
    list = Map.get(suggestions_by_type, type, [])
    {:cont, %{acc | result: acc.result ++ list}}
  end

  defp find_mods_funcs(
         hint,
         cursor_position,
         %State.Env{
           module: module
         } = env,
         %Metadata{} = metadata,
         text_before,
         opts
       ) do
    hint =
      case Source.get_v12_module_prefix(text_before, module) do
        nil ->
          hint

        module_string ->
          # multi alias syntax detected
          # prepend module prefix before running completion
          prefix = module_string <> "."
          prefix <> hint
      end

    hint =
      if String.starts_with?(hint, "__MODULE__") do
        hint |> String.replace_leading("__MODULE__", inspect(module))
      else
        hint
      end

    CompletionEngine.complete(hint, env, metadata, cursor_position, opts)
  end
end
