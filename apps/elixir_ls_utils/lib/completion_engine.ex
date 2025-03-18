# This code has originally been a part of https://github.com/elixir-lsp/elixir_sense

# Copyright (c) 2017 Marlus Saraiva
# Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the 'Software'), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
# The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

# This file includes modified code extracted from the elixir project. Namely:
#
# https://github.com/elixir-lang/elixir/blob/v1.1/lib/iex/lib/iex/autocomplete.exs
#
# The original code is licensed as follows:
#
# Copyright 2012 Plataformatec
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# This module is based on IEx.Autocomplete from version ~ 1.1
# with some changes inspired by Alchemist.Completer (itself based on IEx.Autocomplete).
# Since then the codebases have diverged as the requirements
# put on editor and REPL autocomplete are different.
# However some relevant changes have been merged back
# from upstream Elixir (1.13).
# Changes made to the original version include:
# - different result format with added docs and spec
# - built in and private funcs are not excluded
# - hint generation removed
# - added expansion basing on metadata besides introspection
# - uses custom docs extraction function
# - gets metadata by argument instead of environment variables
#   (original Elixir 1.1) and later GenServer
# - no signature completion as it's handled by signature provider
# - added attribute completion
# - improved completion after %, ^ and & operators

defmodule ElixirLS.Utils.CompletionEngine do
  @moduledoc """
  Provides generic completion for functions, macros, attributes, variables
  """
  alias ElixirSense.Core.Applications
  alias ElixirSense.Core.Behaviours
  alias ElixirSense.Core.Binding
  alias ElixirSense.Core.BuiltinAttributes
  alias ElixirSense.Core.BuiltinFunctions
  alias ElixirSense.Core.Introspection
  alias ElixirSense.Core.Metadata
  alias ElixirSense.Core.Normalized.Code, as: NormalizedCode
  alias ElixirSense.Core.Source
  alias ElixirSense.Core.State
  alias ElixirSense.Core.Struct
  alias ElixirSense.Core.TypeInfo

  alias ElixirLS.Utils.Matcher
  require Logger

  @module_results_cache_key :"#{__MODULE__}_module_results_cache"

  @erlang_module_builtin_functions [{:module_info, 0}, {:module_info, 1}]
  @elixir_module_builtin_functions [{:__info__, 1}]
  @builtin_functions @erlang_module_builtin_functions ++ @elixir_module_builtin_functions

  @bitstring_modifiers [
    %{type: :bitstring_option, name: "big"},
    %{type: :bitstring_option, name: "binary"},
    %{type: :bitstring_option, name: "bitstring"},
    %{type: :bitstring_option, name: "integer"},
    %{type: :bitstring_option, name: "float"},
    %{type: :bitstring_option, name: "little"},
    %{type: :bitstring_option, name: "native"},
    %{type: :bitstring_option, name: "signed"},
    %{type: :bitstring_option, name: "size", arity: 1},
    %{type: :bitstring_option, name: "unit", arity: 1},
    %{type: :bitstring_option, name: "unsigned"},
    %{type: :bitstring_option, name: "utf8"},
    %{type: :bitstring_option, name: "utf16"},
    %{type: :bitstring_option, name: "utf32"}
  ]

  @alias_only_atoms ~w(alias import require)a
  @alias_only_charlists ~w(alias import require)c

  @type attribute :: %{
          type: :attribute,
          name: String.t(),
          summary: String.t() | nil
        }

  @type variable :: %{
          type: :variable,
          name: String.t()
        }

  @type func :: %{
          type: :function | :macro,
          visibility: :public | :private,
          name: String.t(),
          needed_require: String.t() | nil,
          needed_import: {String.t(), {String.t(), integer()}} | nil,
          arity: non_neg_integer,
          def_arity: non_neg_integer,
          args: String.t(),
          args_list: [String.t()],
          origin: String.t(),
          summary: String.t(),
          spec: String.t(),
          snippet: String.t() | nil,
          metadata: map
        }

  @type mod :: %{
          type: :module,
          name: String.t(),
          subtype: ElixirSense.Core.Introspection.module_subtype(),
          summary: String.t(),
          metadata: map,
          required_alias: String.t() | nil
        }

  @type field :: %{
          type: :field,
          subtype: :struct_field | :map_key,
          name: String.t(),
          origin: String.t() | nil,
          call?: boolean,
          type_spec: String.t() | nil
        }

  @type bitstring_option :: %{
          type: :bitstring_option,
          name: String.t(),
          arity: non_neg_integer,
   }

  @type t() ::
          mod()
          | func()
          | variable()
          | field()
          | attribute()

  @spec complete(String.t(), State.Env.t(), Metadata.t(), {pos_integer, pos_integer}, keyword()) ::
          [t()]
  def complete(hint, %State.Env{} = env, %Metadata{} = metadata, cursor_position, opts \\ []) do
    do_expand(hint |> String.to_charlist(), env, metadata, cursor_position, opts)
  end

  def do_expand(code, %State.Env{} = env, %Metadata{} = metadata, cursor_position, opts \\ []) do
    case NormalizedCode.Fragment.cursor_context(code |> dbg) |> dbg do
      {:alias, hint} when is_list(hint) ->
        expand_aliases(List.to_string(hint), env, metadata, cursor_position, false, opts)

      {:alias, prefix, hint} ->
        expand_prefixed_aliases(prefix, hint, env, metadata, cursor_position, false)

      {:unquoted_atom, unquoted_atom} ->
        expand_erlang_modules(List.to_string(unquoted_atom), env, metadata)

      {:dot, path, hint} ->
        if alias = alias_only(path, hint, code, env, metadata, cursor_position) do
          expand_aliases(List.to_string(alias), env, metadata, cursor_position, false, opts)
        else
        expand_dot(
          path,
          List.to_string(hint),
          false,
          env,
          metadata,
          cursor_position,
          false,
          opts
        )
        end

      {:dot_arity, path, hint} ->
        expand_dot(
          path,
          List.to_string(hint),
          true,
          env,
          metadata,
          cursor_position,
          false,
          opts
        )

      {:dot_call, _path, _hint} ->
        # no need to expand signatures here, we have signatures provider
        # IEx calls
        # expand_dot_call(path, List.to_atom(hint), env)
        # to provide signatures and falls back to expand_local_or_var
        expand_expr(env, metadata, cursor_position, opts)

      :expr ->
        # IEx calls expand_struct_fields_or_local_or_var(code, "", env)
        # we choose to return more and handle some special cases
        # TODO expand_expr(env) after we require elixir 1.13

        
        {results, continue?} = expand_container_context(code, :expr, "", env, metadata, cursor_position)
        if continue?, do: results ++ (
        # expand_local_or_var("", env, metadata, cursor_position), else: results
        case code |> dbg do
          [?^] -> expand_var("", env, metadata)
          [?%] ->
            expand_aliases("", env, metadata, cursor_position, true, opts)
            # expand_struct_fields_or_local_or_var(code, "", env, metadata, cursor_position)
          _ ->
            expand_expr(env, metadata, cursor_position, opts)
        end), else: results

      {:local_or_var, local_or_var} ->
        hint = List.to_string(local_or_var)

        {results, continue?} = expand_container_context(code, :expr, hint, env, metadata, cursor_position)
        if continue?, do: results ++ expand_local_or_var(hint, env, metadata, cursor_position), else: results

      # elixir >= 1.18
      {:capture_arg, capture_arg} ->
        expand_local_or_var(List.to_string(capture_arg), env, metadata, cursor_position)

      {:local_arity, local} ->
        expand_local(List.to_string(local), true, env, metadata, cursor_position)

      {:local_call, local} when local in @alias_only_charlists ->
        expand_aliases("", env, metadata, cursor_position, false, opts)

      {:local_call, _local} ->
        # no need to expand signatures here, we have signatures provider
        # expand_local_call(List.to_atom(local), env)
        # IEx calls
        # expand_dot_call(path, List.to_atom(hint), env)
        # to provide signatures and falls back to expand_local_or_var
        expand_expr(env, metadata, cursor_position, opts)

      {:operator, operator} when operator in ~w(:: -)c ->
        {results, continue?} = expand_container_context(code, :operator, "", env, metadata, cursor_position)
        if continue?, do: results ++ expand_local(List.to_string(operator), false, env, metadata, cursor_position), else: results

      {:operator, operator} ->
        case operator do
          [?^] -> expand_var("", env, metadata)
          [?&] -> expand_expr(env, metadata, cursor_position, opts)
          _ -> expand_local(List.to_string(operator), false, env, metadata, cursor_position)
        end

      {:operator_arity, operator} ->
        expand_local(List.to_string(operator), true, env, metadata, cursor_position)

      {:operator_call, operator} when operator in ~w(|)c ->
        {results, continue?} = expand_container_context(code, :expr, "", env, metadata, cursor_position)
        if continue?, do: results ++ expand_local_or_var("", env, metadata, cursor_position), else: results

      {:operator_call, _operator} ->
        expand_local_or_var("", env, metadata, cursor_position)

      {:sigil, []} ->
        expand_sigil(env, metadata, cursor_position)

      {:sigil, [_]} ->
        # {:yes, [], ~w|" """ ' ''' \( / < [ { \||c}
        # we choose to not provide sigil chars
        no()

      {:struct, struct} when is_list(struct) ->
        expand_aliases(List.to_string(struct), env, metadata, cursor_position, true, opts)

      # elixir >= 1.14
      {:struct, {:alias, prefix, hint}} ->
        expand_prefixed_aliases(prefix, hint, env, metadata, cursor_position, true)

      # elixir >= 1.14
      {:struct, {:dot, path, hint}} ->
        expand_dot(path, List.to_string(hint), false, env, metadata, cursor_position, true, opts)

      # elixir >= 1.14
      {:struct, {:module_attribute, attribute}} ->
        expand_attribute(List.to_string(attribute), env, metadata)

      # elixir >= 1.14
      {:struct, {:local_or_var, local_or_var}} ->
        expand_local_or_var(List.to_string(local_or_var), env, metadata, cursor_position)

      {:module_attribute, attribute} ->
        expand_attribute(List.to_string(attribute), env, metadata)

      # elixir >= 1.16
      {:anonymous_call, _} ->
        expand_expr(env, metadata, cursor_position, opts)

      :none ->
        no()
    end
  end

  defp expand_dot(
         path,
         hint,
         exact?,
         %State.Env{} = env,
         %Metadata{} = metadata,
         cursor_position,
         only_structs,
         opts
       ) do
    filter = struct_module_filter(only_structs, env, metadata)

    case expand_dot_path(path, env, metadata, cursor_position) do
      {:ok, {:atom, mod}} when hint == "" ->
        expand_aliases(
          mod,
          "",
          [],
          not only_structs,
          env,
          metadata,
          cursor_position,
          filter,
          opts
        )

      {:ok, {:atom, mod}} ->
        expand_require(mod, hint, exact?, env, metadata, cursor_position)

      {:ok, {:map, fields, _}} ->
        expand_map_field_access(fields, hint, :map, env, metadata)

      {:ok, {:struct, fields, type, _}} ->
        expand_map_field_access(fields, hint, {:struct, type}, env, metadata)

      _ ->
        no()
    end
  end

  # elixir >= 1.14
  defp expand_dot_path(
         {:var, ~c"__MODULE__"},
         %State.Env{} = env,
         %Metadata{} = _metadata,
         _cursor_position
       ) do
    if env.module != nil and Introspection.elixir_module?(env.module) do
      {:ok, {:atom, env.module}}
    else
      :error
    end
  end

  defp expand_dot_path({:var, var}, %State.Env{} = env, %Metadata{} = metadata, cursor_position) do
    value_from_binding({:variable, List.to_atom(var), :any}, env, metadata, cursor_position)
  end

  defp expand_dot_path(
         {:module_attribute, attribute},
         %State.Env{} = env,
         %Metadata{} = metadata,
         cursor_position
       ) do
    value_from_binding({:attribute, List.to_atom(attribute)}, env, metadata, cursor_position)
  end

  defp expand_dot_path(
         {:alias, hint},
         %State.Env{} = env,
         %Metadata{} = metadata,
         _cursor_position
       ) do
    alias = hint |> List.to_string() |> String.split(".") |> value_from_alias(env, metadata)

    case alias do
      {:ok, atom} -> {:ok, {:atom, atom}}
      :error -> :error
    end
  end

  # elixir >= 1.14
  defp expand_dot_path(
         {:alias, {:local_or_var, var}, hint},
         %State.Env{} = env,
         %Metadata{} = metadata,
         _cursor_position
       ) do
    case var do
      ~c"__MODULE__" ->
        alias_suffix = hint |> List.to_string() |> String.split(".")
        alias = [{:__MODULE__, [], nil} | alias_suffix] |> value_from_alias(env, metadata)

        case alias do
          {:ok, atom} -> {:ok, {:atom, atom}}
          :error -> :error
        end

      _ ->
        :error
    end
  end

  defp expand_dot_path(
         {:alias, {:module_attribute, attribute}, hint},
         %State.Env{} = env,
         %Metadata{} = metadata,
         cursor_position
       ) do
    case value_from_binding({:attribute, List.to_atom(attribute)}, env, metadata, cursor_position) do
      {:ok, {:atom, atom}} ->
        if Introspection.elixir_module?(atom) do
          alias_suffix = hint |> List.to_string() |> String.split(".")
          alias = (Module.split(atom) ++ alias_suffix) |> value_from_alias(env, metadata)

          case alias do
            {:ok, atom} -> {:ok, {:atom, atom}}
            :error -> :error
          end
        else
          :error
        end

      :error ->
        :error
    end
  end

  defp expand_dot_path(
         {:alias, _, _hint},
         %State.Env{} = _env,
         %Metadata{} = _metadata,
         _cursor_position
       ) do
    :error
  end

  defp expand_dot_path(
         {:unquoted_atom, var},
         %State.Env{} = _env,
         %Metadata{} = _metadata,
         _cursor_position
       ) do
    {:ok, {:atom, List.to_atom(var)}}
  end

  defp expand_dot_path(
         {:dot, parent, call},
         %State.Env{} = env,
         %Metadata{} = metadata,
         cursor_position
       ) do
    case expand_dot_path(parent, env, metadata, cursor_position) do
      {:ok, expanded} ->
        value_from_binding(
          {:call, expanded, List.to_atom(call), []},
          env,
          metadata,
          cursor_position
        )

      :error ->
        :error
    end
  end

  # elixir >= 1.15
  defp expand_dot_path(:expr, %State.Env{} = _env, %Metadata{} = _metadata, _cursor_position) do
    # TODO expand expression
    :error
  end

  defp expand_expr(%State.Env{} = env, %Metadata{} = metadata, cursor_position, opts) do
    local_or_var = expand_local_or_var("", env, metadata, cursor_position)
    erlang_modules = expand_erlang_modules("", env, metadata)
    elixir_modules = expand_aliases("", env, metadata, cursor_position, false, opts)
    attributes = expand_attribute("", env, metadata)

    local_or_var ++ erlang_modules ++ elixir_modules ++ attributes
  end

  defp no do
    []
  end

  ## Formatting

  defp format_expansion(entries) do
    Enum.flat_map(entries, &to_entries/1)
  end

  defp expand_map_field_access(fields, hint, type, %State.Env{} = env, %Metadata{} = metadata) do
    # when there is only one matching field and it's exact to the hint
    # and it's not a nested map, iex does not return completions
    # We choose to return it normally
    match_map_fields(fields, hint, type, env, metadata)
    |> format_expansion()
  end

  defp expand_require(
         mod,
         hint,
         exact?,
         %State.Env{} = env,
         %Metadata{} = metadata,
         cursor_position
       ) do
    format_expansion(
      match_module_funs(mod, hint, exact?, true, :all, env, metadata, cursor_position)
    )
  end

  ## Expand local or var

  defp expand_local_or_var(hint, %State.Env{} = env, %Metadata{} = metadata, cursor_position) do
    format_expansion(
      match_var(hint, env, metadata) ++ match_local(hint, false, env, metadata, cursor_position)
    )
  end

  defp expand_local(hint, exact?, %State.Env{} = env, %Metadata{} = metadata, cursor_position) do
    format_expansion(match_local(hint, exact?, env, metadata, cursor_position))
  end

  defp expand_var(hint, %State.Env{} = env, %Metadata{} = metadata) do
    variables = match_var(hint, env, metadata)
    format_expansion(variables)
  end

  defp expand_sigil(%State.Env{} = env, %Metadata{} = metadata, cursor_position) do
    sigils =
      match_local("sigil_", false, env, metadata, cursor_position)
      |> Enum.filter(fn %{name: name} -> String.starts_with?(name, "sigil_") end)
      |> Enum.map(fn %{name: "sigil_" <> rest} = local ->
        %{local | name: "~" <> rest}
      end)

    locals = match_local("~", false, env, metadata, cursor_position)

    format_expansion(sigils ++ locals)
  end

  defp match_local(hint, exact?, %State.Env{} = env, %Metadata{} = metadata, cursor_position) do
    kernel_special_forms_locals =
      match_module_funs(
        Kernel.SpecialForms,
        hint,
        exact?,
        false,
        :all,
        env,
        metadata,
        cursor_position
      )

    current_module_locals =
      if env.module && env.function do
        match_module_funs(env.module, hint, exact?, false, :all, env, metadata, cursor_position)
      else
        []
      end

    imported_locals =
      {env.functions, env.macros}
      |> Introspection.combine_imports()
      |> Enum.flat_map(fn {scope_import, imported} ->
        match_module_funs(
          scope_import,
          hint,
          exact?,
          false,
          imported,
          env,
          metadata,
          cursor_position
        )
      end)

    kernel_special_forms_locals ++ current_module_locals ++ imported_locals
  end

  defp match_var(hint, %State.Env{vars: vars}, %Metadata{} = _metadata) do
    for(
      %State.VarInfo{name: name} when is_atom(name) <- vars,
      name = Atom.to_string(name),
      Matcher.match?(name, hint),
      do: name
    )
    |> Enum.sort()
    |> Enum.map(&%{kind: :variable, name: &1})
  end

  # do not suggest attributes outside of a module
  defp expand_attribute(_, %State.Env{module: module}, %Metadata{} = _metadata)
       when module == nil,
       do: no()

  defp expand_attribute(
         hint,
         %State.Env{attributes: attributes} = env,
         %Metadata{} = _metadata
       ) do
    attribute_names =
      attributes
      |> Enum.map(fn %State.AttributeInfo{name: name} -> name end)

    attribute_names =
      case env do
        %State.Env{function: {_fun, _arity}} ->
          attribute_names

        %State.Env{module: module} when not is_nil(module) ->
          # include module attributes in module scope
          attribute_names ++ BuiltinAttributes.all()

        _ ->
          []
      end

    for(
      attribute_name when is_atom(attribute_name) <- attribute_names,
      name = Atom.to_string(attribute_name),
      Matcher.match?(name, hint),
      do: attribute_name
    )
    |> Enum.sort()
    |> Enum.map(
      &%{
        kind: :attribute,
        name: Atom.to_string(&1),
        summary: BuiltinAttributes.docs(&1)
      }
    )
    |> format_expansion()
  end

  ## Erlang modules

  defp expand_erlang_modules(hint, %State.Env{} = env, %Metadata{} = metadata) do
    format_expansion(match_erlang_modules(hint, env, metadata))
  end

  defp match_erlang_modules(hint, %State.Env{} = env, %Metadata{} = metadata) do
    for mod <- match_modules(hint, true, env, metadata),
        usable_as_unquoted_module?(mod) do
      mod_as_atom = String.to_atom(mod)

      case :persistent_term.get({@module_results_cache_key, mod_as_atom}, nil) do
        nil -> get_erlang_module_result(mod_as_atom)
        result -> result
      end
    end
  end

  def fill_erlang_module_cache(module, docs) do
    get_erlang_module_result(module, docs)
  end

  defp get_erlang_module_result(module, docs \\ nil) do
    subtype = Introspection.get_module_subtype(module)
    desc = Introspection.get_module_docs_summary(module, docs)

    name = inspect(module)

    result = %{
      kind: :module,
      name: name,
      full_name: name,
      type: :erlang,
      desc: desc,
      subtype: subtype
    }

    :persistent_term.put({@module_results_cache_key, module}, result)
    result
  end

  defp struct_module_filter(true, %State.Env{} = _env, %Metadata{} = metadata) do
    fn module -> Struct.is_struct(module, metadata.structs) end
  end

  defp struct_module_filter(false, %State.Env{} = _env, %Metadata{} = _metadata) do
    fn _ -> true end
  end

  defp struct?(mod, metadata) do
    Struct.is_struct(mod, metadata.structs)
    # Code.ensure_loaded?(mod) and function_exported?(mod, :__struct__, 1)
  end

  # defp expand_struct_fields_or_local_or_var(code, hint, env, metadata, cursor_position) do
  #   with {:ok, quoted} <- NormalizedCode.Fragment.container_cursor_to_quoted(code) |> dbg,
  #        {aliases, pairs} <- find_struct_fields(quoted),
  #        {:ok, alias} <- value_from_alias(aliases, env, metadata),
  #        true <- struct?(alias, metadata) do

  #     types = ElixirLS.Utils.Field.get_field_types(metadata, alias, true)

  #     entries =
  #       for key <- Struct.get_fields(alias, metadata.structs),
  #           not Keyword.has_key?(pairs, key),
  #           name = Atom.to_string(key),
  #           Matcher.match?(name, hint),
  #           [spec] = [case types[key] do
  #               nil ->
  #                 case key do
  #                   :__struct__ -> inspect(alias) || "atom()"
  #                   :__exception__ -> "true"
  #                   _ -> nil
  #                 end

  #               some ->
  #                 Introspection.to_string_with_parens(some)
  #             end],
  #           do: %{
  #             kind: :field,
  #             name: name,
  #             subtype: :struct_field,
  #             value_is_map: false,
  #             origin: inspect(alias),
  #             call?: false,
  #             type_spec: spec
  #           }
            
  #           # %{kind: :keyword, name: name}

  #     format_expansion(entries|>Enum.sort_by(& &1.name))
  #   else
  #     _ -> expand_local_or_var(hint, env, metadata, cursor_position)
  #   end
  # end

  defp expand_container_context(code, context, hint, env, metadata, cursor_position) do
    case container_context(code, env, metadata, cursor_position) |> dbg do
      {:map, map, pairs} when context == :expr ->
        continue? = pairs == []
        {container_context_map_fields(pairs, :map, map, hint, metadata), continue?}

      {:struct, alias, pairs} when context == :expr ->
        continue? = pairs == []
        {container_context_map_fields(pairs, {:struct, alias}, %{}, hint, metadata), continue?}

      :bitstring_modifier ->
        existing =
          code
          |> List.to_string()
          |> String.split("::")
          |> List.last()
          |> String.split("-")

        results = @bitstring_modifiers
        |> Enum.filter(&(Matcher.match?(&1.name, hint) and &1.name not in existing))
        |> format_expansion()

        {results, false}

      _ ->
        {[], true}
    end
  end

  defp container_context_map_fields(pairs, kind, map, hint, metadata) do
    {keys, types, alias} = case kind do
      {:struct, alias} ->
        keys = Struct.get_fields(alias, metadata.structs)
        types = ElixirLS.Utils.Field.get_field_types(metadata, alias, true)
        {keys, types, alias}
      _ ->
      {Map.keys(map), %{}, nil}
    end |> dbg

    entries =
      for key <- keys,
          not Keyword.has_key?(pairs |> dbg, key),
          name = Atom.to_string(key),
          Matcher.match?(name, hint) do
            spec = case types[key] do
                            nil ->
                              case key do
                                :__struct__ -> if(alias, do: inspect(alias), else: "atom()")
                                :__exception__ -> "true"
                                _ -> nil
                              end
            
                            some ->
                              Introspection.to_string_with_parens(some)
                          end
            %{
                        kind: :field,
                        name: name,
                        subtype: if(kind == :map, do: :map_field, else: :struct_field),
                        value_is_map: false,
                        origin: if(kind != :map and alias, do: inspect(alias)),
                        call?: false,
                        type_spec: spec
                      }
                    end

    format_expansion(entries |> Enum.sort_by(& &1.name))
  end

  defp container_context(code, env, metadata, cursor_position) do
    case NormalizedCode.Fragment.container_cursor_to_quoted(code) |> dbg do
      {:ok, quoted} ->
        case Macro.path(quoted, &match?({:__cursor__, _, []}, &1)) |> dbg do
          [cursor, {:%{}, _, pairs}, {:%, _, [struct_module_ast, _map]} | _] ->
            container_context_struct(cursor, pairs |> dbg, struct_module_ast, env, metadata, cursor_position) |> dbg

          [
            cursor,
            pairs,
            {:|, _, _},
            {:%{}, _, _},
            {:%, _, [struct_module_ast, _map]} | _
          ] ->
            container_context_struct(cursor, pairs, struct_module_ast, env, metadata, cursor_position)

          [cursor, pairs, {:|, _, [expr | _]}, {:%{}, _, _} | _] ->
            container_context_map(cursor, pairs, expr, env, metadata, cursor_position) |> dbg

          [cursor, {special_form, _, [cursor]} | _] when special_form in @alias_only_atoms ->
            :alias_only

          [cursor | tail] ->
            case remove_operators(tail, cursor) do
              [{:"::", _, [_, _]}, {:<<>>, _, [_ | _]} | _] -> :bitstring_modifier
              _ -> nil
            end

          _ ->
            nil
        end

      {:error, _} ->
        nil
    end
  end

  defp remove_operators([{op, _, [_, previous]} = head | tail], previous) when op in [:-],
    do: remove_operators(tail, head)

  defp remove_operators(tail, _previous),
    do: tail

  defp expand_struct_module(atom, _env, _metadata, _cursor_position) when is_atom(atom) do
    {:ok, atom}
  end

  defp expand_struct_module({:__MODULE__, _, context}, env = %{module: module}, _metadata, _cursor_position) when is_atom(context) and not is_nil(module) do
    {:ok, module}
  end

  defp expand_struct_module({:@, _, [{attribute, _, context}]}, env = %{function: {_, _}}, metadata, cursor_position) when is_atom(context) and is_atom(attribute) do
    case value_from_binding({:attribute, attribute}, env, metadata, cursor_position) do
      {:ok, {:atom, atom}} ->
        {:ok, atom}
      _ ->
        :error
    end
  end

  defp expand_struct_module({:__aliases__, _, aliases = [h | _]}, env, metadata, _cursor_position) when is_atom(h) do
    value_from_alias(aliases, env, metadata)
  end

  defp expand_struct_module({:__aliases__, _, aliases = [{:__MODULE__, _, context} | rest]}, env = %{module: module}, metadata, _cursor_position) when is_atom(context) and not is_nil(module) do
    {:ok, Module.concat([module | rest])}
  end

  defp expand_struct_module({:__aliases__, _, aliases = [{:@, _, [{attribute, _, context}]} | rest]}, env = %{function: {_, _}}, metadata, cursor_position) when is_atom(context) and is_atom(attribute) do
    case value_from_binding({:attribute, attribute}, env, metadata, cursor_position) do
      {:ok, {:atom, atom}} ->
        {:ok, Module.concat([atom | rest])}
      _ ->
        :error
    end
  end

  defp expand_struct_module({variable, _, context}, env = %{context: :match}, _metadata, _cursor_position) when is_atom(context) and is_atom(variable) do
    {:ok, nil}
  end

  defp expand_struct_module(_ast, _env, _metadata, _cursor_position) do
    :error
  end

  defp container_context_struct(cursor, pairs, ast, env, metadata, cursor_position) do
    with {pairs, [^cursor]} <- Enum.split(pairs, -1),
         {:ok, alias} <- expand_struct_module(ast, env, metadata, cursor_position),
         true <- Keyword.keyword?(pairs) and (struct?(alias, metadata) or alias == nil) do
      {:struct, alias, pairs}
    else
      _ -> nil
    end
  end

  defp container_context_map(cursor, pairs, expr, env, metadata, cursor_position) do
    # TODO extract to function
    binding_ast = case expr do
      {:@, _, [{atom, _, context}]} when is_atom(atom) and is_atom(context) -> {:attribute, atom}
      {atom, _, context} when is_atom(atom) and is_atom(context) -> {:variable, atom, :any}
      {atom, _, args} when is_atom(atom) and is_list(args) ->
        # TODO filter special
        # TODO map args
        {:local_call, atom, cursor_position, (for a <- args, do: nil)}
      {{:., _, [remote, fun]}, _, args} when is_atom(fun) and is_list(args) ->
        remote = case remote do
          atom when is_atom(atom) -> atom
          {:__MODULE__, _, context} when is_atom(context) -> env.module
          {:__aliases__, _, [:__MODULE__ | rest]} ->
            # TODO check if it works
            Module.concat([env.module | rest])
          # TODO attribute submodule
          {:__aliases__, _, list = [h | _]} when is_atom(h) ->
            # TODO expand alias
            Module.concat(list)
          _ -> nil
        end
        if remote do
          # TODO map args
          {:call, {:atom, remote}, fun, (for a <- args, do: nil)}
        end
      _ -> nil
    end
    with {pairs, [^cursor]} <- Enum.split(pairs, -1),
         {:ok, type} <- value_from_binding(binding_ast, env, metadata, cursor_position),
         true <- Keyword.keyword?(pairs) do
      case type do
        {:map, all, _} ->
          {:map, Map.new(all), pairs}
        {:struct, all, origin, _} ->
          case origin do
            {:atom, alias} -> {:struct, alias, pairs}
            _ ->
              # TODO maybe add __struct__
              {:map, Map.new(all), pairs}
          end
        _ -> nil
      end
    else
      _ -> nil
    end |> dbg
  end

  ## Aliases and modules

  defp alias_only(path, hint, code, env, metadata, cursor_position) do
    # TODO __MODULE__ @?
    with {:alias, alias} <- path,
         [] <- hint,
         :alias_only <- container_context(code, env, metadata, cursor_position) do
      alias ++ [?.]
    else
      _ -> nil
    end
  end

  defp expand_aliases(
         all,
         %State.Env{} = env,
         %Metadata{} = metadata,
         cursor_position,
         only_structs,
         opts
       ) do
    filter = struct_module_filter(only_structs, env, metadata)

    case String.split(all, ".") do
      [hint] ->
        aliases = match_aliases(hint, env, metadata)
        expand_aliases(Elixir, hint, aliases, false, env, metadata, cursor_position, filter, opts)

      parts ->
        hint = List.last(parts)
        list = Enum.take(parts, length(parts) - 1)

        case value_from_alias(list, env, metadata) do
          {:ok, alias} ->
            expand_aliases(
              alias,
              hint,
              [],
              false,
              env,
              metadata,
              cursor_position,
              filter,
              Keyword.put(opts, :required_alias, false)
            )

          :error ->
            no()
        end
    end
  end

  defp expand_aliases(
         mod,
         hint,
         aliases,
         include_funs,
         %State.Env{} = env,
         %Metadata{} = metadata,
         cursor_position,
         filter,
         opts
       ) do
    aliases
    |> Kernel.++(match_elixir_modules(mod, hint, env, metadata, filter, opts))
    |> Kernel.++(
      if include_funs,
        do: match_module_funs(mod, hint, false, true, :all, env, metadata, cursor_position),
        else: []
    )
    |> format_expansion()
  end

  defp expand_prefixed_aliases(
         {:local_or_var, ~c"__MODULE__"},
         hint,
         %State.Env{} = env,
         %Metadata{} = metadata,
         cursor_position,
         only_structs
       ) do
    if env.module != nil and Introspection.elixir_module?(env.module) do
      expand_aliases("#{env.module}.#{hint}", env, metadata, cursor_position, only_structs, [])
    else
      no()
    end
  end

  defp expand_prefixed_aliases(
         {:module_attribute, attribute},
         hint,
         %State.Env{} = env,
         %Metadata{} = metadata,
         cursor_position,
         only_structs
       ) do
    case value_from_binding({:attribute, List.to_atom(attribute)}, env, metadata, cursor_position) do
      {:ok, {:atom, atom}} ->
        if Introspection.elixir_module?(atom) do
          expand_aliases("#{atom}.#{hint}", env, metadata, cursor_position, only_structs, [])
        else
          no()
        end

      {:ok, _} ->
        # this clause can match e.g. in
        # @abc %{SOME: 123}
        # @abc.SOME
        # but this code does not compile as it defines an invalid alias
        no()

      :error ->
        no()
    end
  end

  defp expand_prefixed_aliases(
         _,
         _hint,
         %State.Env{} = _env,
         %Metadata{} = _metadata,
         _cursor_position,
         _only_structs
       ),
       do: no()

  defp value_from_alias(mod_parts, %State.Env{} = env, %Metadata{} = _metadata) do
    mod_parts
    |> Enum.map(fn
      bin when is_binary(bin) -> String.to_atom(bin)
      other -> other
    end)
    |> Source.concat_module_parts(env.module, env.aliases)
  end

  defp match_aliases(hint, %State.Env{} = env, %Metadata{} = _metadata) do
    for {alias, mod} <- env.aliases,
        [name] = Module.split(alias),
        Matcher.match?(name, hint) do
      %{
        kind: :module,
        type: :elixir,
        name: name,
        full_name: inspect(mod),
        desc: {"", %{}},
        subtype: Introspection.get_module_subtype(mod)
      }
    end
  end

  defp match_elixir_modules(
         module,
         hint,
         %State.Env{} = env,
         %Metadata{} = metadata,
         filter,
         opts
       ) do
    name = Atom.to_string(module)
    depth = length(String.split(name, ".")) + 1
    base = name <> "." <> hint

    concat_module = fn
      ["Elixir", "Elixir" | _] = parts -> parts |> tl() |> Module.concat()
      parts -> Module.concat(parts)
    end

    for mod <- match_modules(base, module === Elixir, env, metadata),
        mod_as_atom = mod |> String.to_atom(),
        filter.(mod_as_atom),
        parts = String.split(mod, "."),
        depth <= length(parts),
        name = Enum.at(parts, depth - 1),
        valid_alias_piece?("." <> name),
        concatted = parts |> Enum.take(depth) |> concat_module.(),
        filter.(concatted) do
      {name, concatted, false}
    end
    |> Kernel.++(
      match_elixir_modules_that_require_alias(module, hint, env, metadata, filter, opts)
    )
    |> Enum.reject(fn
      {_, concatted, true} ->
        Enum.find(env.aliases, fn {_as, module} ->
          concatted == module
        end)

      _rest ->
        false
    end)
    |> Enum.uniq_by(&elem(&1, 1))
    |> Enum.map(fn {name, module, required_alias?} ->
      result =
        case metadata.mods_funs_to_positions[{module, nil, nil}] do
          nil ->
            case :persistent_term.get({@module_results_cache_key, module}, nil) do
              nil -> get_elixir_module_result(module)
              result -> result
            end

          info ->
            %{
              kind: :module,
              type: :elixir,
              full_name: inspect(module),
              desc: {Introspection.extract_summary_from_docs(info.doc), info.meta},
              subtype: Metadata.get_module_subtype(metadata, module)
            }
        end

      result = Map.put(result, :name, name)

      if required_alias? do
        Map.put(result, :required_alias, module)
      else
        result
      end
    end)
  end

  def fill_elixir_module_cache(module, docs) do
    get_elixir_module_result(module, docs)
  end

  defp get_elixir_module_result(module, docs \\ nil) do
    {desc, meta} = Introspection.get_module_docs_summary(module, docs)
    subtype = Introspection.get_module_subtype(module)

    result = %{
      kind: :module,
      type: :elixir,
      full_name: inspect(module),
      desc: {desc, meta},
      subtype: subtype
    }

    :persistent_term.put({@module_results_cache_key, module}, result)
    result
  end

  defp valid_alias_piece?(<<?., char, rest::binary>>) when char in ?A..?Z,
    do: valid_alias_rest?(rest)

  defp valid_alias_piece?(_),
    do: false

  defp valid_alias_rest?(<<char, rest::binary>>)
       when char in ?A..?Z
       when char in ?a..?z
       when char in ?0..?9
       when char == ?_,
       do: valid_alias_rest?(rest)

  defp valid_alias_rest?(<<>>),
    do: true

  defp valid_alias_rest?(rest),
    do: valid_alias_piece?(rest)

  ## Helpers

  defp usable_as_unquoted_module?(name) do
    unquoted_atom_or_identifier?(String.to_atom(name)) and
      not String.starts_with?(name, "Elixir.")
  end

  defp unquoted_atom_or_identifier?(atom) when is_atom(atom) do
    # Version.match? is slow, we need to avoid it in a hot loop
    # TODO remove this when we require elixir 1.14
    # Macro.classify_atom/1 was introduced in 1.14.0. If it's not available,
    # assume we're on an older version and fall back to a private API.
    if function_exported?(Macro, :classify_atom, 1) do
      apply(Macro, :classify_atom, [atom]) in [:identifier, :unquoted]
    else
      apply(Code.Identifier, :classify, [atom]) != :other
    end
  end

  defp match_elixir_modules_that_require_alias(
         Elixir,
         hint,
         %State.Env{} = env,
         %Metadata{} = metadata,
         filter,
         opts
       ) do
    if Keyword.get(opts, :required_alias) do
      for {suggestion, required_alias} <-
            find_elixir_modules_that_require_alias(Elixir, hint, env, metadata),
          mod_as_atom = required_alias |> String.to_atom(),
          filter.(mod_as_atom),
          required_alias_mod = required_alias |> String.split(".") |> Module.concat() do
        {suggestion, required_alias_mod, true}
      end
    else
      []
    end
  end

  defp match_elixir_modules_that_require_alias(
         _module,
         _hint,
         %State.Env{} = _env,
         %Metadata{} = _metadata,
         _filter,
         _opts
       ),
       do: []

  defp find_elixir_modules_that_require_alias(Elixir, hint, env, metadata) do
    get_modules(true, env, metadata)
    |> Enum.sort()
    |> Enum.dedup()
    |> Enum.reduce([], fn
      "Elixir." <> module = full_module, acc ->
        subtype = Introspection.get_module_subtype(String.to_atom(full_module))
        # skip mix tasks and protocol implementations as it's not common to need to alias those
        # credo:disable-for-next-line
        if subtype not in [:implementation, :task] do
          # do not search for a match in Elixir. prefix - no need to alias it
          module_parts = module |> String.split(".")

          case module_parts do
            [_] ->
              # no need to alias if module is 1 part
              acc

            [_root | rest] ->
              rest
              |> Enum.with_index(1)
              |> Enum.filter(fn {module_part, _index} ->
                Matcher.match?(module_part, hint)
              end)
              |> Enum.reduce(acc, fn {module_part, index}, acc1 ->
                required_alias = Enum.slice(module_parts, 0..index)
                required_alias = required_alias |> Module.concat() |> Atom.to_string()

                [{module_part, required_alias} | acc1]
              end)
          end
        else
          acc
        end

      _erlang_module, acc ->
        # skip erlang modules
        acc
    end)
    |> Enum.sort()
    |> Enum.dedup()
    |> Enum.filter(fn {suggestion, _required_alias} -> valid_alias_piece?("." <> suggestion) end)
  end

  defp match_modules(hint, root, %State.Env{} = env, %Metadata{} = metadata) do
    hint_parts = hint |> String.split(".")
    hint_parts_length = length(hint_parts)
    [hint_suffix | hint_prefix] = hint_parts |> Enum.reverse()

    root
    |> get_modules(env, metadata)
    |> Enum.sort()
    |> Enum.dedup()
    |> Enum.filter(fn mod ->
      [mod_suffix | mod_prefix] =
        mod |> String.split(".") |> Enum.take(hint_parts_length) |> Enum.reverse()

      hint_prefix == mod_prefix and Matcher.match?(mod_suffix, hint_suffix)
    end)
  end

  defp get_modules(true, %State.Env{} = env, %Metadata{} = metadata) do
    ["Elixir.Elixir"] ++ get_modules(false, env, metadata)
  end

  defp get_modules(false, %State.Env{} = env, %Metadata{} = metadata) do
    # TODO consider changing this to :code.all_available when otp 23 (and elixir 1.14) is required
    modules = Enum.map(:code.all_loaded(), &Atom.to_string(elem(&1, 0)))

    # TODO it seems we only run in interactive mode - remove the check?
    case :code.get_mode() do
      :interactive ->
        modules ++ get_modules_from_applications() ++ get_modules_from_metadata(env, metadata)

      _otherwise ->
        modules ++ get_modules_from_metadata(env, metadata)
    end
  end

  defp get_modules_from_applications do
    for module <- Applications.get_modules_from_applications() do
      Atom.to_string(module)
    end
  end

  defp get_modules_from_metadata(%State.Env{} = _env, %Metadata{} = metadata) do
    for {{k, nil, nil}, _} when is_atom(k) <- metadata.mods_funs_to_positions,
        do: Atom.to_string(k)
  end

  defp match_module_funs(
         mod,
         hint,
         exact?,
         include_builtin,
         imported,
         %State.Env{} = env,
         %Metadata{} = metadata,
         cursor_position
       ) do
    falist =
      cond do
        metadata.mods_funs_to_positions |> Map.has_key?({mod, nil, nil}) ->
          get_metadata_module_funs(mod, include_builtin, env, metadata, cursor_position)

        match?({:module, _}, ensure_loaded(mod)) ->
          get_module_funs(mod, include_builtin)

        true ->
          []
      end
      |> Enum.sort_by(fn {f, a, _, _, _, _, _} -> {f, -a} end)

    list =
      Enum.reduce(falist, [], fn {f, a, def_a, func_kind, {doc_str, meta}, spec, arg}, acc ->
        doc = {Introspection.extract_summary_from_docs(doc_str), meta}

        case :lists.keyfind(f, 1, acc) do
          {f, aa, def_arities, func_kinds, docs, specs, args} ->
            :lists.keyreplace(
              f,
              1,
              acc,
              {f, [a | aa], [def_a | def_arities], [func_kind | func_kinds], [doc | docs],
               [spec | specs], [arg | args]}
            )

          false ->
            [{f, [a], [def_a], [func_kind], [doc], [spec], [arg]} | acc]
        end
      end)

    for {fun, arities, def_arities, func_kinds, docs, specs, args} <- list,
        name = Atom.to_string(fun),
        if(exact?, do: name == hint, else: Matcher.match?(name, hint)) do
      needed_requires =
        for func_kind <- func_kinds do
          if func_kind in [:macro, :defmacro, :defguard] and mod not in env.requires and
               mod != Kernel.SpecialForms and mod != env.module do
            mod
          end
        end

      needed_imports =
        if imported == :all do
          arities |> Enum.map(fn _ -> nil end)
        else
          arities
          |> Enum.map(fn a ->
            if {fun, a} not in imported do
              {mod, {fun, a}}
            end
          end)
        end

      %{
        kind: :function,
        name: name,
        arities: arities,
        def_arities: def_arities,
        module: mod,
        func_kinds: func_kinds,
        docs: docs,
        specs: specs,
        needed_requires: needed_requires,
        needed_imports: needed_imports,
        args: args
      }
    end
    |> Enum.sort_by(& &1.name)
  end

  # TODO filter by hint here?
  defp get_metadata_module_funs(
         mod,
         include_builtin,
         %State.Env{} = env,
         %Metadata{} = metadata,
         cursor_position
       ) do
    cond do
      not Map.has_key?(metadata.mods_funs_to_positions, {mod, nil, nil}) ->
        []

      true ->
        # local macros are available after definition
        # local functions are hoisted
        for {{^mod, f, a}, %State.ModFunInfo{} = info} when is_atom(f) <-
              metadata.mods_funs_to_positions,
            a != nil,
            (mod == env.module and not include_builtin) or Introspection.is_pub(info.type),
            mod != env.module or State.ModFunInfo.get_category(info) != :macro or
              List.last(info.positions) < cursor_position,
            include_builtin || {f, a} not in @builtin_functions do
          behaviour_implementation =
            Metadata.get_module_behaviours(metadata, env, mod)
            |> Enum.find_value(fn behaviour ->
              if Introspection.is_callback(behaviour, f, a, metadata) do
                behaviour
              end
            end)

          {specs, docs, meta} =
            case behaviour_implementation do
              nil ->
                case metadata.specs[{mod, f, a}] do
                  nil ->
                    {"", info.doc, info.meta}

                  %State.SpecInfo{specs: specs} ->
                    {specs |> Enum.reverse() |> Enum.join("\n"), info.doc, info.meta}
                end

              behaviour ->
                meta = Map.merge(info.meta, %{implementing: behaviour})

                case metadata.specs[{behaviour, f, a}] do
                  %State.SpecInfo{} = spec_info ->
                    specs = spec_info.specs |> Enum.reverse()

                    {callback_doc, callback_meta} =
                      case metadata.mods_funs_to_positions[{behaviour, f, a}] do
                        nil ->
                          {spec_info.doc, spec_info.meta}

                        def_info ->
                          # in case of protocol implementation get doc and meta from def
                          {def_info.doc, def_info.meta}
                      end

                    spec =
                      specs |> Enum.reject(&String.starts_with?(&1, "@spec")) |> Enum.join("\n")

                    {spec, callback_doc, callback_meta |> Map.merge(meta)}

                  nil ->
                    Metadata.get_doc_spec_from_behaviour(
                      behaviour,
                      f,
                      a,
                      State.ModFunInfo.get_category(info)
                    )
                end
            end

          # assume function head is first in code and last in metadata
          head_params = Enum.at(info.params, -1)
          args = head_params |> Enum.map(&Macro.to_string/1)
          default_args = Introspection.count_defaults(head_params)

          # TODO this is useless - we duplicate and then deduplicate
          for arity <- (a - default_args)..a do
            {f, arity, a, info.type, {docs, meta}, specs, args}
          end
        end
        |> Enum.concat()
    end
  end

  # TODO filter by hint here?
  def get_module_funs(mod, include_builtin) do
    docs = NormalizedCode.get_docs(mod, :docs)
    module_specs = TypeInfo.get_module_specs(mod)

    callback_specs =
      for behaviour <- Behaviours.get_module_behaviours(mod),
          {fa, spec} <- TypeInfo.get_module_callbacks(behaviour),
          into: %{},
          do: {fa, {behaviour, spec}}

    if docs != nil and function_exported?(mod, :__info__, 1) do
      exports = mod.__info__(:macros) ++ mod.__info__(:functions) ++ special_builtins(mod)
      # TODO this is useless - we should only return max arity variant
      default_arg_functions = default_arg_functions(docs)

      for {f, a} <- exports do
        {f, new_arity} =
          case default_arg_functions[{f, a}] do
            nil -> {f, a}
            new_arity -> {f, new_arity}
          end

        {func_kind, func_doc} = find_doc({f, new_arity}, docs)
        func_kind = func_kind || :function

        doc =
          case func_doc do
            nil ->
              app = ElixirSense.Core.Applications.get_application(mod)
              # TODO provide docs for builtin
              if f in [:behaviour_info | @builtin_functions] do
                {"", %{builtin: true, app: app}}
              else
                {"", %{app: app}}
              end

            {{_fun, _}, _line, _kind, _args, doc, metadata} ->
              {doc, metadata}
          end

        spec_key =
          case func_kind do
            :macro -> {:"MACRO-#{f}", new_arity + 1}
            :function -> {f, new_arity}
          end

        {_behaviour, fun_spec, spec_kind} =
          case callback_specs[spec_key] do
            nil ->
              {nil, module_specs[spec_key], :spec}

            {behaviour, fun_spec} ->
              {behaviour, fun_spec, if(func_kind == :macro, do: :macrocallback, else: :callback)}
          end

        spec = Introspection.spec_to_string(fun_spec, spec_kind)

        fun_args = Introspection.extract_fun_args(func_doc)

        # TODO check if this is still needed on 1.13+
        # as of Elixir 1.12 some functions/macros, e.g. Kernel.SpecialForms.fn
        # have broken specs in docs
        # in that case we fill a dummy fun_args
        fun_args =
          if length(fun_args) != new_arity do
            format_params(nil, new_arity)
          else
            fun_args
          end

        {f, a, new_arity, func_kind, doc, spec, fun_args}
      end
      |> Kernel.++(
        for {f, a} <- @builtin_functions,
            include_builtin,
            do: {f, a, a, :function, {"", %{}}, nil, nil}
      )
    else
      funs =
        if Code.ensure_loaded?(mod) do
          mod.module_info(:exports)
          |> Kernel.--(if include_builtin, do: [], else: @builtin_functions)
          |> Kernel.++(BuiltinFunctions.erlang_builtin_functions(mod))
        else
          []
        end

      for {f, a} <- funs do
        # we don't expect macros here
        {behaviour, fun_spec} =
          case callback_specs[{f, a}] do
            nil -> {nil, module_specs[{f, a}]}
            callback -> callback
          end

        # we load typespec anyway, no big win reading erlang spec from meta[:signature]

        doc_result =
          if docs != nil do
            {_kind, func_doc} = find_doc({f, a}, docs)

            case func_doc do
              nil ->
                if behaviour do
                  {"", %{implementing: behaviour}}
                else
                  {"", %{}}
                end

              {{_fun, _}, _line, _kind, _args, doc, metadata} ->
                {doc, metadata}
            end
          else
            if behaviour do
              {"", %{implementing: behaviour}}
            else
              {"", %{}}
            end
          end

        params = format_params(fun_spec, a)
        spec = Introspection.spec_to_string(fun_spec, if(behaviour, do: :callback, else: :spec))

        {f, a, a, :function, doc_result, spec, params}
      end
    end
  end

  defp format_params({{_name, _arity}, [params | _]}, _arity_1) do
    TypeInfo.extract_params(params)
  end

  defp format_params(nil, 0), do: []

  defp format_params(nil, arity) do
    for _ <- 1..arity, do: "term"
  end

  defp special_builtins(mod) do
    if Code.ensure_loaded?(mod) do
      mod.module_info(:exports)
      |> Enum.filter(fn {f, a} ->
        {f, a} in [{:behaviour_info, 1}]
      end)
    else
      []
    end
  end

  defp find_doc(fun, _docs) when fun in @builtin_functions, do: {:function, nil}

  defp find_doc(fun, docs) do
    doc =
      docs
      |> Enum.find(&match?({^fun, _, _, _, _, _}, &1))

    case doc do
      nil -> {nil, nil}
      {_, _, func_kind, _, _, _} = d -> {func_kind, d}
    end
  end

  defp default_arg_functions(docs) do
    for {{fun_name, arity}, _, _kind, args, _, _} <- docs,
        count = Introspection.count_defaults(args),
        count > 0,
        new_arity <- (arity - count)..(arity - 1),
        into: %{},
        do: {{fun_name, new_arity}, arity}
  end

  defp ensure_loaded(Elixir), do: {:error, :nofile}
  defp ensure_loaded(mod), do: Code.ensure_compiled(mod)

  defp match_map_fields(fields, hint, type, %State.Env{} = _env, %Metadata{} = metadata) do
    {subtype, origin, types} =
      case type do
        {:struct, {:atom, mod}} ->
          types =
            ElixirLS.Utils.Field.get_field_types(
              metadata,
              mod,
              true
            )

          {:struct_field, inspect(mod), types}

        {:struct, nil} ->
          {:struct_field, nil, %{}}

        :map ->
          {:map_key, nil, %{}}

        other ->
          raise "unexpected #{inspect(other)} for hint #{inspect(hint)}"
      end

    for {key, value} when is_atom(key) <- fields,
        key_str = Atom.to_string(key),
        not Regex.match?(~r/^[A-Z]/u, key_str),
        Matcher.match?(key_str, hint) do
      value_is_map =
        case value do
          {:map, _, _} -> true
          {:struct, _, _, _} -> true
          _ -> false
        end

      %{
        kind: :field,
        name: key_str,
        subtype: subtype,
        value_is_map: value_is_map,
        origin: origin,
        call?: true,
        # TODO make it use the same code
        type_spec: if(types[key], do: Introspection.to_string_with_parens(types[key]))
      }
    end
    |> Enum.sort_by(& &1.name)
  end

  ## Ad-hoc conversions
  @spec to_entries(map) :: [t()]

  defp to_entries(%{type: :bitstring_option} = option) do
    [option]
  end
  defp to_entries(%{
         kind: :field,
         subtype: subtype,
         name: name,
         origin: origin,
         call?: call?,
         type_spec: type_spec
       }) do
    [
      %{
        type: :field,
        name: name,
        subtype: subtype,
        origin: origin,
        call?: call?,
        type_spec: type_spec
      }
    ]
  end

  defp to_entries(
         %{
           kind: :module,
           name: name,
           full_name: full_name,
           desc: {desc, metadata},
           subtype: subtype
         } = map
       ) do
    [
      %{
        type: :module,
        name: name,
        full_name: full_name,
        required_alias: if(map[:required_alias], do: inspect(map[:required_alias])),
        subtype: subtype,
        summary: desc,
        metadata: metadata
      }
    ]
  end

  defp to_entries(%{kind: :variable, name: name}) do
    [%{type: :variable, name: name}]
  end

  defp to_entries(%{kind: :attribute, name: name, summary: summary}) do
    [%{type: :attribute, name: "@" <> name, summary: summary}]
  end

  defp to_entries(%{
         kind: :function,
         name: name,
         arities: arities,
         def_arities: def_arities,
         needed_imports: needed_imports,
         needed_requires: needed_requires,
         module: mod,
         func_kinds: func_kinds,
         docs: docs,
         specs: specs,
         args: args
       }) do
    for e <-
          Enum.zip([
            arities,
            docs,
            specs,
            args,
            def_arities,
            func_kinds,
            needed_imports,
            needed_requires
          ]),
        {a, {doc, metadata}, spec, args, def_arity, func_kind, needed_import, needed_require} = e do
      kind =
        case func_kind do
          k when k in [:macro, :defmacro, :defmacrop, :defguard, :defguardp] -> :macro
          _ -> :function
        end

      visibility =
        if func_kind in [:defp, :defmacrop, :defguardp] do
          :private
        else
          :public
        end

      mod_name = inspect(mod)

      fa = {name |> String.to_atom(), a}

      if fa in (BuiltinFunctions.all() -- [exception: 1, message: 1]) do
        args = BuiltinFunctions.get_args(fa)
        docs = BuiltinFunctions.get_docs(fa)

        %{
          type: kind,
          visibility: visibility,
          name: name,
          arity: a,
          def_arity: def_arity,
          args: args |> Enum.join(", "),
          args_list: args,
          needed_require: nil,
          needed_import: nil,
          origin: mod_name,
          summary: Introspection.extract_summary_from_docs(docs),
          metadata: %{builtin: true},
          spec: BuiltinFunctions.get_specs(fa) |> Enum.join("\n"),
          snippet: nil
        }
      else
        needed_import =
          case needed_import do
            nil -> nil
            {mod, {fun, arity}} -> {inspect(mod), {Atom.to_string(fun), arity}}
          end

        %{
          type: kind,
          visibility: visibility,
          name: name,
          arity: a,
          def_arity: def_arity,
          args: args |> Enum.join(", "),
          args_list: args,
          needed_require: if(needed_require, do: inspect(needed_require)),
          needed_import: needed_import,
          origin: mod_name,
          summary: doc,
          metadata: metadata,
          spec: spec || "",
          snippet: nil
        }
      end
    end
  end

  defp value_from_binding(
         binding_ast,
         %State.Env{} = env,
         %Metadata{} = metadata,
         cursor_position
       ) do
    case Binding.expand(
           Binding.from_env(env, metadata, cursor_position),
           binding_ast
         ) do
      :none -> :error
      nil -> :error
      other -> {:ok, other}
    end
  end
end
