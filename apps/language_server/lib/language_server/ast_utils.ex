defmodule ElixirLS.LanguageServer.AstUtils do
  import ElixirLS.LanguageServer.Protocol
  alias ElixirLS.LanguageServer.SourceFile

  @binary_operators ~w[. ** * / + - ++ -- +++ --- .. <> in |> <<< >>> <<~ ~>> <~ ~> <~> < > <= >= == != === !== =~ && &&& and || ||| or = => :: when <- -> \\]a
  @unary_operators ~w[@ + - ! ^ not &]a

  def node_range(atom) when is_atom(atom), do: nil
  def node_range([{{:__block__, _, [atom]} = first, _} | _] = list) when is_atom(atom) do
    case List.last(list) do
      {_, last} ->
        case {node_range(first), node_range(last)} do
          {range(start_line, start_character, _, _), range(_, _, end_line, end_character)} ->
            range(start_line, start_character, end_line, end_character)
          _ -> nil
          end
      _ -> nil
    end
  end
  def node_range(list) when is_list(list), do: nil

  def node_range({:__block__, meta, args} = ast) do
    line = Keyword.get(meta, :line)
    column = Keyword.get(meta, :column)

    if line == nil or column == nil do
      if match?([_ | _], args) do
        first = List.first(args)
        last = List.last(args)

        case {node_range(first), node_range(last)} do
          {range(start_line, start_character, _, _), range(_, _, end_line, end_character)} ->
            range(start_line, start_character, end_line, end_character)
          _ -> nil
        end
      end
    else
      line = line - 1
      column = column - 1

      {end_line, end_column} = cond do
        token = meta[:token] ->
          {line, column + String.length(token)}
        end_location = meta[:closing] ->
          # 2 element tuple
          {end_location[:line] - 1, end_location[:column] - 1 + 1}
        match?([_], args) ->
          [literal] = args
          delimiter = meta[:delimiter]
          if delimiter in ["\"\"\"", "'''"] do
            literal = if is_list(literal) do
              to_string(literal)
            else
              literal
            end
            lines = SourceFile.lines(literal)
            {line + length(lines), meta[:indentation] + get_delimiter_length(delimiter)}
          else
            get_literal_end(literal, {line, column}, delimiter)
          end
          
        true ->
          {line, column}
      end

      range(line, column, end_line, end_column)
    end
  end

  # def node_range({left, right}) do
  #   case {node_range(left), node_range(right)} do
  #     {range(start_line, start_column, _, _), range(_, _, end_line, end_column)} ->
  #       range(start_line, start_column, end_line, end_column)
  #     _ -> nil
  #   end
  # end
  # def node_range([node]) do
  #   node_range(node)
  # end

  # def node_range()

  # interpolated charlist AST is too complicated to handle via the generic algorithm
  def node_range({{:".", _, [List, :to_charlist]}, meta, _args} = ast) do
    line = Keyword.get(meta, :line) - 1
    column = Keyword.get(meta, :column) - 1
    {end_line, end_column} = get_eoe_by_formatting(ast, {line, column})
    # formatter changes charlist '' to ~c"" sigil so we need to correct columns
    # if charlist is single line
    correction = if end_line == line do
      2
    else
      0
    end
    range(line, column, end_line, end_column - correction)
  end

  def node_range({form, meta, args} = ast) do
    line = Keyword.get(meta, :line)
    column = Keyword.get(meta, :column)

    if line == nil or column == nil do
      nil
    else
      line = line - 1
      column = column - 1

      dbg({line, column})

      {start_line, start_column} = cond do
        form == :"%{}" ->
          # TODO elixir parser bug?
          {line, column - 1}
        form == :-> and match?([[_|_], _], args) ->
          [[left | _], _right] = args
          operator_length = form |> to_string() |> String.length()
          case node_range(left) do
            range(line, column, _, _) ->
              {line, column}
            nil ->
              # TODO is it needed
              {line, column}
          end
        form == :"&" and match?([int] when is_integer(int), args) ->
          [int] = args
          {line, column}
        form in @binary_operators and match?([_, _], args) ->
          [left, _right] = args
          operator_length = form |> to_string() |> String.length()
          
          case node_range(left) do
            range(line, column, _, _) ->
              {line, column}
            nil ->
              # TODO is it needed
              {line, column}
          end
        match?({:., _, [_ | _]}, form) ->
          {:., _, [module_or_var | _]} = form
          case node_range(module_or_var) do
            range(line, column, _, _) ->
              {line, column}
            nil ->
              # TODO is it needed
              {line, column}
          end
          |> dbg
        true -> {line, column}
      end

      {end_line, end_column} = cond do
        end_location = meta[:end] ->
          {end_location[:line] - 1, end_location[:column] - 1 + 3}

        end_location = meta[:end_of_expression] ->
          {end_location[:line] - 1, end_location[:column] - 1}

        end_location = meta[:closing] ->
          closing_length =
            case form do
              :<<>> -> 2
              :fn -> 3
              _ -> 1
            end

          {end_location[:line] - 1, end_location[:column] - 1 + closing_length}

        form == :__aliases__ ->
          last = meta[:last]

          last_length =
            case List.last(args) do
              atom when is_atom(atom) -> atom |> to_string() |> String.length()
              _ -> 0
            end

          {last[:line] - 1, last[:column] - 1 + last_length}

        form == :"%" and match?([_, _], args) ->
          [_alias, map] = args
          case node_range(map) do
            range(_, _, end_line, end_column) ->
              {end_line, end_column}
            nil ->
              # TODO is it needed
              {line, column}
          end

        form == :"<<>>" or is_atom(form) and String.starts_with?(to_string(form), "sigil_") ->
          # interpolated string AST is too complicated
          # try to format it instead
          get_eoe_by_formatting(ast, {line, column})

        form == :"&" and match?([int] when is_integer(int), args) ->
          [int] = args
          {line, column + String.length(to_string(int))}
        form in @binary_operators and match?([_, _], args) ->
          [left, right] = args
          operator_length = form |> to_string() |> String.length()
          case node_range(right) do
            range(_, _, end_line, end_column) ->
              {end_line, end_column}
            nil ->
              # TODO is it needed
              {line, column + operator_length}
          end

        form in @unary_operators and match?([_], args) ->
          [right] = args
          operator_length = form |> to_string() |> String.length()
          case node_range(right) do
            range(_, _, end_line, end_column) ->
              {end_line, end_column}
            nil ->
              # TODO is it needed
              {line, column + operator_length}
          end

        match?({:., _, [_, _ ]}, form) ->
          case args do
            [] ->
              {:., _, [_, fun]} = form
              # TODO handle quotes
              {line, column + String.length(to_string(fun))}
            _ ->
              case node_range(List.last(args)) do
                range(_, _, end_line, end_column) ->
                  {end_line, end_column}
                nil ->
                  # TODO is it needed
                  nil
                  # {line, column + operator_length}
              end
          end
          |> dbg

        is_atom(form) ->
          variable_length = form |> to_string() |> String.length()
          case args do
            nil ->
              {line, column + variable_length}
            [] -> 
              {line, column + variable_length}
            _ ->
              # local call no parens
              last_arg = List.last(args)
              case node_range(last_arg |> dbg) |> dbg do
                range(_, _, end_line, end_column) ->
                  {end_line, end_column}
                nil ->
                  # TODO is it needed
                  {line, column + variable_length}
              end
          end
          

        true ->
          raise "unhandled block"
      end

      range(start_line, start_column, end_line, end_column)
    end
  end

  def get_literal_end(true, {line, column}, _), do: {line, column + 4}
  def get_literal_end(false, {line, column}, _), do: {line, column + 5}
  def get_literal_end(nil, {line, column}, _), do: {line, column + 3}
  def get_literal_end(atom, {line, column}, delimiter) when is_atom(atom) do
    delimiter_length = get_delimiter_length(delimiter)
    lines = atom |> to_string() |> SourceFile.lines
    case lines do
      [only_line] ->
        # add :
        {line, column + String.length(only_line) + 1 + 2 * delimiter_length}
      _ ->
        last_line_length = lines |> List.last |> String.length
        {line + length(lines) - 1, last_line_length + 1 * delimiter_length}
    end
  end
  def get_literal_end(list, {line, column}, delimiter) when is_list(list) do
    delimiter_length = get_delimiter_length(delimiter)
    lines = list |> to_string() |> SourceFile.lines
    case lines do
      [only_line] ->
        # add 2 x '
        {line, column + String.length(only_line) + 2 * delimiter_length}
      _ ->
        # add 1 x '
        last_line_length = lines |> List.last |> String.length
        {line + length(lines) - 1, last_line_length + 1 * delimiter_length}
    end
  end
  def get_literal_end(binary, {line, column}, delimiter) when is_binary(binary) do
    delimiter_length = get_delimiter_length(delimiter)
    lines = binary |> SourceFile.lines
    case lines do
      [only_line] ->
        # add 2 x "
        {line, column + String.length(only_line) + 2 * delimiter_length}
      _ ->
        # add 1 x "
        last_line_length = lines |> List.last |> String.length
        {line + length(lines) - 1, last_line_length + 1 * delimiter_length}
    end
  end

  def get_delimiter_length(nil), do: 0
  def get_delimiter_length("\""), do: 1
  def get_delimiter_length("'"), do: 1
  def get_delimiter_length("\"\"\""), do: 3
  def get_delimiter_length("'''"), do: 3

  defp get_eoe_by_formatting(ast, {line, column}) do
    code = ast |> Code.quoted_to_algebra |> Inspect.Algebra.format(:infinity) |> IO.iodata_to_binary() |> dbg
    lines = code |> SourceFile.lines()
    case lines do
      [_] -> {line, column + String.length(code)}
      _ ->
        last_line = List.last(lines)
        {line + length(lines) - 1, String.length(last_line)}
    end
  end
end
