defmodule ElixirLS.LanguageServer.Providers.ExecuteCommand.ToPipe do
  @moduledoc """
  This module implements a custom command for converting function calls
  to pipe operators.

  Returns a formatted source fragment.
  """
  import ElixirLS.LanguageServer.Protocol

  alias ElixirLS.LanguageServer.{JsonRpc, Server, SourceFile}

  @behaviour ElixirLS.LanguageServer.Providers.ExecuteCommand

  @impl ElixirLS.LanguageServer.Providers.ExecuteCommand
  def execute(%{"uri" => uri, "cursor_line" => line, "cursor_column" => col}, state)
      when is_integer(line) and is_integer(col) and is_binary(uri) do
    # line and col are assumed to be 1-indexed
    source_file = Server.get_source_file(state, uri)

    {:ok, %{edited_text: edited_text, edit_range: edit_range}} =
      to_pipe_at_cursor(source_file, line, col)

    edit_result =
      JsonRpc.send_request("workspace/applyEdit", %{
        "label" => "Convert function call to pipe operator",
        "edit" => %{
          "changes" => %{
            uri => [%{"range" => edit_range, "newText" => edited_text}]
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

  def to_pipe_at_cursor(source_file, line, col) do
    result =
      ElixirSense.Core.Source.walk_text(
        source_file.text,
        %{walked_text: "", function_call: nil, range: nil},
        fn current_char, remaining_text, current_line, current_col, acc ->
          if current_line == line and current_col == col do
            tail = get_function_call_tail(remaining_text)
            {:ok, head} = get_function_call_head(acc.walked_text)

            {remaining_text,
             %{
               acc
               | walked_text: acc.walked_text <> current_char,
                 function_call: head <> current_char <> tail,
                 range: get_range(line, col, head, current_char, tail)
             }}
          else
            {remaining_text, %{acc | walked_text: acc.walked_text <> current_char}}
          end
        end
      )

    case result do
      %{function_call: nil} ->
        {:error, :function_call_not_found}

      %{function_call: function_call, range: range} ->
        piped_text =
          function_call
          |> Code.string_to_quoted!()
          |> to_pipe()
          |> Macro.to_string()

        {:ok, %{edited_text: piped_text, edit_range: range}}
    end
  end

  defp get_range(line, col, head, current_char, tail) do
    start_line = line
    start_col = col - String.length(head)

    tail_lines = String.split(head <> current_char <> tail, "\n", trim: true)
    line_offset = length(tail_lines) - 1
    col_offset = tail_lines |> List.last() |> String.length()

    end_col = if line_offset == 0, do: start_col + col_offset, else: col_offset

    range(start_line, start_col, start_line + line_offset, end_col)
  end

  defp get_function_call_head(text) do
    middle_of_call_regex = ~r/((?:\S+\.)+(?:\S+\.?)?\()$/

    case Regex.scan(middle_of_call_regex, text, capture: :all_but_first) do
      [[head]] -> {:ok, head}
      _ -> {:error, :invalid_function_call_position}
    end
  end

  def get_function_call_tail(text) do
    text
    |> String.graphemes()
    |> Enum.reduce_while(%{paren_count: 0, text: ""}, fn
      c = "(", acc ->
        {:cont, %{acc | paren_count: acc.paren_count + 1, text: [acc.text | [c]]}}

      c = ")", acc ->
        acc = %{acc | paren_count: acc.paren_count - 1, text: [acc.text | [c]]}

        if acc.paren_count <= 0 do
          {:halt, acc}
        else
          {:cont, acc}
        end

      c, acc ->
        {:cont, %{acc | text: [acc.text | [c]]}}
    end)
    |> Map.get(:text)
    |> IO.iodata_to_binary()
  end

  defp to_pipe(code) do
    {piped_ast, _} = Macro.prewalk(code, %{has_piped: false}, &to_pipe/2)
    piped_ast
  end

  defp to_pipe({:|>, line, [left, right]}, %{has_piped: false} = acc) do
    {{:|>, line, [left |> to_pipe(acc) |> elem(0), right]}, Map.put(acc, :has_piped, true)}
  end

  defp to_pipe(
         {{:., line, [{_, _, nil}]} = anonymous_function_node, _meta, [h | t]},
         %{has_piped: false} = acc
       ) do
    {{:|>, line, [h, {anonymous_function_node, line, t}]}, Map.put(acc, :has_piped, true)}
  end

  defp to_pipe({{:., line, _args} = function, _meta, [h | t]}, %{has_piped: false} = acc)
       when t != [] do
    {{:|>, line, [h, {function, line, t}]}, Map.put(acc, :has_piped, true)}
  end

  defp to_pipe({function, line, [h | t]}, %{has_piped: false} = acc)
       when is_atom(function) and t != [] do
    {{:|>, line, [h, {function, line, t}]}, Map.put(acc, :has_piped, true)}
  end

  defp to_pipe(node, acc) do
    {node, acc}
  end
end
