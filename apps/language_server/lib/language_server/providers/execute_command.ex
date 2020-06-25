defmodule ElixirLS.LanguageServer.Providers.ExecuteCommand do
  @moduledoc """
  Adds a @spec annotation to the document when the user clicks on a code lens.
  """

  alias ElixirLS.LanguageServer.{JsonRpc, SourceFile}
  import ElixirLS.LanguageServer.Protocol

  def execute("spec:" <> _, args, source_files) do
    [
      %{
        "uri" => uri,
        "mod" => mod,
        "fun" => fun,
        "arity" => arity,
        "spec" => spec,
        "line" => line
      }
    ] = args

    mod = String.to_atom(mod)
    fun = String.to_atom(fun)

    cur_text = source_files[uri].text

    # In case line has changed since this suggestion was generated, look for the function's current
    # line number and fall back to the previous line number if we can't guess the new one
    line =
      if SourceFile.function_def_on_line?(cur_text, line, fun) do
        line
      else
        new_line = SourceFile.function_line(mod, fun, arity)

        if SourceFile.function_def_on_line?(cur_text, line, fun) do
          new_line
        else
          raise "Function definition has moved since suggestion was generated. " <>
                  "Try again after file has been recompiled."
        end
      end

    cur_line = Enum.at(SourceFile.lines(cur_text), line - 1)
    [indentation] = Regex.run(Regex.recompile!(~r/^\s*/), cur_line)

    # Attempt to format to fit within the preferred line length, fallback to having it all on one
    # line if anything fails
    formatted =
      try do
        target_line_length =
          uri
          |> SourceFile.formatter_opts()
          |> Keyword.get(:line_length, 98)

        target_line_length = target_line_length - String.length(indentation)

        Code.format_string!("@spec #{spec}", line_length: target_line_length)
        |> IO.iodata_to_binary()
        |> String.split(["\r\n", "\r", "\n"])
        |> Enum.map(&(indentation <> &1))
        |> Enum.join("\n")
        |> Kernel.<>("\n")
      rescue
        _ ->
          "#{indentation}@spec #{spec}\n"
      end

    JsonRpc.send_request("workspace/applyEdit", %{
      "label" => "Add @spec to #{mod}.#{fun}/#{arity}",
      "edit" => %{
        "changes" => %{
          uri => [%{"range" => range(line - 1, 0, line - 1, 0), "newText" => formatted}]
        }
      }
    })

    {:ok, nil}
  end
end
