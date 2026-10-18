defmodule ElixirLS.LanguageServer.Test.LegacyFormatPlugin do
  @moduledoc false
  # Emits a function suggestion in the shape of older third party plugins
  # (no default_args key). Only reacts to the hint `legacy_plugin_fun`.
  @behaviour ElixirLS.LanguageServer.Plugin

  @impl true
  def reduce("legacy_plugin_fun", _env, _buffer_metadata, _cursor_context, acc) do
    suggestion = %{
      type: :function,
      name: "legacy_plugin_fun",
      arity: 1,
      def_arity: 1,
      args: "value",
      args_list: ["value"],
      origin: "Legacy.Plugin.Builtins",
      spec: "@spec legacy_plugin_fun(value :: atom()) :: atom()",
      metadata: %{},
      snippet: nil,
      summary: "A legacy plugin function",
      needed_import: nil,
      needed_require: nil,
      visibility: :public
    }

    {:cont, %{acc | result: acc.result ++ [suggestion]}}
  end

  def reduce(_hint, _env, _buffer_metadata, _cursor_context, acc), do: {:cont, acc}
end
