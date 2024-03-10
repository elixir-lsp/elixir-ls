# This code has originally been a part of https://github.com/elixir-lsp/elixir_sense

# Copyright (c) 2017 Marlus Saraiva
# Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the 'Software'), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
# The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

defmodule ElixirLS.LanguageServer.Providers.Completion.Reducers.Bitstring do
  @moduledoc false

  alias ElixirSense.Core.Bitstring
  alias ElixirSense.Core.Source

  @type bitstring_option :: %{
          type: :bitstring_option,
          name: String.t()
        }

  @doc """
  A reducer that adds suggestions of bitstring options.
  """
  def add_bitstring_options(_hint, _env, _buffer_metadata, cursor_context, acc) do
    prefix = cursor_context.text_before

    case Source.bitstring_options(prefix) do
      candidate when not is_nil(candidate) ->
        parsed = Bitstring.parse(candidate)

        list =
          for option <- Bitstring.available_options(parsed),
              candidate_part = candidate |> String.split("-") |> List.last(),
              option_str = option |> Atom.to_string(),
              String.starts_with?(option_str, candidate_part) do
            %{
              name: option_str,
              type: :bitstring_option
            }
          end

        {:cont, %{acc | result: acc.result ++ list}}

      _ ->
        {:cont, acc}
    end
  end
end
