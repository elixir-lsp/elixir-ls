defmodule ElixirLS.LanguageServer.Providers.ExecuteCommand.ExpandMacro do
  @moduledoc """
  This module implements a custom command expanding an elixir macro.
  Returns a formatted source fragment.
  """

  alias ElixirLS.LanguageServer.Server
  alias ElixirSense.Core.State
  alias ElixirSense.Core.Parser
  alias ElixirSense.Core.Metadata
  alias ElixirSense.Core.Compiler
  alias ElixirLS.LanguageServer.SourceFile

  @behaviour ElixirLS.LanguageServer.Providers.ExecuteCommand

  @impl ElixirLS.LanguageServer.Providers.ExecuteCommand
  def execute([uri, text, line], state)
      when is_binary(text) and is_integer(line) do
    source_file = Server.get_source_file(state, uri)
    path = get_path(uri)
    cur_text = source_file.text

    # TODO change/move this
    if String.trim(text) != "" do
      formatted =
        expand_full(cur_text, text, path, line + 1)
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
         "expandOnce" => "\n"
       }}
    end
  end

  def expand_full(buffer, code, file, line) do
    buffer_file_metadata = Parser.parse_string(buffer, true, false, {line, 1})
    env = Metadata.get_cursor_env(buffer_file_metadata, {line, 1})

    do_expand_full(code, env, file, line)
  end

  def do_expand_full(code, %State.Env{} = env, file, line) do
    env = State.Env.to_macro_env(env, file, line)

    try do
      expr = code |> Code.string_to_quoted!()

      {ast, _state, _env} = Compiler.expand(expr, %State{}, env)

      %{
        expand_once: expr |> Macro.expand_once(env) |> Macro.to_string(),
        expand: expr |> Macro.expand(env) |> Macro.to_string(),
        expand_all: ast |> Macro.to_string()
      }
    rescue
      e ->
        message = inspect(e)

        %{
          expand_once: message,
          expand: message,
          expand_all: message
        }
    end
  end

  defp get_path(uri) do
    case uri do
      "file:" <> _ ->
        SourceFile.Path.from_uri(uri)

      _ ->
        "nofile"
    end
  end
end
