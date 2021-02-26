defmodule ElixirLS.LanguageServer.Providers.ExecuteCommand.ExpandMacro do
  @moduledoc """
  This module implements a custom command expanding an elixir macro.
  Returns a formatted source fragment.
  """

  alias ElixirLS.LanguageServer.Server

  @behaviour ElixirLS.LanguageServer.Providers.ExecuteCommand

  @impl ElixirLS.LanguageServer.Providers.ExecuteCommand
  def execute("expandMacro", [uri, text, line], state)
      when is_binary(text) and is_integer(line) do
    source_file = Server.get_source_file(state, uri)
    cur_text = source_file.text

    result = ElixirSense.expand_full(cur_text, text, line + 1)

    formatted =
      for {key, value} <- result,
          into: %{},
          do:
            (
              key =
                key
                |> Atom.to_string()
                |> Macro.camelize()
                |> String.replace("Expand", "expand")

              {key, value |> Code.format_string!() |> List.to_string()}
            )

    {:ok, formatted}
  end
end
