# This code has originally been a part of https://github.com/elixir-lsp/elixir_sense

# Copyright (c) 2017 Marlus Saraiva
# Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the 'Software'), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
# The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

defmodule ElixirLS.LanguageServer.Providers.Completion.GenericReducer do
  @moduledoc """
  A generic behaviour for reducers that customize suggestions
  according to the cursor's position in a function call.
  """

  require Logger
  # TODO change/move this
  alias ElixirLS.LanguageServer.Plugins.Util

  @type func_call :: {module, fun :: atom, arg :: non_neg_integer, any}
  @type suggestion :: ElixirLS.LanguageServer.Providers.Completion.Suggestion.generic()
  @type reducer_name :: atom()

  @callback suggestions(hint :: String.t(), func_call, [func_call], opts :: map) ::
              :ignore
              | {:add | :override, [suggestion]}
              | {:add | :override, [suggestion], [reducer_name]}

  defmacro __using__(_) do
    quote do
      @behaviour unquote(__MODULE__)

      def reduce(hint, env, buffer_metadata, cursor_context, acc) do
        unquote(__MODULE__).reduce(__MODULE__, hint, env, buffer_metadata, cursor_context, acc)
      end
    end
  end

  def reduce(reducer, hint, env, buffer_metadata, cursor_context, acc) do
    text_before = cursor_context.text_before

    opts = %{
      env: env,
      buffer_metadata: buffer_metadata,
      cursor_context: cursor_context,
      module_store: acc.context.module_store
    }

    case Util.func_call_chain(text_before, env, buffer_metadata) do
      [func_call | _] = chain ->
        if function_exported?(reducer, :suggestions, 4) do
          try do
            reducer.suggestions(hint, func_call, chain, opts) |> handle_suggestions(acc)
          catch
            kind, payload ->
              {payload, stacktrace} = Exception.blame(kind, payload, __STACKTRACE__)
              message = Exception.format(kind, payload, stacktrace)
              Logger.error("Error in suggestions reducer: #{message}")
              {:cont, acc}
          end
        else
          {:cont, acc}
        end

      [] ->
        if function_exported?(reducer, :suggestions, 2) do
          try do
            reducer.suggestions(hint, opts) |> handle_suggestions(acc)
          catch
            kind, payload ->
              {payload, stacktrace} = Exception.blame(kind, payload, __STACKTRACE__)
              message = Exception.format(kind, payload, stacktrace)
              Logger.error("Error in suggestions reducer: #{message}")
              {:cont, acc}
          end
        else
          {:cont, acc}
        end
    end
  end

  def handle_suggestions(:ignore, acc) do
    {:cont, acc}
  end

  def handle_suggestions({:add, suggestions}, acc) do
    {:cont, %{acc | result: suggestions ++ acc.result}}
  end

  def handle_suggestions({:add, suggestions, reducers}, acc) do
    {:cont, %{acc | result: suggestions ++ acc.result, reducers: reducers}}
  end

  def handle_suggestions({:override, suggestions}, acc) do
    {:halt, %{acc | result: suggestions}}
  end

  def handle_suggestions({:override, suggestions, reducers}, acc) do
    {:cont, %{acc | result: suggestions, reducers: reducers}}
  end
end
