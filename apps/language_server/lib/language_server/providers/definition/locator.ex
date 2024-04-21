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
  alias ElixirSense.Core.Introspection
  alias ElixirSense.Core.Metadata
  alias ElixirSense.Core.State
  alias ElixirSense.Core.State.ModFunInfo
  alias ElixirSense.Core.State.TypeInfo
  alias ElixirSense.Core.State.VarInfo
  alias ElixirSense.Core.Source
  alias ElixirSense.Core.SurroundContext
  alias ElixirLS.LanguageServer.Location
  alias ElixirSense.Core.Parser

  alias ElixirLS.LanguageServer.Plugins.Phoenix.Scope
  alias ElixirSense.Core.Normalized.Code, as: NormalizedCode

  def definition(code, line, column, options \\ []) do
    case NormalizedCode.Fragment.surround_context(code, {line, column}) do
      :none ->
        nil

      context ->
        metadata =
          Keyword.get_lazy(options, :metadata, fn ->
            Parser.parse_string(code, true, true, {line, column})
          end)

        env =
          Metadata.get_env(metadata, {line, column})
          |> Metadata.add_scope_vars(metadata, {line, column})

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
          vars: vars,
          attributes: attributes
        } = env,
        metadata
      ) do
    binding_env = Binding.from_env(env, metadata)

    type = SurroundContext.to_binding(context.context, module)

    case type do
      nil ->
        nil

      {:keyword, _} ->
        nil

      {:variable, variable} ->
        var_info =
          vars
          |> Enum.find(fn
            %VarInfo{name: name, positions: positions} ->
              name == variable and context.begin in positions
          end)

        if var_info != nil do
          {definition_line, definition_column} = Enum.min(var_info.positions)

          %Location{type: :variable, file: nil, line: definition_line, column: definition_column}
        else
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
          %Location{type: :attribute, file: nil, line: line, column: column}
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
         {{kind, _} = type, function},
         context,
         env,
         metadata,
         binding_env,
         visited
       )
       when kind in [:attribute, :variable] do
    case Binding.expand(binding_env, type) do
      {:atom, module} ->
        do_find_function_or_module(
          {{:atom, Introspection.expand_alias(module, env.aliases)}, function},
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
         %State.Env{scope: {function, arity}, module: module} = env,
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
    %State.Env{
      module: current_module,
      requires: requires,
      aliases: aliases,
      scope: scope
    } = env

    m = get_module(module, context, env, metadata)

    case {m, function}
         |> Introspection.actual_mod_fun(
           env.functions,
           env.macros,
           requires,
           aliases,
           current_module,
           scope,
           metadata.mods_funs_to_positions,
           metadata.types,
           context.begin
         ) do
      {_, _, false, _} ->
        nil

      {mod, fun, true, :mod_fun} ->
        {line, column} = context.end
        call_arity = Metadata.get_call_arity(metadata, mod, fun, line, column) || :any

        fn_definition =
          Location.get_function_position_using_metadata(
            mod,
            fun,
            call_arity,
            metadata.mods_funs_to_positions
          )

        case fn_definition do
          nil ->
            Location.find_mod_fun_source(mod, fun, call_arity)

          %ModFunInfo{positions: positions} = mi ->
            # for simplicity take last position here as positions are reversed
            {line, column} = positions |> Enum.at(-1)

            %Location{
              file: nil,
              type: ModFunInfo.get_category(mi),
              line: line,
              column: column
            }
        end

      {mod, fun, true, :type} ->
        {line, column} = context.end
        call_arity = Metadata.get_call_arity(metadata, mod, fun, line, column) || :any

        type_definition =
          Location.get_type_position_using_metadata(mod, fun, call_arity, metadata.types)

        case type_definition do
          nil ->
            Location.find_type_source(mod, fun, call_arity)

          %TypeInfo{positions: positions} ->
            # for simplicity take last position here as positions are reversed
            {line, column} = positions |> Enum.at(-1)

            %Location{
              file: nil,
              type: :typespec,
              line: line,
              column: column
            }
        end
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
