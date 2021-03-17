defmodule ElixirLS.LanguageServer.Providers.ExecuteCommand.ManipulatePipes do
  @moduledoc """
  This module implements a custom command for converting function calls
  to pipe operators and pipes to function calls.

  Returns a formatted source fragment.
  """
  import ElixirLS.LanguageServer.Protocol

  alias ElixirLS.LanguageServer.{JsonRpc, Server}

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
          raise ArgumentError, "from pipe not implemented"
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

  def to_pipe_at_cursor(source_file, line, col) do
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
          |> to_pipe()
          |> Macro.to_string()

        {:ok, %{edited_text: piped_text, edit_range: range}}
    end
  end

  def get_function_call(line, col, head, current, original_tail) do
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

  def do_get_function_call(text, start_char, end_char) do
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

  @doc false
  def to_pipe(code) do
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

  defp to_pipe({{:., line, _args} = function, _meta, args}, %{has_piped: false} = acc)
       when args != [] do
    {{:|>, line, [hd(args), {function, line, tl(args)}]}, Map.put(acc, :has_piped, true)}
  end

  defp to_pipe({function, line, [h | t]}, %{has_piped: false} = acc)
       when is_atom(function) and t != [] do
    {{:|>, line, [h, {function, line, t}]}, Map.put(acc, :has_piped, true)}
  end

  defp to_pipe(node, acc) do
    {node, acc}
  end
end
