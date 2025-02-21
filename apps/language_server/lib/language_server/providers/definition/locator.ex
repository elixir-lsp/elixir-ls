# This code has originally been a part of https://github.com/elixir-lsp/elixir_sense

# Copyright (c) 2017 Marlus Saraiva
# Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the 'Software'), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
# The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

defmodule ElixirLS.LanguageServer.Providers.Definition.Locator do
  @moduledoc """
  Provides a function to find out where symbols are defined.

  Currently finds definition of modules, functions and macros,
  typespecs, variables and attributes.
  """

  alias ElixirSense.Core.Binding
  require ElixirSense.Core.Introspection, as: Introspection
  alias ElixirSense.Core.Metadata
  alias ElixirSense.Core.State
  alias ElixirSense.Core.State.ModFunInfo
  alias ElixirSense.Core.Source
  alias ElixirSense.Core.SurroundContext
  alias ElixirLS.LanguageServer.Location
  alias ElixirSense.Core.Parser
  alias ElixirSense.Core.State.{ModFunInfo, TypeInfo, SpecInfo}

  alias ElixirLS.LanguageServer.Plugins.Phoenix.Scope
  alias ElixirSense.Core.Normalized.Code, as: NormalizedCode

  def definition(code, line, column, options \\ []) do
    case NormalizedCode.Fragment.surround_context(code, {line, column}) do
      :none ->
        nil

      context ->
        metadata =
          Keyword.get_lazy(options, :metadata, fn ->
            Parser.parse_string(code, true, false, {line, column})
          end)

        env = Metadata.get_cursor_env(metadata, {line, column}, {context.begin, context.end})

        find(
          context,
          env,
          metadata
        )
    end
  end

  @doc """
  Finds out where a module, function, macro or variable was defined.
  """
  @spec find(
          any(),
          State.Env.t(),
          Metadata.t()
        ) :: %Location{} | nil
  def find(
        context,
        %State.Env{
          module: module,
          attributes: attributes
        } = env,
        metadata
      ) do
    binding_env = Binding.from_env(env, metadata, context.begin)

    type = SurroundContext.to_binding(context.context, module)

    case type do
      nil ->
        nil

      {:keyword, _} ->
        nil

      {:variable, variable, version} ->
        var_info = Metadata.find_var(metadata, variable, version, context.begin)

        if var_info != nil do
          {definition_line, definition_column} = Enum.min(var_info.positions)

          %Location{
            type: :variable,
            file: nil,
            line: definition_line,
            column: definition_column,
            end_line: definition_line,
            end_column: definition_column + String.length(to_string(variable))
          }
        else
          # find local call
          find_function_or_module(
            {nil, variable},
            context,
            env,
            metadata,
            binding_env
          )
        end

      {:attribute, attribute} ->
        attribute_info =
          Enum.find(attributes, fn
            %State.AttributeInfo{name: name} -> name == attribute
          end)

        if attribute_info != nil do
          %State.AttributeInfo{positions: [{line, column} | _]} = attribute_info

          %Location{
            type: :attribute,
            file: nil,
            line: line,
            column: column,
            end_line: line,
            end_column: column + 1 + String.length(to_string(attribute))
          }
        end

      {module, function} ->
        find_function_or_module(
          {module, function},
          context,
          env,
          metadata,
          binding_env
        )
    end
  end

  defp find_function_or_module(
         target,
         context,
         env,
         metadata,
         binding_env,
         visited \\ []
       ) do
    unless target in visited do
      do_find_function_or_module(
        target,
        context,
        env,
        metadata,
        binding_env,
        [target | visited]
      )
    end
  end

  defp do_find_function_or_module(
         {{:variable, _, _} = type, function},
         context,
         env,
         metadata,
         binding_env,
         visited
       ) do
    case Binding.expand(binding_env, type) do
      {:atom, module} ->
        do_find_function_or_module(
          {{:atom, module}, function},
          context,
          env,
          metadata,
          binding_env,
          visited
        )

      _ ->
        nil
    end
  end

  defp do_find_function_or_module(
         {{:attribute, _} = type, function},
         context,
         env,
         metadata,
         binding_env,
         visited
       ) do
    case Binding.expand(binding_env, type) do
      {:atom, module} ->
        do_find_function_or_module(
          {{:atom, module}, function},
          context,
          env,
          metadata,
          binding_env,
          visited
        )

      _ ->
        nil
    end
  end

  defp do_find_function_or_module(
         {nil, :super},
         context,
         %State.Env{function: {function, arity}, module: module} = env,
         metadata,
         binding_env,
         visited
       ) do
    case metadata.mods_funs_to_positions[{module, function, arity}] do
      %ModFunInfo{overridable: {true, origin}} ->
        # overridable function is most likely defined by __using__ macro
        do_find_function_or_module(
          {{:atom, origin}, :__using__},
          context,
          env,
          metadata,
          binding_env,
          visited
        )

      _ ->
        nil
    end
  end

  defp do_find_function_or_module(
         {module, function},
         context,
         env,
         metadata,
         _binding_env,
         _visited
       ) do
    m = get_module(module, context, env, metadata)

    case {m, function}
         |> Introspection.actual_mod_fun(
           env,
           metadata.mods_funs_to_positions,
           metadata.types,
           context.begin,
           true
         ) do
      {_, f, false, _} ->
        module = env.module
        {line, column} = context.end
        call_arity = Metadata.get_call_arity(metadata, env.module, f, line, column) || :any

        Enum.find_value(metadata.specs, fn
          {{^module, ^f, a}, spec_info = %SpecInfo{}} ->
            if Introspection.matches_arity?(a, call_arity) do
              {{line, column}, {end_line, end_column}} = Location.info_to_range(spec_info)

              if spec_info.kind in [:callback, :macrocallback] do
                %Location{
                  file: nil,
                  type: spec_info.kind,
                  line: line,
                  column: column,
                  end_line: end_line,
                  end_column: end_column
                }
              else
                # find def location for spec
                find_function(module, f, a, metadata)
              end
            end

          _ ->
            nil
        end)

      {mod, fun, true, :mod_fun} ->
        {line, column} = context.end
        call_arity = Metadata.get_call_arity(metadata, mod, fun, line, column) || :any

        find_function(mod, fun, call_arity, metadata)

      {mod, fun, true, :type} ->
        {line, column} = context.end
        call_arity = Metadata.get_call_arity(metadata, mod, fun, line, column) || :any

        type_definition =
          Location.get_type_position_using_metadata(mod, fun, call_arity, metadata.types)

        case type_definition do
          nil ->
            Location.find_type_source(mod, fun, call_arity)

          %TypeInfo{} = info ->
            {{line, column}, {end_line, end_column}} = Location.info_to_range(info)

            %Location{
              file: nil,
              type: :typespec,
              line: line,
              column: column,
              end_line: end_line,
              end_column: end_column
            }
        end
    end
  end

  def find_function(mod, fun, arity, metadata) do
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

  defp get_module(module, %{end: {line, col}}, env, metadata) do
    with {true, module} <- get_phoenix_module(module, env),
         true <- Introspection.elixir_module?(module) do
      text_before = Source.text_before(metadata.source, line, col)

      case Scope.within_scope(text_before) do
        {false, _} ->
          module

        {true, scope_alias} ->
          Module.concat(scope_alias, module)
      end
    end
  end

  defp get_phoenix_module(module, env) do
    case {Phoenix.Router in env.requires, module} do
      {true, {:atom, module}} -> {true, module}
      {false, {:atom, module}} -> module
      _ -> nil
    end
  end
end
