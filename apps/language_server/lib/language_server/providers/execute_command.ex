defmodule ElixirLS.LanguageServer.Providers.ExecuteCommand do
  @moduledoc """
  Adds a @spec annotation to the document when the user clicks on a code lens.
  """

  alias ElixirLS.LanguageServer.{JsonRpc, SourceFile}
  import ElixirLS.LanguageServer.Protocol
  alias ElixirLS.LanguageServer.Server

  @default_target_line_length 98

  def execute("spec:" <> _, args, state) do
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

    source_file = Server.get_source_file(state, uri)

    cur_text = source_file.text

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
          case SourceFile.formatter_opts(uri) do
            {:ok, opts} -> Keyword.get(opts, :line_length, @default_target_line_length)
            :error -> @default_target_line_length
          end

        target_line_length = target_line_length - String.length(indentation)

        Code.format_string!("@spec #{spec}", line_length: target_line_length)
        |> IO.iodata_to_binary()
        |> SourceFile.lines()
        |> Enum.map(&(indentation <> &1))
        |> Enum.join("\n")
        |> Kernel.<>("\n")
      rescue
        _ ->
          "#{indentation}@spec #{spec}\n"
      end

    edit_result =
      JsonRpc.send_request("workspace/applyEdit", %{
        "label" => "Add @spec to #{mod}.#{fun}/#{arity}",
        "edit" => %{
          "changes" => %{
            uri => [%{"range" => range(line - 1, 0, line - 1, 0), "newText" => formatted}]
          }
        }
      })

    case edit_result do
      {:ok, %{"applied" => true}} ->
        {:ok, nil}

      other ->
        {:error, :server_error,
         "cannot insert spec, workspace/applyEdit returned #{inspect(other)}"}
    end
  end

  def execute(_command, _args, _state) do
    {:error, :invalid_request, nil}
  end
end
