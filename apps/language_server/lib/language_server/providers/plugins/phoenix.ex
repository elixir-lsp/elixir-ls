defmodule ElixirLS.LanguageServer.Plugins.Phoenix do
  @moduledoc false

  @behaviour ElixirLS.LanguageServer.Plugin

  use ElixirLS.LanguageServer.Providers.Completion.GenericReducer

  alias ElixirSense.Core.Source
  alias ElixirSense.Core.Binding
  alias ElixirSense.Core.Introspection
  alias ElixirLS.LanguageServer.Plugins.ModuleStore
  alias ElixirLS.LanguageServer.Plugins.Phoenix.Scope
  alias ElixirLS.LanguageServer.Plugins.Util
  alias ElixirLS.Utils.Matcher

  @phoenix_route_funcs ~w(
    get put patch trace
    delete head options
    forward connect post
  )a

  @impl true
  def setup(context) do
    ModuleStore.ensure_compiled(context, Phoenix.Router)
  end

  if Version.match?(System.version(), ">= 1.14.0-dev") do
    @impl true
    def suggestions(hint, {Phoenix.Router, func, 1, _info}, _list, opts)
        when func in @phoenix_route_funcs do
      binding = Binding.from_env(opts.env, opts.buffer_metadata)
      {_, scope_alias} = Scope.within_scope(opts.cursor_context.text_before, binding)

      case find_controllers(opts.module_store, opts.env, hint, scope_alias) do
        [] -> :ignore
        controllers -> {:override, controllers}
      end
    end

    def suggestions(
          hint,
          {Phoenix.Router, func, 2, %{params: [_path, module]}},
          _list,
          opts
        )
        when func in @phoenix_route_funcs do
      binding_env = Binding.from_env(opts.env, opts.buffer_metadata)
      {_, scope_alias} = Scope.within_scope(opts.cursor_context.text_before)
      {module, _} = Source.get_mod([module], binding_env)

      module = Module.concat(scope_alias, module)

      suggestions =
        for {export, {2, :function}} when export not in ~w(action call)a <-
              Introspection.get_exports(module),
            name = inspect(export),
            Matcher.match?(name, hint) do
          %{
            type: :generic,
            kind: :function,
            label: name,
            insert_text: Util.trim_leading_for_insertion(hint, name),
            detail: "Phoenix action"
          }
        end

      {:override, suggestions}
    end
  end

  @impl true
  def suggestions(_hint, _func_call, _list, _opts) do
    :ignore
  end

  defp find_controllers(module_store, env, hint, scope_alias) do
    [prefix | _] =
      env.module
      |> inspect()
      |> String.split(".")

    for module <- module_store.list,
        mod_str = inspect(module),
        Util.match_module?(mod_str, prefix),
        mod_str =~ "Controller",
        Util.match_module?(mod_str, hint) do
      {doc, _} = Introspection.get_module_docs_summary(module)

      %{
        type: :generic,
        kind: :class,
        label: mod_str,
        insert_text: skip_scope_alias(scope_alias, mod_str),
        detail: "Phoenix controller",
        documentation: doc
      }
    end
    |> Enum.sort_by(& &1.label)
  end

  defp skip_scope_alias(nil, insert_text), do: insert_text

  defp skip_scope_alias(scope_alias, insert_text),
    do: String.replace_prefix(insert_text, "#{inspect(scope_alias)}.", "")
end
