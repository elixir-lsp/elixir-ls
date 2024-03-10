# This code has originally been a part of https://github.com/elixir-lsp/elixir_sense

# Copyright (c) 2017 Marlus Saraiva
# Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the 'Software'), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
# The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

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
