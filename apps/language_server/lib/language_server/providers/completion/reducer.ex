defmodule ElixirLS.LanguageServer.Providers.Completion.Reducer do
  @moduledoc !"""
             Provides common functions for reducers.
             """

  def put_context(acc, key, value) do
    updated_context = Map.put(acc.context, key, value)
    put_in(acc.context, updated_context)
  end

  def get_context(acc, key) do
    get_in(acc, [:context, key])
  end
end
