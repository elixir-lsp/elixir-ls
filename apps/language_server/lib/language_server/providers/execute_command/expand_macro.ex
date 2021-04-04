defmodule ElixirLS.LanguageServer.Providers.ExecuteCommand.ExpandMacro do
  @moduledoc """
  This module implements a custom command expanding an elixir macro.
  Returns a formatted source fragment.
  """

  alias ElixirLS.LanguageServer.Server

  @behaviour ElixirLS.LanguageServer.Providers.ExecuteCommand

  @impl ElixirLS.LanguageServer.Providers.ExecuteCommand
  def execute([uri, text, line], state)
      when is_binary(text) and is_integer(line) do
    source_file = Server.get_source_file(state, uri)
    cur_text = source_file.text

    if String.trim(text) != "" do
      formatted =
        ElixirSense.expand_full(cur_text, text, line + 1)
        |> Map.new(fn {key, value} ->
          key =
            key
            |> Atom.to_string()
            |> Macro.camelize()
            |> String.replace("Expand", "expand")

          formatted = value |> Code.format_string!() |> List.to_string()
          {key, formatted <> "\n"}
        end)

      {:ok, formatted}
    else
      # special case to avoid
      # warning: invalid expression (). If you want to invoke or define a function, make sure there are
      # no spaces between the function name and its arguments. If you wanted to pass an empty block or code,
      # pass a value instead, such as a nil or an atom
      # nofile:1
      {:ok,
       %{
         "expand" => "\n",
         "expandAll" => "\n",
         "expandOnce" => "\n",
         "expandPartial" => "\n"
       }}
    end
  end
end
