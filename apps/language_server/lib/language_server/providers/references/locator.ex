defmodule ElixirLS.LanguageServer.Providers.References.Locator do
  @moduledoc """
  This module provides References to function or module identified at the provided location.
  """

  alias ElixirSense.Core.Binding
  require ElixirSense.Core.Introspection, as: Introspection
  alias ElixirSense.Core.Metadata
  alias ElixirSense.Core.Normalized.Code, as: NormalizedCode
  alias ElixirSense.Core.State
  alias ElixirSense.Core.State.AttributeInfo
  alias ElixirSense.Core.State.VarInfo
  alias ElixirSense.Core.SurroundContext
  alias ElixirSense.Core.Parser

  def references(code, line, column, trace, options \\ []) do
    case NormalizedCode.Fragment.surround_context(code, {line, column}) do
      :none ->
        []

      %{
        begin: {begin_line, begin_col}
      } = context ->
        metadata =
          Keyword.get_lazy(options, :metadata, fn ->
            Parser.parse_string(code, true, true, {line, column})
          end)

        env =
          %State.Env{
            module_variants: module_variants
          } =
          Metadata.get_env(metadata, {line, column})
          |> Metadata.add_scope_vars(metadata, {line, column})

        # find last env of current module
        attributes = get_attributes(metadata, module_variants)

        # one line can contain variables from many scopes
        # if the cursor is over variable take variables from the scope as it will
        # be more correct than the env scope
        vars =
          case Enum.find(env.vars, fn %VarInfo{positions: positions} ->
                 {begin_line, begin_col} in positions
               end) do
            %VarInfo{scope_id: scope_id} ->
              # in (h|l)?eex templates vars_info_per_scope_id[scope_id] is nil
              if metadata.vars_info_per_scope_id[scope_id] do
                metadata.vars_info_per_scope_id[scope_id]
              else
                []
              end

            nil ->
              []
          end

        find(
          context,
          env,
          vars,
          attributes,
          metadata,
          trace
        )
    end
  end

  defp get_attributes(_metadata, []), do: []

  defp get_attributes(metadata, [module | _]) do
    %State.Env{attributes: attributes} = Metadata.get_last_module_env(metadata, module)

    attributes
  end

  @type position :: %{line: pos_integer, column: pos_integer}

  @type range :: %{
          start: position,
          end: position
        }

  @type reference_info :: %{
          uri: String.t() | nil,
          range: range
        }

  def find(
        context,
        %State.Env{
          imports: imports,
          requires: requires,
          aliases: aliases,
          module: module,
          scope: scope
        } = env,
        vars,
        attributes,
        %Metadata{
          mods_funs_to_positions: mods_funs,
          calls: calls,
          types: metadata_types
        } = metadata,
        trace
      ) do
    binding_env = Binding.from_env(env, metadata)

    type = SurroundContext.to_binding(context.context, module)

    refs_for_mod_fun = fn {mod, function} ->
      actual =
        {mod, function}
        |> expand(binding_env, module, aliases)
        |> Introspection.actual_mod_fun(
          imports,
          requires,
          aliases,
          module,
          scope,
          mods_funs,
          metadata_types,
          context.begin
        )

      case actual do
        {mod, fun, true, :mod_fun} ->
          {line, column} = context.end
          call_arity = Metadata.get_call_arity(metadata, module, function, line, column) || :any

          metadata_call_references =
            calls
            |> Map.values()
            |> List.flatten()
            |> Enum.filter(fn call -> function == nil or call.func == function end)
            |> Enum.map(fn call ->
              env = Metadata.get_env(metadata, call.position)

              binding_env = Binding.from_env(env, metadata)

              found =
                {call.mod, function}
                |> wrap_atom
                |> expand(binding_env, module, aliases)
                |> Introspection.actual_mod_fun(
                  env.imports,
                  env.requires,
                  env.aliases,
                  env.module,
                  env.scope,
                  mods_funs,
                  metadata_types,
                  call.position
                )

              case found do
                {^mod, ^function, true, :mod_fun} when is_nil(function) ->
                  build_var_location(to_string(call.func), call.position)

                {^mod, ^function, true, :mod_fun} ->
                  [_, _, arities] = get_matching_arities([mod, function, call_arity], mods_funs)
                  corrected_arity = get_corrected_arity([mod, function, call.arity], mods_funs)

                  if Enum.any?(
                       arities,
                       &Introspection.matches_arity?(corrected_arity, &1)
                     ) do
                    build_var_location(to_string(function), call.position)
                  end

                _ ->
                  nil
              end
            end)
            |> Enum.filter(&(not is_nil(&1)))

          tracer_call_reverences =
            {mod, fun}
            |> xref_at_cursor(call_arity, module, scope, mods_funs, trace)
            |> Enum.map(&build_location/1)

          (metadata_call_references ++ tracer_call_reverences)
          |> Enum.sort_by(fn %{uri: a, range: %{start: %{line: b, column: c}}} -> {a, b, c} end)

        _ ->
          # no results for types or not found
          []
      end
    end

    case type do
      nil ->
        []

      {:keyword, _} ->
        []

      {:variable, variable} ->
        {line, column} = context.begin

        var_info =
          Enum.find(vars, fn %VarInfo{name: name, positions: positions} ->
            name == variable and {line, column} in positions
          end)

        if var_info != nil do
          %VarInfo{positions: positions} = var_info

          positions
          |> Enum.map(fn pos -> build_var_location(to_string(variable), pos) end)
        else
          refs_for_mod_fun.({nil, variable})
        end

      {:attribute, attribute} ->
        attribute_info =
          attributes
          |> Enum.find(fn %AttributeInfo{name: name} -> name == attribute end)

        if attribute_info != nil do
          %AttributeInfo{positions: positions} = attribute_info

          positions
          |> Enum.map(fn pos -> build_var_location("@#{attribute}", pos) end)
        else
          []
        end

      {mod, function} ->
        refs_for_mod_fun.({mod, function})
    end
  end

  defp xref_at_cursor(actual_mod_fun, arity, module, scope, mods_funs, trace) do
    mfa = callee_at_cursor(actual_mod_fun, module, scope, arity, mods_funs)

    filtered_calls(mfa, mods_funs, trace)
  end

  # Cursor over a module
  defp callee_at_cursor({module, nil}, _module, _scope, _arity, _mods_funs) do
    [module]
  end

  # Cursor over a function call
  defp callee_at_cursor({module, func}, _module, _scope, arity, _mods_funs) do
    [module, func, arity]
  end

  defp filtered_calls(mfa, mods_funs, trace) do
    mfa = get_matching_arities(mfa, mods_funs)

    trace
    |> Map.values()
    |> List.flatten()
    |> Enum.filter(caller_filter(mfa, mods_funs))
    |> Enum.uniq()
  end

  defp caller_filter([module, func, filter_arities], mods_funs) do
    fn
      %{callee: {^module, ^func, callee_arity}} ->
        corrected_arity = get_corrected_arity([module, func, callee_arity], mods_funs)
        Enum.any?(filter_arities, &Introspection.matches_arity?(corrected_arity, &1))

      _ ->
        false
    end
  end

  defp caller_filter([module, func], _mods_funs), do: &match?(%{callee: {^module, ^func, _}}, &1)
  defp caller_filter([module], _mods_funs), do: &match?(%{callee: {^module, _, _}}, &1)

  defp build_location(call) do
    %{callee: {_, func, _}} = call

    line = call.line || 1

    {start_column, end_column} =
      if call.line != nil and call.column != nil do
        func_length = func |> to_string() |> String.length()
        {call.column, call.column + func_length}
      else
        {1, 1}
      end

    %{
      uri: call.file,
      range: %{
        start: %{line: line, column: start_column},
        end: %{line: line, column: end_column}
      }
    }
  end

  defp build_var_location(subject, {line, column}) do
    %{
      uri: nil,
      range: %{
        start: %{line: line, column: column},
        end: %{line: line, column: column + String.length(subject)}
      }
    }
  end

  defp expand({nil, func}, _env, module, _aliases) when module not in [nil, Elixir],
    do: {nil, func}

  defp expand({type, func}, env, _module, aliases) do
    case Binding.expand(env, type) do
      {:atom, module} -> {Introspection.expand_alias(module, aliases), func}
      _ -> {nil, nil}
    end
  end

  defp get_corrected_arity([m], _mods_funs) do
    [m]
  end

  defp get_corrected_arity([m, f, a], mods_funs) do
    arity =
      mods_funs
      |> Enum.find_value(fn
        {{^m, ^f, arity}, info} when not is_nil(arity) ->
          # no need to filter public only here
          defaults = info.params |> List.last() |> Introspection.count_defaults()

          if Introspection.matches_arity_with_defaults?(arity, defaults, a) do
            arity
          end

        _ ->
          false
      end)

    arity =
      if arity != nil do
        arity
      else
        case NormalizedCode.get_docs(m, :docs) do
          nil ->
            nil

          docs ->
            docs
            |> Enum.find_value(fn
              {{^f, arity}, _, _, _, _, meta} ->
                defaults = Map.get(meta, :defaults, 0)

                if Introspection.matches_arity_with_defaults?(arity, defaults, a) do
                  arity
                end

              _ ->
                false
            end)
        end
      end

    if arity != nil do
      arity
    else
      # no need to drop macro prefix and correct arity - macros handled by docs
      if Code.ensure_loaded?(m) and {f, a} in m.module_info(:exports) do
        a
      end
    end
  end

  defp get_matching_arities([m, f, a], mods_funs) do
    arities =
      mods_funs
      |> Enum.filter(fn
        {{^m, ^f, arity}, info} when not is_nil(arity) ->
          # no need to filter public only here
          defaults = info.params |> List.last() |> Introspection.count_defaults()

          if Introspection.matches_arity_with_defaults?(arity, defaults, a) do
            arity
          end

        _ ->
          false
      end)
      |> Enum.map(fn
        {{_, _, arity}, _} -> arity
      end)

    arities =
      if arities == [] do
        case NormalizedCode.get_docs(m, :docs) do
          nil ->
            []

          docs ->
            docs
            |> Enum.filter(fn
              {{^f, arity}, _, _, _, _, meta} ->
                defaults = Map.get(meta, :defaults, 0)

                if Introspection.matches_arity_with_defaults?(arity, defaults, a) do
                  arity
                end

              _ ->
                false
            end)
            |> Enum.map(fn
              {{^f, arity}, _, _, _, _, _meta} -> arity
            end)
        end
      else
        arities
      end

    arities =
      if arities == [] do
        if Code.ensure_loaded?(m) do
          m.module_info(:exports)
          |> Enum.filter(fn {fun, arity} ->
            # no need to drop macro prefix and correct arity - macros handled by docs
            fun == f and Introspection.matches_arity?(arity, a)
          end)
          |> Enum.map(fn {_fun, arity} ->
            arity
          end)
        else
          []
        end
      else
        arities
      end

    [m, f, arities]
  end

  defp get_matching_arities(other, _mods_funs) do
    other
  end

  defp wrap_atom({nil, other}), do: {nil, other}
  defp wrap_atom({atom, other}) when is_atom(atom), do: {{:atom, atom}, other}
  defp wrap_atom(other), do: other
end
