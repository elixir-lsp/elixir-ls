defmodule ElixirLS.LanguageServer.Providers.Completion.Reducers.Record do
  @moduledoc false

  alias ElixirSense.Core.Introspection
  alias ElixirSense.Core.Metadata
  alias ElixirSense.Core.Source
  alias ElixirSense.Core.State
  alias ElixirSense.Core.State.{RecordInfo, TypeInfo}
  alias ElixirLS.Utils.Matcher
  alias ElixirSense.Core.Normalized.Code, as: NormalizedCode

  @type field :: %{
          type: :field,
          subtype: :record_field,
          name: String.t(),
          origin: String.t() | nil,
          call?: boolean,
          type_spec: String.t() | nil
        }

  @doc """
  A reducer that adds suggestions of record fields.
  """
  def add_fields(hint, env, buffer_metadata, context, acc) do
    text_before = context.text_before

    case find_record_fields(hint, text_before, env, buffer_metadata, context.cursor_position) do
      {[], _} ->
        {:cont, acc}

      {fields, nil} ->
        {:halt, %{acc | result: fields}}

      {fields, :maybe_record_update} ->
        reducers = [
          :populate_complete_engine,
          :modules,
          :functions,
          :macros,
          :variables,
          :attributes,
          :structs_fields,
          :bitstring_options
        ]

        {:cont, %{acc | result: fields, reducers: reducers}}
    end
  end

  defp find_record_fields(
         hint,
         text_before,
         %State.Env{} = env,
         %Metadata{
           records: records,
           types: metadata_types
         } = metadata,
         cursor_position
       ) do
    binding_env = ElixirSense.Core.Binding.from_env(env, metadata, cursor_position)

    # check if we are inside local or remote call arguments and parameter is 0, 1 or 2
    # record fields can specified on 0, 1 and 2 position in the argument list
    with %{
           candidate: {m, f},
           npar: npar,
           elixir_prefix: elixir_prefix,
           options_so_far: options_so_far,
           option: nil,
           cursor_at_option: cursor_at_option
         }
         when npar < 2 <-
           Source.which_func(text_before, binding_env),
         {mod, fun, true, :mod_fun} <-
           Introspection.actual_mod_fun(
             {m, f},
             env,
             metadata.mods_funs_to_positions,
             metadata.types,
             cursor_position,
             not elixir_prefix
           ),
         fields_info when is_list(fields_info) <- get_record_info(mod, fun, records) do
      fields = get_fields(hint, mod, fun, fields_info, options_so_far, metadata_types)

      {fields, if(npar == 0 and cursor_at_option in [false, :maybe], do: :maybe_record_update)}
    else
      _o ->
        {[], nil}
    end
  end

  defp get_record_info(mod, fun, records) do
    case records[{mod, fun}] do
      %RecordInfo{} = info ->
        info.fields

      nil ->
        if Version.match?(System.version(), ">= 1.18.0-dev") do
          case NormalizedCode.get_docs(mod, :docs) do
            nil ->
              nil

            docs ->
              Enum.find_value(docs, fn
                {{^fun, 1}, _, :macro, _, _, %{record: {_tag, fields}}} -> fields
                _ -> nil
              end)
          end
        end
    end
  end

  defp get_fields(hint, module, record_name, fields, fields_so_far, types) do
    field_types = get_field_types(types, module, record_name)

    for {key, _value} when is_atom(key) <- fields,
        key not in fields_so_far,
        key_str = Atom.to_string(key),
        Matcher.match?(key_str, hint) do
      type_spec =
        case Keyword.get(field_types, key, nil) do
          nil -> nil
          some -> Introspection.to_string_with_parens(some)
        end

      %{
        type: :field,
        name: key_str,
        subtype: :record_field,
        origin: "#{inspect(module)}.#{record_name}",
        type_spec: type_spec,
        call?: false
      }
    end
    |> Enum.sort_by(& &1.name)
  end

  defp get_field_types(types, module, record) do
    # assume there is a type record_name or record_name_t or t
    with %TypeInfo{specs: [spec | _]} <-
           types[{module, record, 0}] || types[{module, :"#{record}_t", 0}] ||
             types[{module, :t, 0}],
         {:ok, ast} <- Code.string_to_quoted(spec),
         {:@, _,
          [
            {kind, _,
             [
               {:"::", _,
                [
                  {_type_name, _, []},
                  {:record, _,
                   [
                     _tag,
                     field_types
                   ]}
                ]}
             ]}
          ]}
         when kind in [:type, :typep, :opaque] <- ast do
      field_types
    else
      _ ->
        candidates =
          if Version.match?(System.version(), ">= 1.18.0-dev") do
            ElixirSense.Core.TypeInfo.find_all(module, fn info ->
              info.name in [record, :"#{record}_t", :t] and info.arity == 0
            end)
          else
            []
          end

        with [info | _] <- candidates,
             {:ok, ast} <- Code.string_to_quoted(info.spec),
             {:@, _,
              [
                {kind, _,
                 [
                   {:"::", _,
                    [
                      {_name, _, []},
                      {:{}, _,
                       [
                         _tag
                         | field_types
                       ]}
                    ]}
                 ]}
              ]}
             when kind in [:type, :typep, :opaque] <- ast do
          field_types
          |> Enum.map(fn
            {:"::", _, [{name, _, context}, type]} when is_atom(name) and is_atom(context) ->
              {name, type}

            _ ->
              nil
          end)
          |> Enum.reject(&is_nil/1)
        else
          _ ->
            []
        end
    end
  end
end
