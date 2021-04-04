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

  @newlines ["\r\n", "\n", "\r"]

  @impl ElixirLS.LanguageServer.Providers.ExecuteCommand
  def execute([operation, uri, line, col], state)
      when is_integer(line) and is_integer(col) and is_binary(uri) and
             operation in ["toPipe", "fromPipe"] do
    # line and col are assumed to be 0-indexed
    source_file = Server.get_source_file(state, uri)

    {:ok, %{edited_text: edited_text, edit_range: edit_range}} =
      case operation do
        "toPipe" ->
          to_pipe_at_cursor(source_file.text, line, col)

        "fromPipe" ->
          from_pipe_at_cursor(source_file.text, line, col)
      end

    label =
      case operation do
        "toPipe" -> "Convert function call to pipe operator"
        "fromPipe" -> "Convert pipe operator to function call"
      end

    edit_result =
      JsonRpc.send_request("workspace/applyEdit", %{
        "label" => label,
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

  defp to_pipe_at_cursor(text, line, col) do
    result =
      ElixirSense.Core.Source.walk_text(
        text,
        %{walked_text: "", function_call: nil, range: nil},
        fn current_char, remaining_text, current_line, current_col, acc ->
          if current_line - 1 == line and current_col - 1 == col do
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
        piped_text = AST.to_pipe(function_call)

        {:ok, %{edited_text: piped_text, edit_range: range}}
    end
  end

  defp from_pipe_at_cursor(text, line, col) do
    result =
      ElixirSense.Core.Source.walk_text(
        text,
        %{walked_text: "", pipe_call: nil, range: nil},
        fn current_char, remaining_text, current_line, current_col, acc ->
          if current_line - 1 == line and current_col - 1 == col do
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

    {head, _tail} = String.split_at(call, -String.length(tail))

    col = if head == "", do: col + 2, else: col - String.length(head) + 1

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

    {:ok, pipe_call, range(start_line, start_col, end_line, end_col)}
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

    function_name =
      head
      |> String.trim_trailing(call_without_function_name)
      |> get_function_name_from_tail()

    function_name <> call_without_function_name
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
end
