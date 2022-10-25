defmodule ElixirLS.LanguageServer.Experimental.SourceFile.Document do
  alias ElixirLS.LanguageServer.Experimental.SourceFile.LineParser
  alias ElixirLS.LanguageServer.Experimental.SourceFile.Line

  import Line
  defstruct lines: nil, starting_index: 1

  @type t :: %__MODULE__{}

  def new(text, starting_index \\ 1) do
    lines =
      text
      |> LineParser.parse(starting_index)
      |> List.to_tuple()

    %__MODULE__{lines: lines, starting_index: starting_index}
  end

  def to_iodata(%__MODULE__{} = document) do
    document.lines
    |> Tuple.to_list()
    |> Enum.reduce([], fn
      line(text: text, ending: ending), acc ->
        [acc | [text | ending]]
    end)
  end

  def to_string(%__MODULE__{} = document) do
    document
    |> to_iodata()
    |> IO.iodata_to_binary()
  end

  def size(%__MODULE__{} = document) do
    tuple_size(document.lines)
  end

  def fetch_line(%__MODULE__{} = document, index) when is_integer(index) do
    case Enum.at(document, index - document.starting_index) do
      line() = line -> {:ok, line}
      _ -> :error
    end
  end
end

defimpl Enumerable, for: ElixirLS.LanguageServer.Experimental.SourceFile.Document do
  alias ElixirLS.LanguageServer.Experimental.SourceFile.Document

  def count(%Document{} = document) do
    {:ok, Document.size(document)}
  end

  def member?(%Document{}, _) do
    {:error, Document}
  end

  def reduce(%Document{} = document, acc, fun) do
    document.lines
    |> Tuple.to_list()
    |> Enumerable.reduce(acc, fun)
  end

  def slice(%Document{} = document) do
    {:ok, Document.size(document), fn start, len -> do_slice(document, start, len) end}
  end

  defp do_slice(%Document{} = document, start, 1) do
    [elem(document.lines, start)]
  end

  defp do_slice(%Document{} = document, start, length) do
    Enum.map(start..(start + length - 1), &elem(document.lines, &1))
  end
end
