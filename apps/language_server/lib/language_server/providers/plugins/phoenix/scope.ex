defmodule ElixirLS.LanguageServer.Plugins.Phoenix.Scope do
  @moduledoc false

  alias ElixirSense.Core.Source
  alias ElixirSense.Core.Binding

  def within_scope(buffer, binding_env \\ %Binding{}) do
    with {:ok, ast} <- Code.Fragment.container_cursor_to_quoted(buffer),
         {true, scopes_ast} <- get_scopes(ast),
         scopes_ast = Enum.reverse(scopes_ast),
         scope_alias <- get_scope_alias(scopes_ast, binding_env) do
      {true, scope_alias}
    else
      _ -> {false, nil}
    end
  end

  defp get_scopes(ast) do
    path = Macro.path(ast, &match?({:__cursor__, _, _}, &1))

    scopes =
      path
      |> Enum.filter(&match?({:scope, _, _}, &1))
      |> Enum.map(fn {:scope, meta, params} ->
        params = Enum.reject(params, &match?([{:do, _} | _], &1))
        {:scope, meta, params}
      end)

    case scopes do
      [] -> {false, nil}
      scopes -> {true, scopes}
    end
  end

  # scope path: "/", alias: ExampleWeb do ... end
  defp get_scope_alias_from_ast_node({:scope, _, [scope_params]}, binding_env, module)
       when is_list(scope_params) do
    scope_alias = Keyword.get(scope_params, :alias)
    concat_module(scope_alias, binding_env, module)
  end

  # scope "/", alias: ExampleWeb do ... end
  defp get_scope_alias_from_ast_node(
         {:scope, _, [_scope_path, scope_params]},
         binding_env,
         module
       )
       when is_list(scope_params) do
    scope_alias = Keyword.get(scope_params, :alias)
    concat_module(scope_alias, binding_env, module)
  end

  defp get_scope_alias_from_ast_node(
         {:scope, _, [_scope_path, scope_alias]},
         binding_env,
         module
       ) do
    concat_module(scope_alias, binding_env, module)
  end

  # scope "/", ExampleWeb, host: "api." do ... end
  defp get_scope_alias_from_ast_node(
         {:scope, _, [_scope_path, scope_alias, scope_params]},
         binding_env,
         module
       )
       when is_list(scope_params) do
    concat_module(scope_alias, binding_env, module)
  end

  defp get_scope_alias_from_ast_node(
         _ast,
         _binding_env,
         module
       ),
       do: module

  # no alias - propagate parent
  defp concat_module(nil, _binding_env, module), do: module
  # alias: false resets all nested aliases
  defp concat_module(false, _binding_env, _module), do: nil

  defp concat_module(scope_alias, binding_env, module) do
    scope_alias = get_mod(scope_alias, binding_env)
    Module.concat([module, scope_alias])
  end

  defp get_scope_alias(scopes_ast, binding_env, module \\ nil)
  # recurse
  defp get_scope_alias([], _binding_env, module), do: module

  defp get_scope_alias([head | tail], binding_env, module) do
    scope_alias = get_scope_alias_from_ast_node(head, binding_env, module)
    get_scope_alias(tail, binding_env, scope_alias)
  end

  defp get_mod({:__aliases__, _, [scope_alias]}, binding_env) do
    get_mod(scope_alias, binding_env)
  end

  defp get_mod({name, _, nil}, binding_env) when is_atom(name) do
    case Binding.expand(binding_env, {:variable, name}) do
      {:atom, atom} ->
        atom

      _ ->
        nil
    end
  end

  defp get_mod(scope_alias, binding_env) do
    with {mod, _} <- Source.get_mod([scope_alias], binding_env) do
      mod
    end
  end
end
