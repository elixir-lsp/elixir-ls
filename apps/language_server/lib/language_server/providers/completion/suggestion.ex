# This code has originally been a part of https://github.com/elixir-lsp/elixir_sense

# Copyright (c) 2017 Marlus Saraiva
# Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the 'Software'), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
# The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

defmodule ElixirLS.LanguageServer.Providers.Completion.Suggestion do
  @moduledoc """
  Provider responsible for finding suggestions for auto-completing.

  It provides suggestions based on a list of pre-defined reducers.

  ## Reducers

  A reducer is a function with the following spec:

      @spec reducer(
        String.t(),
        String.t(),
        State.Env.t(),
        Metadata.t(),
        acc()
      ) :: {:cont | :halt, acc()}

  ## Examples

  Adding suggestions:

      def my_reducer(hint, prefix, env, buffer_metadata, acc) do
        suggestions = ...
        {:cont, %{acc | result: acc.result ++ suggestions}}
      end

  Defining the only set of suggestions to be provided:

      def my_reducer(hint, prefix, env, buffer_metadata, acc) do
        suggestions = ...
        {:halt, %{acc | result: suggestions}}
      end

  Defining a list of suggestions to be provided and allow an extra
  limited set of additional reducers to run next:

      def my_reducer(hint, prefix, env, buffer_metadata, acc) do
        suggestions = ...
        {:cont, %{acc | result: fields, reducers: [:populate_complete_engine, :variables]}}
      end
  """

  alias ElixirSense.Core.Metadata
  alias ElixirLS.LanguageServer.Plugins.ModuleStore
  alias ElixirSense.Core.State
  alias ElixirSense.Core.Parser
  alias ElixirSense.Core.Source
  alias ElixirLS.LanguageServer.Providers.Completion.Reducers

  @type generic :: %{
          type: :generic,
          label: String.t(),
          detail: String.t() | nil,
          documentation: String.t() | nil,
          insert_text: String.t() | nil,
          filter_text: String.t() | nil,
          snippet: String.t() | nil,
          priority: integer() | nil,
          kind: atom(),
          command: map()
        }

  @type suggestion ::
          generic()
          | Reducers.CompleteEngine.t()
          | Reducers.Struct.field()
          | Reducers.Record.field()
          | Reducers.Returns.return()
          | Reducers.Callbacks.callback()
          | Reducers.Protocol.protocol_function()
          | Reducers.Params.param_option()
          | Reducers.TypeSpecs.type_spec()
          | Reducers.Bitstring.bitstring_option()

  @type acc :: %{result: [suggestion], reducers: [atom], context: map}
  @type cursor_context :: %{
          text_before: String.t(),
          text_after: String.t(),
          at_module_body?: boolean(),
          cursor_position: {pos_integer, pos_integer}
        }

  @reducers [
    structs_fields: &Reducers.Struct.add_fields/5,
    record_fields: &Reducers.Record.add_fields/5,
    returns: &Reducers.Returns.add_returns/5,
    callbacks: &Reducers.Callbacks.add_callbacks/5,
    protocol_functions: &Reducers.Protocol.add_functions/5,
    overridable: &Reducers.Overridable.add_overridable/5,
    param_options: &Reducers.Params.add_options/5,
    typespecs: &Reducers.TypeSpecs.add_types/5,
    populate_complete_engine: &Reducers.CompleteEngine.populate/6,
    variables: &Reducers.CompleteEngine.add_variables/5,
    modules: &Reducers.CompleteEngine.add_modules/5,
    functions: &Reducers.CompleteEngine.add_functions/5,
    macros: &Reducers.CompleteEngine.add_macros/5,
    variable_fields: &Reducers.CompleteEngine.add_fields/5,
    attributes: &Reducers.CompleteEngine.add_attributes/5,
    docs_snippets: &Reducers.DocsSnippets.add_snippets/5,
    bitstring_options: &Reducers.Bitstring.add_bitstring_options/5
  ]

  @add_opts_for [:populate_complete_engine]

  @spec suggestions(String.t(), pos_integer, pos_integer, keyword()) :: [Suggestion.suggestion()]
  def suggestions(code, line, column, options \\ []) do
    {prefix = hint, suffix} = Source.prefix_suffix(code, line, column)

    metadata =
      Keyword.get_lazy(options, :metadata, fn ->
        Parser.parse_string(code, true, false, {line, column})
      end)

    {text_before, text_after} = Source.split_at(code, line, column)

    # This works better than Code.Fragment.surround_context
    surround =
      case {prefix, suffix} do
        {"", ""} ->
          nil

        _ ->
          {{line, column - String.length(prefix)}, {line, column + String.length(suffix)}}
      end

    env = Metadata.get_cursor_env(metadata, {line, column}, surround)

    module_store = ModuleStore.build()

    cursor_context = %{
      cursor_position: {line, column},
      text_before: text_before,
      text_after: text_after,
      at_module_body?: Metadata.at_module_body?(env)
    }

    find(hint, env, metadata, cursor_context, module_store, options)
  end

  @doc """
  Finds all suggestions for a hint based on context information.
  """
  @spec find(String.t(), State.Env.t(), Metadata.t(), cursor_context, ModuleStore.t(), keyword()) ::
          [suggestion()]
  def find(
        hint,
        env,
        buffer_metadata,
        cursor_context,
        %{plugins: plugins} = module_store,
        opts \\ []
      ) do
    reducers =
      plugins
      |> Enum.filter(&function_exported?(&1, :reduce, 5))
      |> Enum.map(fn module ->
        {module, &module.reduce/5}
      end)
      |> Enum.concat(@reducers)
      |> maybe_add_opts(opts)

    context =
      plugins
      |> Enum.filter(&function_exported?(&1, :setup, 1))
      |> Enum.reduce(%{module_store: module_store}, fn plugin, context ->
        plugin.setup(context)
      end)

    acc = %{result: [], reducers: Keyword.keys(reducers), context: context}

    %{result: result} =
      Enum.reduce_while(reducers, acc, fn {key, fun}, acc ->
        if key in acc.reducers do
          fun.(hint, env, buffer_metadata, cursor_context, acc)
        else
          {:cont, acc}
        end
      end)

    for item <- result do
      plugins
      |> Enum.filter(&function_exported?(&1, :decorate, 1))
      |> Enum.reduce(item, fn module, item -> module.decorate(item) end)
    end
  end

  defp maybe_add_opts(reducers, opts) do
    Enum.map(reducers, fn {name, reducer} ->
      if name in @add_opts_for do
        {name, reducer_with_opts(reducer, opts)}
      else
        {name, reducer}
      end
    end)
  end

  defp reducer_with_opts(fun, opts) do
    fn a, b, c, d, e -> fun.(a, b, c, d, e, opts) end
  end
end
