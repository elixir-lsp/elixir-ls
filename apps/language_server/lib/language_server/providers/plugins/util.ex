defmodule ElixirLS.LanguageServer.Plugins.Util do
  @moduledoc false

  alias ElixirSense.Core.Binding
  alias ElixirSense.Core.Introspection
  alias ElixirSense.Core.Metadata
  alias ElixirSense.Core.Source
  alias ElixirSense.Core.State
  alias ElixirLS.Utils.Matcher

  def match_module?(mod_str, hint) do
    hint = String.downcase(hint)
    mod_full = String.downcase(mod_str)
    mod_last = mod_full |> String.split(".") |> List.last()
    Enum.any?([mod_last, mod_full], &Matcher.match?(&1, hint))
  end

  def trim_leading_for_insertion(hint, value) do
    [_, hint_prefix] = Regex.run(~r/(.*?)[\w0-9\._!\?\->]*$/u, hint)
    insert_text = String.replace_prefix(value, hint_prefix, "")

    case String.split(hint, ".") do
      [] ->
        insert_text

      hint_parts ->
        parts = String.split(insert_text, ".")
        {_, insert_parts} = Enum.split(parts, length(hint_parts) - 1)
        Enum.join(insert_parts, ".")
    end
  end

  # TODO this is vscode specific. Remove?
  def command(:trigger_suggest) do
    %{
      "title" => "Trigger Parameter Hint",
      "command" => "editor.action.triggerSuggest"
    }
  end

  def actual_mod_fun({mod, fun}, elixir_prefix, env, buffer_metadata, cursor_position) do
    %Metadata{mods_funs_to_positions: mods_funs, types: metadata_types} = buffer_metadata

    Introspection.actual_mod_fun(
      {mod, fun},
      env,
      mods_funs,
      metadata_types,
      cursor_position,
      not elixir_prefix
    )
  end

  def partial_func_call(code, %State.Env{} = env, %Metadata{} = buffer_metadata, cursor_position) do
    binding_env = Binding.from_env(env, buffer_metadata, cursor_position)

    func_info = Source.which_func(code, binding_env)

    with %{candidate: {mod, fun}, npar: npar} <- func_info,
         mod_fun <-
           actual_mod_fun(
             {mod, fun},
             func_info.elixir_prefix,
             env,
             buffer_metadata,
             cursor_position
           ),
         {actual_mod, actual_fun, _, _} <- mod_fun do
      {actual_mod, actual_fun, npar, func_info}
    else
      _ ->
        :none
    end
  end

  def func_call_chain(code, env, buffer_metadata, cursor_position) do
    func_call_chain(code, env, buffer_metadata, cursor_position, [])
  end

  # TODO reimplement this on elixir 1.14 with
  # Code.Fragment.container_cursor_to_quoted and Macro.path
  defp func_call_chain(code, env, buffer_metadata, cursor_position, chain) do
    case partial_func_call(code, env, buffer_metadata, cursor_position) do
      :none ->
        Enum.reverse(chain)

      {_mod, _fun, _npar, %{pos: {{line, col}, _}}} = func_call ->
        code_before = Source.text_before(code, line, col)
        func_call_chain(code_before, env, buffer_metadata, cursor_position, [func_call | chain])
    end
  end
end
