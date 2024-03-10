# This code has originally been a part of https://github.com/elixir-lsp/elixir_sense

# Copyright (c) 2017 Marlus Saraiva
# Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the 'Software'), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
# The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

defmodule ElixirLS.LanguageServer.Providers.Completion.Reducers.Returns do
  @moduledoc false

  alias ElixirSense.Core.Introspection
  alias ElixirSense.Core.Metadata
  alias ElixirSense.Core.State

  @type return :: %{
          type: :return,
          description: String.t(),
          spec: String.t(),
          snippet: String.t()
        }

  @doc """
  A reducer that adds suggestions of possible return values.
  """
  def add_returns(
        "" = _hint,
        %State.Env{scope: {fun, arity}} = env,
        buffer_metadata,
        _context,
        acc
      ) do
    %State.Env{module: current_module, behaviours: behaviours, protocol: protocol} = env
    %Metadata{specs: specs} = buffer_metadata

    spec_returns =
      case specs[{current_module, fun, arity}] do
        nil ->
          []

        %State.SpecInfo{specs: info_specs} ->
          for spec <- info_specs,
              {:ok, {:@, _, [{_, _, [quoted]}]}} <- [Code.string_to_quoted(spec)],
              return <- Introspection.get_returns_from_spec_ast(quoted) do
            format_return(return)
          end
      end

    callbacks =
      for mod <- behaviours,
          protocol == nil or mod != elem(protocol, 0) do
        case specs[{mod, fun, arity}] do
          nil ->
            for return <- Introspection.get_returns_from_callback(mod, fun, arity) do
              format_return(return)
            end

          %State.SpecInfo{specs: info_specs} ->
            for spec <- info_specs,
                {:ok, {:@, _, [{_, _, [quoted]}]}} <- [Code.string_to_quoted(spec)],
                return <- Introspection.get_returns_from_spec_ast(quoted) do
              format_return(return)
            end
        end
      end
      |> List.flatten()

    protocol_functions =
      case protocol do
        {proto, _implementations} ->
          case specs[{proto, fun, arity}] do
            nil ->
              for return <- Introspection.get_returns_from_callback(proto, fun, arity) do
                format_return(return)
              end

            %State.SpecInfo{specs: info_specs} ->
              for spec <- info_specs,
                  {:ok, {:@, _, [{:callback, _, [quoted]}]}} <- [Code.string_to_quoted(spec)],
                  return <- Introspection.get_returns_from_spec_ast(quoted) do
                format_return(return)
              end
          end

        nil ->
          []
      end

    list = callbacks ++ protocol_functions ++ spec_returns
    {:cont, %{acc | result: acc.result ++ list}}
  end

  def add_returns(_hint, _env, _buffer_metadata, _context, acc) do
    {:cont, acc}
  end

  defp format_return(return) do
    %{
      type: :return,
      description: return.description,
      spec: return.spec,
      snippet: return.snippet
    }
  end
end
