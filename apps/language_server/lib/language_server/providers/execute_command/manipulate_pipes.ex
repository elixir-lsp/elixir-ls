defmodule ElixirLS.LanguageServer.Providers.ExecuteCommand.ManipulatePipes do
  @moduledoc """
  This module implements a custom command for converting function calls
  to pipe operators and pipes to function calls.

  Returns a formatted source fragment.
  """
  import ElixirLS.LanguageServer.Protocol

  alias ElixirLS.LanguageServer.{JsonRpc, Server}
  alias ElixirLS.LanguageServer.SourceFile
  alias ElixirLS.LanguageServer.Protocol.TextEdit

  alias __MODULE__.AST

  @behaviour ElixirLS.LanguageServer.Providers.ExecuteCommand

  @newlines ["\r\n", "\n", "\r"]

  @impl ElixirLS.LanguageServer.Providers.ExecuteCommand
  def execute([operation, uri, line, col], state)
      when is_integer(line) and is_integer(col) and is_binary(uri) and
             operation in ["toPipe", "fromPipe"] do
    # line and col are assumed to be 0-indexed
    source_file = Server.get_source_file(state, uri)

    label =
      case operation do
        "toPipe" -> "Convert function call to pipe operator"
        "fromPipe" -> "Convert pipe operator to function call"
      end

    processing_result =
      case operation do
        "toPipe" ->
          to_pipe_at_cursor(source_file.text, line, col)

        "fromPipe" ->
          from_pipe_at_cursor(source_file.text, line, col)
      end

    with {:ok, %TextEdit{} = text_edit} <- processing_result,
         {:ok, %{"applied" => true}} <-
           JsonRpc.send_request("workspace/applyEdit", %{
             "label" => label,
             "edit" => %{
               "changes" => %{
                 uri => [text_edit]
               }
             }
           }) do
      {:ok, nil}
    else
      {:error, reason} ->
        {:error, reason}

      error ->
        {:error, :server_error,
         "cannot execute pipe conversion, workspace/applyEdit returned #{inspect(error)}"}
    end
  end

  @doc false
  def to_pipe_at_cursor(text, line, col) do
    result =
      ElixirSense.Core.Source.walk_text(
        text,
        %{walked_text: "", function_call: nil, range: nil},
        fn current_char, remaining_text, current_line, current_col, acc ->
          if current_line - 1 == line and current_col - 1 == col do
            {:ok, function_call, call_range} =
              get_function_call(line, col, acc.walked_text, current_char, remaining_text)

            if function_call_includes_cursor(call_range, line, col) do
              {remaining_text,
               %{
                 acc
                 | walked_text: acc.walked_text <> current_char,
                   function_call: function_call,
                   range: call_range
               }}
            else
              # The cursor was not inside a function call so we cannot
              # manipulate the pipes
              {remaining_text,
               %{
                 acc
                 | walked_text: acc.walked_text <> current_char
               }}
            end
          else
            {remaining_text, %{acc | walked_text: acc.walked_text <> current_char}}
          end
        end
      )

    with {:result, %{function_call: function_call, range: range}}
         when not is_nil(function_call) and not is_nil(range) <- {:result, result},
         {:ok, piped_text} <- AST.to_pipe(function_call) do
      text_edit = %TextEdit{newText: piped_text, range: range}
      {:ok, text_edit}
    else
      {:result, %{function_call: nil}} ->
        {:error, :function_call_not_found}

      {:error, :invalid_code} ->
        {:error, :invalid_code}
    end
  end

  defp from_pipe_at_cursor(text, line, col) do
    result =
      ElixirSense.Core.Source.walk_text(
        text,
        %{walked_text: "", pipe_call: nil, range: nil},
        fn current_char, remaining_text, current_line, current_col, acc ->
          if current_line - 1 == line and current_col - 1 == col do
            case get_pipe_call(line, col, acc.walked_text, current_char, remaining_text) do
              {:ok, pipe_call, call_range} ->
                {remaining_text,
                 %{
                   acc
                   | walked_text: acc.walked_text <> current_char,
                     pipe_call: pipe_call,
                     range: call_range
                 }}

              {:error, :no_pipe_at_selection} ->
                {remaining_text,
                 %{
                   acc
                   | walked_text: acc.walked_text <> current_char
                 }}
            end
          else
            {remaining_text, %{acc | walked_text: acc.walked_text <> current_char}}
          end
        end
      )

    with {:result, %{pipe_call: pipe_call, range: range}}
         when not is_nil(pipe_call) and not is_nil(range) <- {:result, result},
         {:ok, unpiped_text} <- AST.from_pipe(pipe_call) do
      text_edit = %TextEdit{newText: unpiped_text, range: range}
      {:ok, text_edit}
    else
      {:result, %{pipe_call: nil}} ->
        {:error, :pipe_not_found}

      {:error, :invalid_code} ->
        {:error, :invalid_code}
    end
  end

  defp get_function_call(line, col, head, cur, original_tail) when cur in ["\n", "\r", "\r\n"] do
    {head, new_cur} = String.split_at(head, -1)
    get_function_call(line, col - 1, head, new_cur, cur <> original_tail)
  end

  defp get_function_call(line, col, head, ")", original_tail) do
    {head, cur} = String.split_at(head, -1)
    get_function_call(line, col - 1, head, cur, ")" <> original_tail)
  end

  defp get_function_call(line, col, head, current, original_tail) do
    tail = do_get_function_call(original_tail, "(", ")")

    {end_line, end_col} =
      if String.contains?(tail, @newlines) do
        tail_list = String.split(tail, @newlines)
        end_line = line + length(tail_list) - 1
        end_col = tail_list |> Enum.at(-1) |> String.length()
        {end_line, end_col}
      else
        {line, col + String.length(tail) + 1}
      end

    text = head <> current <> tail

    call = get_function_call_before(text)
    orig_head = head

    {head, _new_tail} =
      case String.length(tail) do
        0 -> {call, ""}
        length -> String.split_at(call, -length)
      end

    {line, col} = fix_start_of_range(orig_head, head, line, col)

    {:ok, call, range(line, col, end_line, end_col)}
  end

  defp do_get_function_call(text, start_char, end_char) do
    text
    |> do_get_function_call(start_char, end_char, %{paren_count: 0, text: ""})
    |> Map.get(:text)
    |> IO.iodata_to_binary()
  end

  defp do_get_function_call(<<c::binary-size(1), tail::bitstring>>, start_char, end_char, acc)
       when c == start_char do
    do_get_function_call(tail, start_char, end_char, %{
      acc
      | paren_count: acc.paren_count + 1,
        text: [acc.text | [c]]
    })
  end

  defp do_get_function_call(<<c::binary-size(1), tail::bitstring>>, start_char, end_char, acc)
       when c == end_char do
    acc = %{acc | paren_count: acc.paren_count - 1, text: [acc.text | [c]]}

    if acc.paren_count <= 0 do
      acc
    else
      do_get_function_call(tail, start_char, end_char, acc)
    end
  end

  defp do_get_function_call(<<c::binary-size(1), tail::bitstring>>, start_char, end_char, acc) do
    do_get_function_call(tail, start_char, end_char, %{acc | text: [acc.text | [c]]})
  end

  defp do_get_function_call(_, _, _, acc), do: acc

  defp get_pipe_call(line, col, head, current, tail) do
    pipe_right = do_get_function_call(tail, "(", ")")

    pipe_left =
      head
      |> String.reverse()
      |> :unicode.characters_to_binary(:utf8, :utf16)
      |> do_get_pipe_call()
      |> :unicode.characters_to_binary(:utf16, :utf8)

    pipe_left =
      if String.contains?(pipe_left, ")") do
        get_function_call_before(head)
      else
        pipe_left
      end

    pipe_left = String.trim_leading(pipe_left)

    pipe_call = pipe_left <> current <> pipe_right

    {line_offset, tail_length} =
      pipe_left
      |> String.reverse()
      |> count_newlines_and_get_tail()

    start_line = line - line_offset

    start_col =
      if line_offset != 0 do
        head
        |> String.trim_trailing(pipe_left)
        |> String.split(["\r\n", "\n", "\r"])
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
        col + tail_length
      end

    if String.contains?(pipe_call, "|>") do
      {:ok, pipe_call, range(start_line, start_col, end_line, end_col)}
    else
      {:error, :no_pipe_at_selection}
    end
  end

  # do_get_pipe_call(text :: utf16 binary, {utf16 binary, has_passed_through_whitespace, should_halt})
  defp do_get_pipe_call(text, acc \\ {"", false, false})

  defp do_get_pipe_call(_text, {acc, _, true}), do: acc
  defp do_get_pipe_call("", {acc, _, _}), do: acc

  defp do_get_pipe_call(<<?\r::utf16, ?\n::utf16, _::bitstring>>, {acc, true, _}),
    do: <<?\r::utf16, ?\n::utf16, acc::bitstring>>

  defp do_get_pipe_call(<<0, c::utf8, _::bitstring>>, {acc, true, _})
       when c in [?\t, ?\v, ?\r, ?\n, ?\s],
       do: <<c::utf16, acc::bitstring>>

  defp do_get_pipe_call(<<0, ?\r, 0, ?\n, text::bitstring>>, {acc, false, _}),
    do: do_get_pipe_call(text, {<<?\r::utf16, ?\n::utf16, acc::bitstring>>, false, false})

  defp do_get_pipe_call(<<0, c::utf8, text::bitstring>>, {acc, false, _})
       when c in [?\t, ?\v, ?\n, ?\s],
       do: do_get_pipe_call(text, {<<c::utf16, acc::bitstring>>, false, false})

  defp do_get_pipe_call(<<0, c::utf8, text::bitstring>>, {acc, _, _})
       when c in [?|, ?>],
       do: do_get_pipe_call(text, {<<c::utf16, acc::bitstring>>, false, false})

  defp do_get_pipe_call(<<c::utf16, text::bitstring>>, {acc, _, _}),
    do: do_get_pipe_call(text, {<<c::utf16, acc::bitstring>>, true, false})

  defp get_function_call_before(head) do
    call_without_function_name =
      head
      |> String.reverse()
      |> do_get_function_call(")", "(")
      |> String.reverse()

    if call_without_function_name == "" do
      head
    else
      function_name =
        head
        |> String.trim_trailing(call_without_function_name)
        |> get_function_name_from_tail()

      function_name <> call_without_function_name
    end
  end

  defp get_function_name_from_tail(s) do
    s
    |> String.reverse()
    |> String.graphemes()
    |> Enum.reduce_while([], fn c, acc ->
      if String.match?(c, ~r/[\s\(\[\{]/) do
        {:halt, acc}
      else
        {:cont, [c | acc]}
      end
    end)
    |> IO.iodata_to_binary()
  end

  defp count_newlines_and_get_tail(s, acc \\ {0, 0})

  defp count_newlines_and_get_tail("", acc), do: acc

  defp count_newlines_and_get_tail(s, {line_count, tail_length}) do
    case String.next_grapheme(s) do
      {g, tail} when g in ["\r\n", "\r", "\n"] ->
        count_newlines_and_get_tail(tail, {line_count + 1, 0})

      {_, tail} ->
        count_newlines_and_get_tail(tail, {line_count, tail_length + 1})
    end
  end

  # Fixes the line and column returned, finding the correct position on previous lines
  defp fix_start_of_range(orig_head, head, line, col)
  defp fix_start_of_range(_, "", line, col), do: {line, col + 2}

  defp fix_start_of_range(orig_head, head, line, col) do
    new_col = col - String.length(head) + 1

    if new_col < 0 do
      lines =
        SourceFile.lines(orig_head)
        |> Enum.take(line)
        |> Enum.reverse()

      # Go back through previous lines to find the correctly adjusted line and
      # column number for the start of head (where the function starts)
      Enum.reduce_while(lines, {line, new_col}, fn
        _line_text, {cur_line, cur_col} when cur_col >= 0 ->
          {:halt, {cur_line, cur_col}}

        line_text, {cur_line, cur_col} ->
          # The +1 is for the line separator
          {:cont, {cur_line - 1, cur_col + String.length(line_text) + 1}}
      end)
    else
      {line, new_col}
    end
  end

  defp function_call_includes_cursor(call_range, line, char) do
    range(start_line, start_character, end_line, end_character) = call_range

    starts_before =
      cond do
        start_line < line -> true
        start_line == line and start_character <= char -> true
        true -> false
      end

    ends_after =
      cond do
        end_line > line -> true
        end_line == line and end_character >= char -> true
        true -> false
      end

    starts_before and ends_after
  end
end
