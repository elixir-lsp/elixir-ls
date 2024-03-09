defmodule ElixirLS.LanguageServer.Providers.Completion.Reducers.Protocol do
  @moduledoc false

  alias ElixirSense.Core.Introspection
  alias ElixirSense.Core.State
  alias ElixirLS.Utils.Matcher

  @type protocol_function :: %{
          type: :protocol_function,
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
  A reducer that adds suggestions of protocol functions.
  """
  def add_functions(_hint, %State.Env{scope: {_f, _a}}, _metadata, _cursor_context, acc),
    do: {:cont, acc}

  def add_functions(_hint, %State.Env{protocol: nil}, _metadata, _cursor_context, acc),
    do: {:cont, acc}

  def add_functions(hint, env, buffer_metadata, _cursor_context, acc) do
    %State.Env{protocol: {protocol, _implementations}} = env

    mod_name = inspect(protocol)

    list =
      if Map.has_key?(buffer_metadata.mods_funs_to_positions, {protocol, nil, nil}) do
        behaviour_callbacks =
          buffer_metadata.specs
          |> Enum.filter(fn {{mod, _, arity}, %State.SpecInfo{kind: kind}} ->
            mod == protocol and is_integer(arity) and kind in [:callback]
          end)

        for {{_, name, arity}, %State.SpecInfo{} = info} <- behaviour_callbacks,
            hint == "" or String.starts_with?("def", hint) or Matcher.match?("#{name}", hint) do
          %State.ModFunInfo{} =
            def_info =
            buffer_metadata.mods_funs_to_positions |> Map.fetch!({protocol, name, arity})

          %{
            type: :protocol_function,
            name: Atom.to_string(name),
            arity: arity,
            args: Enum.join(List.last(info.args), ", "),
            args_list: List.last(info.args),
            origin: mod_name,
            summary: Introspection.extract_summary_from_docs(def_info.doc),
            spec: List.last(info.specs),
            metadata: def_info.meta
          }
        end
      else
        for {{name, arity}, {_type, args, docs, metadata, spec}} <-
              Introspection.module_functions_info(protocol),
            hint == "" or String.starts_with?("def", hint) or Matcher.match?("#{name}", hint) do
          %{
            type: :protocol_function,
            name: Atom.to_string(name),
            arity: arity,
            args: args |> Enum.join(", "),
            args_list: args,
            origin: inspect(protocol),
            summary: docs,
            metadata: metadata,
            spec: spec
          }
        end
      end

    {:cont, %{acc | result: acc.result ++ Enum.sort(list)}}
  end
end
