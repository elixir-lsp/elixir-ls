defmodule ElixirLS.LanguageServer.Providers.ExecuteCommand.ManipulatePipes do
  @moduledoc """
  This module implements a custom command for converting function calls
  to pipe operators and pipes to function calls.

  Returns a formatted source fragment.
  """
  import ElixirLS.LanguageServer.Protocol

  alias ElixirLS.LanguageServer.{JsonRpc, Server}

  alias __MODULE__.AST

  @behaviour ElixirLS.LanguageServer.Providers.ExecuteCommand

  @impl ElixirLS.LanguageServer.Providers.ExecuteCommand
  def execute(
        %{"uri" => uri, "cursor_line" => line, "cursor_column" => col, "operation" => operation},
        state
      )
      when is_integer(line) and is_integer(col) and is_binary(uri) and
             operation in ["to_pipe", "from_pipe"] do
    # line and col are assumed to be 1-indexed
    source_file = Server.get_source_file(state, uri)

    {:ok, %{edited_text: edited_text, edit_range: edit_range}} =
      case operation do
        "to_pipe" ->
          to_pipe_at_cursor(source_file, line, col)

        "from_pipe" ->
          from_pipe_at_cursor(source_file, line, col)
      end

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

  defp to_pipe_at_cursor(source_file, line, col) do
    result =
      ElixirSense.Core.Source.walk_text(
        source_file.text,
        %{walked_text: "", function_call: nil, range: nil},
        fn current_char, remaining_text, current_line, current_col, acc ->
          if current_line == line and current_col == col do
            {:ok, function_call, call_range} =
              get_function_call(line, col, acc.walked_text, current_char, remaining_text)

            {remaining_text,
             %{
               acc
               | walked_text: acc.walked_text <> current_char,
                 function_call: function_call,
                 range: call_range
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
          |> AST.to_pipe()
          |> Macro.to_string()

        {:ok, %{edited_text: piped_text, edit_range: range}}
    end
  end

  defp from_pipe_at_cursor(source_file, line, col) do
    result =
      ElixirSense.Core.Source.walk_text(
        source_file.text,
        %{walked_text: "", pipe_call: nil, range: nil},
        fn current_char, remaining_text, current_line, current_col, acc ->
          if current_line == line and current_col == col do
            {:ok, pipe_call, call_range} =
              get_pipe_call(line, col, acc.walked_text, current_char, remaining_text)

            {remaining_text,
             %{
               acc
               | walked_text: acc.walked_text <> current_char,
                 pipe_call: pipe_call,
                 range: call_range
             }}
          else
            {remaining_text, %{acc | walked_text: acc.walked_text <> current_char}}
          end
        end
      )

    case result do
      %{pipe_call: nil} ->
        {:error, :pipe_not_found}

      %{pipe_call: pipe_call, range: range} ->
        unpiped_text = AST.from_pipe(pipe_call)

        {:ok, %{edited_text: unpiped_text, edit_range: range}}
    end
  end

  defp get_function_call(line, col, head, current, original_tail) do
    tail = do_get_function_call(original_tail, "(", ")")

    {end_line, end_col} =
      if String.contains?(tail, "\n") do
        tail_list = String.split(tail, "\n")
        end_line = line + length(tail_list) - 1
        end_col = tail_list |> Enum.at(-1) |> String.length()
        {end_line, end_col}
      else
        {line, col + String.length(tail)}
      end

    text = head <> current <> tail

    function_call_args =
      String.reverse(text)
      |> do_get_function_call(")", "(")
      |> String.reverse()

    text_without_call = String.trim_trailing(text, function_call_args)

    case Regex.scan(~r/((?:\S+\.)*(?:\S+\.?))$/, text_without_call, capture: :all_but_first) do
      [[call_name]] ->
        call = call_name <> function_call_args

        {head, _tail} = String.split_at(call, -String.length(tail))
        col = col - String.length(head) + 1

        {:ok, call, range(line, col, end_line, end_col)}

      _ ->
        {:error, :not_a_function_call}
    end
  end

  defp do_get_function_call(text, start_char, end_char) do
    text
    |> String.graphemes()
    |> Enum.reduce_while(%{paren_count: 0, text: ""}, fn
      c = ^start_char, acc ->
        {:cont, %{acc | paren_count: acc.paren_count + 1, text: [acc.text | [c]]}}

      c = ^end_char, acc ->
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

  defp get_pipe_call(line, col, head, current, tail) do
    pipe_right = do_get_function_call(tail, "(", ")") |> IO.inspect()

    pipe_left_without_function_name =
      head
      |> String.reverse()
      |> do_get_function_call(")", "(")
      |> String.reverse()
      |> IO.inspect()

    function_name =
      head
      |> String.trim_trailing(pipe_left_without_function_name)
      |> get_function_name_from_tail()
      |> IO.inspect()

    pipe_left = function_name <> pipe_left_without_function_name
    pipe_call = pipe_left <> current <> pipe_right

    {line_offset, tail_length} = pipe_left |> String.reverse() |> count_newlines_and_get_tail()

    start_line = line - line_offset

    start_col =
      if line_offset != 0 do
        head
        |> String.trim_trailing(pipe_left)
        |> String.split("\n")
        |> Enum.at(-1, "")
        |> String.length()
      else
        col - tail_length
      end

    {line_offset, tail_length} = (current <> pipe_right) |> count_newlines_and_get_tail()

    end_line = line + line_offset

    end_col =
      if line_offset != 0 do
        tail_length
      else
        col + tail_length - 1
      end

    {:ok, pipe_call, range(start_line, start_col, end_line, end_col)}
  end

  defp get_function_name_from_tail(s) do
    s
    |> String.reverse()
    |> String.graphemes()
    |> Enum.reduce_while([], fn c, acc ->
      if String.match?(c, ~r/\s/) do
        {:halt, acc}
      else
        {:cont, [c | acc]}
      end
    end)
    |> IO.iodata_to_binary()
  end

  defp count_newlines_and_get_tail(s) do
    for <<c::binary-size(1) <- s>>, reduce: {0, 0} do
      {count, tail} ->
        if c == "\n" do
          {count + 1, 0}
        else
          {count, tail + 1}
        end
    end
  end
end
