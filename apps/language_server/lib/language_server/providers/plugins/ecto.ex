defmodule ElixirLS.LanguageServer.Plugins.Ecto do
  @moduledoc false

  alias ElixirLS.LanguageServer.Plugins.ModuleStore
  alias ElixirSense.Core.Source
  alias ElixirLS.LanguageServer.Plugins.Ecto.Query
  alias ElixirLS.LanguageServer.Plugins.Ecto.Schema
  alias ElixirLS.LanguageServer.Plugins.Ecto.Types
  require Logger

  @behaviour ElixirLS.LanguageServer.Plugin
  use ElixirLS.LanguageServer.Providers.Completion.GenericReducer

  @schema_funcs [:field, :belongs_to, :has_one, :has_many, :many_to_many]

  @impl true
  def setup(context) do
    ModuleStore.ensure_compiled(context, Ecto.UUID)
  end

  @impl true
  def suggestions(hint, {Ecto.Migration, :add, 1, _info}, _chain, opts) do
    builtin_types = Types.find_builtin_types(hint, opts.cursor_context)
    builtin_types = Enum.reject(builtin_types, &String.starts_with?(&1.label, "{"))

    {:override, builtin_types}
  end

  def suggestions(hint, {Ecto.Schema, :field, 1, _info}, _chain, opts) do
    builtin_types = Types.find_builtin_types(hint, opts.cursor_context)
    custom_types = Types.find_custom_types(hint, opts.module_store)

    {:override, builtin_types ++ custom_types}
  end

  def suggestions(hint, {Ecto.Schema, func, 1, _info}, _chain, opts)
      when func in @schema_funcs do
    {:override, Schema.find_schemas(hint, opts.module_store)}
  end

  def suggestions(hint, {Ecto.Schema, func, 2, %{option: option}}, _, _)
      when func in @schema_funcs and option != nil do
    {:override, Schema.find_option_values(hint, option, func)}
  end

  def suggestions(_hint, {Ecto.Schema, func, 2, %{cursor_at_option: false}}, _, _)
      when func in @schema_funcs do
    :ignore
  end

  def suggestions(hint, {Ecto.Schema, func, 2, _info}, _, _)
      when func in @schema_funcs do
    {:override, Schema.find_options(hint, func)}
  end

  def suggestions(hint, {Ecto.Query, :from, 0, _info}, _, opts) do
    text_before = opts.cursor_context.text_before

    if after_in?(hint, text_before) do
      {:add, Schema.find_schemas(hint, opts.module_store)}
    else
      :ignore
    end
  end

  def suggestions(
        hint,
        _,
        [{nil, :assoc, 1, assoc_info} | rest],
        opts
      ) do
    text_before = opts.cursor_context.text_before
    env = opts.env
    meta = opts.buffer_metadata

    with %{pos: {{line, col}, _}} <- assoc_info,
         from_info when not is_nil(from_info) <-
           Enum.find_value(rest, fn
             {Ecto.Query, :from, 1, from_info} -> from_info
             _ -> nil
           end),
         assoc_code <- Source.text_after(text_before, line, col),
         [_, var] <-
           Regex.run(~r/^assoc\(\s*([_\p{Ll}\p{Lo}][\p{L}\p{N}_]*[?!]?)\s*,/u, assoc_code),
         %{^var => %{type: type}} <- Query.extract_bindings(text_before, from_info, env, meta),
         true <- function_exported?(type, :__schema__, 1) do
      {:override, Query.find_assoc_suggestions(type, hint)}
    else
      _ ->
        :ignore
    end
  end

  def suggestions(hint, _func_call, chain, opts) do
    case Enum.find(chain, &match?({Ecto.Query, :from, 1, _}, &1)) do
      {_, _, _, %{cursor_at_option: false} = info} ->
        text_before = opts.cursor_context.text_before
        env = opts.env
        buffer_metadata = opts.buffer_metadata

        schemas =
          if after_in?(hint, text_before),
            do: Schema.find_schemas(hint, opts.module_store),
            else: []

        bindings = Query.extract_bindings(text_before, info, env, buffer_metadata)
        {:add, schemas ++ Query.bindings_suggestions(hint, bindings)}

      {_, _, _, _} ->
        {:override, Query.find_options(hint)}

      _ ->
        :ignore
    end
  end

  # Adds customized snippet for `Ecto.Schema.schema/2`
  @impl true
  def decorate(%{origin: "Ecto.Schema", name: "schema", arity: 2} = item) do
    snippet = """
    schema "$1" do
      $0
    end
    """

    Map.put(item, :snippet, snippet)
  end

  # Fallback
  def decorate(item) do
    item
  end

  defp after_in?(hint, text_before) do
    try do
      Regex.match?(~r/\s+in\s+#{Regex.escape(hint)}$/u, text_before)
    rescue
      e in ErlangError ->
        # Generating regex from client code is generally unsafe. One way it can fail is
        # (ErlangError) Erlang error: :internal_error
        # unexpected response code from PCRE engine

        Logger.warning(
          "Unable to determine if cursor is after `in` in #{inspect(hint)}: #{Exception.format(:error, e, __STACKTRACE__)}"
        )

        false
    end
  end
end
