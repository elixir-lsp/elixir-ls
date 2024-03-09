defmodule ElixirLS.LanguageServer.Providers.ExecuteCommand.ExpandMacro do
  @moduledoc """
  This module implements a custom command expanding an elixir macro.
  Returns a formatted source fragment.
  """

  alias ElixirLS.LanguageServer.Server
  alias ElixirSense.Core.Ast
  alias ElixirSense.Core.MacroExpander
  alias ElixirSense.Core.State
  alias ElixirSense.Core.Parser
  alias ElixirSense.Core.Metadata

  @behaviour ElixirLS.LanguageServer.Providers.ExecuteCommand

  @impl ElixirLS.LanguageServer.Providers.ExecuteCommand
  def execute([uri, text, line], state)
      when is_binary(text) and is_integer(line) do
    source_file = Server.get_source_file(state, uri)
    cur_text = source_file.text

    # TODO change/move this
    if String.trim(text) != "" do
      formatted =
        expand_full(cur_text, text, line + 1)
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

  def expand_full(buffer, code, line) do
    buffer_file_metadata = Parser.parse_string(buffer, true, true, {line, 1})

    env = Metadata.get_env(buffer_file_metadata, {line, 1})

    do_expand_full(code, env)
  end

  def do_expand_full(code, %State.Env{requires: requires, imports: imports, module: module}) do
    env =
      %Macro.Env{macros: __ENV__.macros}
      |> Ast.set_module_for_env(module)
      |> Ast.add_requires_to_env(requires)
      |> Ast.add_imports_to_env(imports)

    try do
      {:ok, expr} = code |> Code.string_to_quoted()

      # Elixir require some meta to expand ast
      expr = MacroExpander.add_default_meta(expr)

      %{
        expand_once: expr |> Macro.expand_once(env) |> Macro.to_string(),
        expand: expr |> Macro.expand(env) |> Macro.to_string(),
        expand_partial: expr |> Ast.expand_partial(env) |> Macro.to_string(),
        expand_all: expr |> Ast.expand_all(env) |> Macro.to_string()
      }
    rescue
      e ->
        message = inspect(e)

        %{
          expand_once: message,
          expand: message,
          expand_partial: message,
          expand_all: message
        }
    end
  end
end
