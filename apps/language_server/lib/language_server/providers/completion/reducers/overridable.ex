# This code has originally been a part of https://github.com/elixir-lsp/elixir_sense

# Copyright (c) 2017 Marlus Saraiva
# Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the 'Software'), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
# The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

defmodule ElixirLS.LanguageServer.Providers.Completion.Reducers.Overridable do
  @moduledoc false

  alias ElixirSense.Core.Introspection
  alias ElixirSense.Core.State
  alias ElixirLS.Utils.Matcher

  @doc """
  A reducer that adds suggestions of overridable functions.
  """

  def add_overridable(
        hint,
        env = %State.Env{typespec: nil, module: module},
        metadata,
        _cursor_context,
        acc
      )
      when not is_nil(module) do
    %State.Env{protocol: protocol, behaviours: behaviours, module: module} = env

    # overridable behaviour callbacks are returned by Reducers.Callbacks
    behaviour_callbacks =
      Enum.flat_map(behaviours, fn
        mod when is_atom(mod) and (protocol == nil or mod != elem(protocol, 0)) ->
          for %{
                name: name,
                arity: arity
              } <-
                Introspection.get_callbacks_with_docs(mod) do
            {name, arity}
          end

        _ ->
          []
      end)

    # no need to care of default args here
    # only the max arity version can be overridden
    list =
      for {{^module, name, arity}, %State.ModFunInfo{overridable: {true, origin}} = info}
          when is_integer(arity) <- metadata.mods_funs_to_positions,
          def_prefix?(hint, info.type) or Matcher.match?("#{name}", hint),
          {name, arity} not in behaviour_callbacks do
        spec =
          case metadata.specs[{module, name, arity}] do
            %State.SpecInfo{specs: specs} -> specs |> Enum.join("\n")
            nil -> ""
          end

        args_list =
          info.params
          |> List.last()
          |> Enum.with_index()
          |> Enum.map(&Introspection.param_to_var/1)

        args = args_list |> Enum.join(", ")

        subtype =
          case State.ModFunInfo.get_category(info) do
            :function -> :callback
            :macro -> :macrocallback
          end

        %{
          type: :callback,
          subtype: subtype,
          name: Atom.to_string(name),
          arity: arity,
          args: args,
          args_list: args_list,
          origin: inspect(origin),
          summary: Introspection.extract_summary_from_docs(info.doc),
          metadata: info.meta,
          spec: spec
        }
      end

    {:cont, %{acc | result: acc.result ++ Enum.sort(list)}}
  end

  def add_overridable(_hint, %State.Env{}, _metadata, _cursor_context, acc),
    do: {:cont, acc}

  defp def_prefix?(hint, type) when type in [:defmacro, :defmacrop] do
    String.starts_with?("defmacro", hint)
  end

  defp def_prefix?(hint, type) when type in [:defguard, :defguardp] do
    String.starts_with?("defguard", hint)
  end

  defp def_prefix?(hint, type) when type in [:def, :defp, :defdelegate] do
    String.starts_with?("def", hint)
  end
end
