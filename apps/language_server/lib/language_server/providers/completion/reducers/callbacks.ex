# This code has originally been a part of https://github.com/elixir-lsp/elixir_sense

# Copyright (c) 2017 Marlus Saraiva
# Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the 'Software'), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
# The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

defmodule ElixirLS.LanguageServer.Providers.Completion.Reducers.Callbacks do
  @moduledoc false

  alias ElixirSense.Core.Introspection
  alias ElixirSense.Core.State
  alias ElixirLS.Utils.Matcher

  @type callback :: %{
          type: :callback,
          subtype: :callback | :macrocallback,
          name: String.t(),
          arity: non_neg_integer,
          args: String.t(),
          args_list: [String.t()],
          origin: String.t(),
          summary: String.t(),
          spec: String.t(),
          metadata: map
        }

  @doc """
  A reducer that adds suggestions of callbacks.
  """
  def add_callbacks(
        hint,
        env = %State.Env{module: module, typespec: nil},
        buffer_metadata,
        context,
        acc
      )
      when module != nil do
    text_before = context.text_before

    %State.Env{protocol: protocol, behaviours: behaviours} = env

    list =
      Enum.flat_map(behaviours, fn
        mod when is_atom(mod) and (protocol == nil or mod != elem(protocol, 0)) ->
          mod_name = inspect(mod)

          if Map.has_key?(buffer_metadata.mods_funs_to_positions, {mod, nil, nil}) do
            behaviour_callbacks =
              buffer_metadata.specs
              |> Enum.filter(fn {{behaviour_mod, _, arity}, %State.SpecInfo{kind: kind}} ->
                behaviour_mod == mod and is_integer(arity) and kind in [:callback, :macrocallback]
              end)

            for {{_, name, arity}, %State.SpecInfo{} = info} <- behaviour_callbacks,
                hint == "" or def_prefix?(hint, List.last(info.specs)) or
                  Matcher.match?("#{name}", hint) do
              def_info = buffer_metadata.mods_funs_to_positions[{env.module, name, arity}]
              def_info_meta = if def_info, do: def_info.meta, else: %{}
              meta = info.meta |> Map.merge(def_info_meta)

              %{
                type: :callback,
                subtype: info.kind,
                name: Atom.to_string(name),
                arity: arity,
                args: Enum.join(List.last(info.args), ", "),
                args_list: List.last(info.args),
                origin: mod_name,
                summary: Introspection.extract_summary_from_docs(info.doc),
                spec: List.last(info.specs),
                metadata: meta
              }
            end
          else
            for %{
                  name: name,
                  arity: arity,
                  kind: kind,
                  callback: spec,
                  signature: signature,
                  doc: doc,
                  metadata: metadata
                } <-
                  Introspection.get_callbacks_with_docs(mod),
                hint == "" or def_prefix?(hint, spec) or Matcher.match?("#{name}", hint) do
              desc = Introspection.extract_summary_from_docs(doc)

              {args, args_list} =
                if signature do
                  match_res = Regex.run(~r/.\(([^\)]*)\)/u, signature)

                  unless match_res do
                    raise "unable to get arguments from #{inspect(signature)}"
                  end

                  [_, args_str] = match_res

                  args_list =
                    args_str
                    |> String.split(",")
                    |> Enum.map(&String.trim/1)

                  args =
                    args_str
                    |> String.replace("\n", " ")
                    |> String.split(",")
                    |> Enum.map_join(", ", &String.trim/1)

                  {args, args_list}
                else
                  if arity == 0 do
                    {"", []}
                  else
                    args_list = for _ <- 1..arity, do: "term"
                    {Enum.join(args_list, ", "), args_list}
                  end
                end

              def_info = buffer_metadata.mods_funs_to_positions[{env.module, name, arity}]
              def_info_meta = if def_info, do: def_info.meta, else: %{}
              meta = metadata |> Map.merge(def_info_meta)

              %{
                type: :callback,
                subtype: kind,
                name: Atom.to_string(name),
                arity: arity,
                args: args,
                args_list: args_list,
                origin: mod_name,
                summary: desc,
                spec: spec,
                metadata: meta
              }
            end
          end

        _ ->
          []
      end)

    list = Enum.sort(list)

    cond do
      Regex.match?(~r/\s(def|defmacro)\s+([_\p{Ll}\p{Lo}][\p{L}\p{N}_]*[?!]?)?$/u, text_before) ->
        {:halt, %{acc | result: list}}

      env.function != nil ->
        {:cont, acc}

      true ->
        {:cont, %{acc | result: acc.result ++ list}}
    end
  end

  def add_callbacks(_hint, _env, _buffer_metadata, _context, acc) do
    {:cont, acc}
  end

  defp def_prefix?(hint, spec) do
    if String.starts_with?(spec, "@macrocallback") do
      String.starts_with?("defmacro", hint)
    else
      String.starts_with?("def", hint)
    end
  end
end
