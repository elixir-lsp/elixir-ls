defmodule ElixirLS.LanguageServer.Providers.Completion.Reducers.Struct do
  @moduledoc false

  alias ElixirSense.Core.Binding
  alias ElixirSense.Core.Introspection
  alias ElixirSense.Core.Metadata
  alias ElixirSense.Core.Source
  alias ElixirSense.Core.State
  alias ElixirLS.Utils.Matcher

  @type field :: %{
          type: :field,
          subtype: :struct_field | :map_key,
          name: String.t(),
          origin: String.t() | nil,
          call?: boolean,
          type_spec: String.t() | nil
        }

  @doc """
  A reducer that adds suggestions of struct fields.
  """
  def add_fields(hint, env, buffer_metadata, context, acc) do
    text_before = context.text_before

    case find_struct_fields(hint, text_before, env, buffer_metadata) do
      {[], _} ->
        {:cont, acc}

      {fields, nil} ->
        {:halt, %{acc | result: fields}}

      {fields, :maybe_struct_update} ->
        reducers = [
          :populate_complete_engine,
          :modules,
          :functions,
          :macros,
          :variables,
          :attributes
        ]

        {:cont, %{acc | result: fields, reducers: reducers}}
    end
  end

  defp find_struct_fields(hint, text_before, env, buffer_metadata) do
    %State.Env{
      module: module,
      vars: vars,
      attributes: attributes,
      imports: imports,
      aliases: aliases
    } = env

    %Metadata{
      structs: structs,
      mods_funs_to_positions: mods_funs,
      types: metadata_types,
      specs: specs
    } = buffer_metadata

    env = %ElixirSense.Core.Binding{
      attributes: attributes,
      variables: vars,
      structs: structs,
      imports: imports,
      current_module: module,
      specs: specs,
      types: metadata_types,
      mods_funs: mods_funs
    }

    case Source.which_struct(text_before, module) do
      {type, fields_so_far, elixir_prefix, var} ->
        type =
          case {type, elixir_prefix} do
            {{:atom, mod}, false} ->
              # which_struct returns not expanded aliases
              {:atom, Introspection.expand_alias(mod, aliases)}

            _ ->
              type
          end

        type = Binding.expand(env, {:struct, [], type, var})

        result = get_fields(buffer_metadata, type, hint, fields_so_far)
        {result, if(fields_so_far == [], do: :maybe_struct_update)}

      {:map, fields_so_far, var} ->
        var = Binding.expand(env, var)

        result = get_fields(buffer_metadata, var, hint, fields_so_far)
        {result, if(fields_so_far == [], do: :maybe_struct_update)}

      _ ->
        {[], nil}
    end
  end

  defp get_fields(metadata, {:map, fields, _}, hint, fields_so_far) do
    expand_map_field_access(metadata, fields, hint, :map, fields_so_far)
  end

  defp get_fields(metadata, {:struct, fields, type, _}, hint, fields_so_far) do
    expand_map_field_access(metadata, fields, hint, {:struct, type}, fields_so_far)
  end

  defp get_fields(_, _, _hint, _fields_so_far), do: []

  defp expand_map_field_access(metadata, fields, hint, type, fields_so_far) do
    {subtype, origin, types} =
      case type do
        {:struct, {:atom, mod}} ->
          types = ElixirLS.Utils.Field.get_field_types(metadata, mod, true)

          {:struct_field, inspect(mod), types}

        {:struct, nil} ->
          {:struct_field, nil, %{}}

        :map ->
          {:map_key, nil, %{}}
      end

    for {key, _value} when is_atom(key) <- fields,
        key not in fields_so_far,
        key_str = Atom.to_string(key),
        Matcher.match?(key_str, hint) do
      spec =
        case types[key] do
          nil ->
            case key do
              :__struct__ -> origin || "atom()"
              :__exception__ -> "true"
              _ -> nil
            end

          some ->
            Introspection.to_string_with_parens(some)
        end

      %{
        type: :field,
        name: key_str,
        subtype: subtype,
        origin: origin,
        call?: false,
        type_spec: spec
      }
    end
    |> Enum.sort_by(& &1.name)
  end
end
