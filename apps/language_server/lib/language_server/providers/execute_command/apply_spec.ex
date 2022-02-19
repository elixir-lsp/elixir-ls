defmodule ElixirLS.LanguageServer.Providers.ExecuteCommand.ApplySpec do
  @moduledoc """
  This module implements a custom command inserting dialyzer suggested function spec.
  Generates source file edit as a result.
  """

  alias ElixirLS.LanguageServer.{JsonRpc, SourceFile}
  import ElixirLS.LanguageServer.Protocol
  alias ElixirLS.LanguageServer.Server

  @behaviour ElixirLS.LanguageServer.Providers.ExecuteCommand

  @default_target_line_length 98

  @impl ElixirLS.LanguageServer.Providers.ExecuteCommand
  def execute(args, state) do
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
        |> Enum.map_join("\n", &(indentation <> &1))
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
            # we don't care about utf16 positions here as we send 0
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
end
