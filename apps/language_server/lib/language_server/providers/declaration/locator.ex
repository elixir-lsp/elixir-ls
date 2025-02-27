defmodule ElixirLS.LanguageServer.Providers.Declaration.Locator do
  @moduledoc """
  Provides a function to find the declaration of a callback or protocol function,
  that is, the place where a behaviour or protocol defines the callback that is being
  implemented.

  This is effectively the reverse of the "go to implementations" provider.
  """

  alias ElixirSense.Core.Binding
  alias ElixirSense.Core.SurroundContext
  alias ElixirSense.Core.Metadata
  alias ElixirSense.Core.Normalized.Code, as: NormalizedCode
  alias ElixirSense.Core.State
  alias ElixirLS.LanguageServer.Location
  alias ElixirSense.Core.Parser
  alias ElixirSense.Core.State.{ModFunInfo, SpecInfo}

  require ElixirSense.Core.Introspection, as: Introspection

  @doc """
  Finds the declaration (callback or protocol definition) for the function under the cursor.

  It parses the code, determines the environment and then checks if the current function
  is an implementation of any behaviour (or protocol). For each matching behaviour,
  it returns the location where the callback is declared.

  Returns either a single `%Location{}` or a list of locations if multiple declarations are found.
  """
  def declaration(code, line, column, options \\ []) do
    case NormalizedCode.Fragment.surround_context(code, {line, column}) do
      :none ->
        nil

      context ->
        metadata =
          Keyword.get_lazy(options, :metadata, fn ->
            Parser.parse_string(code, true, false, {line, column})
          end)

        env = Metadata.get_cursor_env(metadata, {line, column}, {context.begin, context.end})
        find(context, env, metadata)
    end
  end

  @doc false
  def find(context, %State.Env{module: module} = env, metadata) do
    binding_env = Binding.from_env(env, metadata, context.begin)

    type = SurroundContext.to_binding(context.context, module)

    case type do
      nil ->
        nil

      {:keyword, _} ->
        nil

      {:variable, variable, version} ->
        var_info = Metadata.find_var(metadata, variable, version, context.begin)

        if var_info == nil do
          # find local call
          find_function(
            {nil, variable},
            context,
            env,
            metadata,
            binding_env
          )
        end

      {:attribute, _attribute} ->
        nil

      {module, function} ->
        find_function(
          {module, function},
          context,
          env,
          metadata,
          binding_env
        )
    end
  end

  defp find_function(
         {{:variable, _, _} = type, function},
         context,
         env,
         metadata,
         binding_env
       ) do
    case Binding.expand(binding_env, type) do
      {:atom, module} ->
        find_function(
          {{:atom, module}, function},
          context,
          env,
          metadata,
          binding_env
        )

      _ ->
        nil
    end
  end

  defp find_function(
         {{:attribute, _} = type, function},
         context,
         env,
         metadata,
         binding_env
       ) do
    case Binding.expand(binding_env, type) do
      {:atom, module} ->
        find_function(
          {{:atom, module}, function},
          context,
          env,
          metadata,
          binding_env
        )

      _ ->
        nil
    end
  end

  defp find_function(
         {module, function},
         context,
         env,
         metadata,
         _binding_env
       ) do
    m = get_module(module)

    case {m, function}
         |> Introspection.actual_mod_fun(
           env,
           metadata.mods_funs_to_positions,
           metadata.types,
           context.begin,
           true
         ) do
      {mod, fun, false, _} ->
        {line, column} = context.end
        call_arity = Metadata.get_call_arity(metadata, mod, fun, line, column) || :any

        get_callback_location(env.module, fun, call_arity, metadata)

      {mod, fun, true, :mod_fun} ->
        {line, column} = context.end
        call_arity = Metadata.get_call_arity(metadata, mod, fun, line, column) || :any

        find_callback(mod, fun, call_arity, metadata, env)

      _ ->
        nil
    end
  end

  defp get_module({:atom, module}), do: module
  defp get_module(_), do: nil

  def find_callback(mod, fun, arity, metadata, env) do
    # Get the behaviours (and possibly protocols) declared for the current module.
    behaviours = Metadata.get_module_behaviours(metadata, env, mod)

    # For each behaviour, if the current function is a callback for it,
    # try to find the callback’s declaration.
    locations =
      for behaviour <- behaviours ++ [mod],
          Introspection.is_callback(behaviour, fun, arity, metadata),
          location = get_callback_location(behaviour, fun, arity, metadata),
          location != nil do
        location
      end

    locations =
      if locations == [] do
        # check if function is overridable
        # NOTE we only go over local buffer defs. There is no way to tell if a remote def has been overridden.
        metadata.mods_funs_to_positions
        |> Enum.filter(fn
          {{^mod, ^fun, a}, %ModFunInfo{overridable: {true, _module_with_overridables}}}
          when Introspection.matches_arity?(a, arity) ->
            true

          {_, _} ->
            false
        end)
        |> Enum.map(fn {_, %ModFunInfo{overridable: {true, module_with_overridables}}} ->
          # assume overridables are defined by __using__ macro
          get_function_location(module_with_overridables, :__using__, :any, metadata)
        end)
      else
        locations
      end

    case locations do
      [] -> nil
      [single] -> single
      multiple -> multiple
    end
  end

  # Attempts to find the callback declaration in the behaviour (or protocol) module.
  # First it checks for a callback spec in the metadata; if none is found, it falls back
  # to trying to locate the source code.
  defp get_callback_location(behaviour, fun, arity, metadata) do
    case Enum.find(metadata.specs, fn
           {{^behaviour, ^fun, a}, %SpecInfo{kind: kind}}
           when kind in [:callback, :macrocallback] ->
             Introspection.matches_arity?(a, arity)

           _ ->
             false
         end) do
      nil ->
        # Fallback: try to locate the function in the behaviour module’s source.
        Location.find_callback_source(behaviour, fun, arity)

      {{^behaviour, ^fun, _a}, spec_info} ->
        {{line, column}, {end_line, end_column}} = Location.info_to_range(spec_info)

        %Location{
          file: nil,
          type: spec_info.kind,
          line: line,
          column: column,
          end_line: end_line,
          end_column: end_column
        }
    end
  end

  defp get_function_location(mod, fun, arity, metadata) do
    fn_definition =
      Location.get_function_position_using_metadata(
        mod,
        fun,
        arity,
        metadata.mods_funs_to_positions
      )

    case fn_definition do
      nil ->
        Location.find_mod_fun_source(mod, fun, arity)

      %ModFunInfo{} = info ->
        {{line, column}, {end_line, end_column}} = Location.info_to_range(info)

        %Location{
          file: nil,
          type: ModFunInfo.get_category(info),
          line: line,
          column: column,
          end_line: end_line,
          end_column: end_column
        }
    end
  end
end
