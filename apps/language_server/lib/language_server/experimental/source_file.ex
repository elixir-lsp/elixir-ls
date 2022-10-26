defmodule ElixirLS.LanguageServer.Experimental.SourceFile do
  alias ElixirLS.LanguageServer.Experimental.Protocol.Types.TextDocument.ContentChangeEvent

  alias ElixirLS.LanguageServer.Experimental.SourceFile.Conversions
  alias ElixirLS.LanguageServer.Experimental.SourceFile.Document
  alias ElixirLS.LanguageServer.Experimental.SourceFile.Position
  alias ElixirLS.LanguageServer.Experimental.SourceFile.Range
  alias ElixirLS.LanguageServer.SourceFile
  import ElixirLS.LanguageServer.Protocol, only: [range: 4]
  import ElixirLS.LanguageServer.Experimental.SourceFile.Line

  defstruct [:uri, :path, :version, dirty?: false, document: nil]

  @type t :: %__MODULE__{
          uri: String.t(),
          version: pos_integer(),
          dirty?: boolean,
          document: Document.t(),
          path: String.t()
        }

  @type version :: pos_integer()
  @type change_application_error :: {:error, {:invalid_range, map()}}
  # public
  @spec new(URI.t(), String.t(), pos_integer()) :: t
  def new(uri, text, version) do
    %__MODULE__{
      uri: uri,
      version: version,
      document: Document.new(text),
      path: SourceFile.Path.from_uri(uri)
    }
  end

  @spec mark_dirty(t) :: t
  def mark_dirty(%__MODULE__{} = source) do
    %__MODULE__{source | dirty?: true}
  end

  @spec mark_clean(t) :: t
  def mark_clean(%__MODULE__{} = source) do
    %__MODULE__{source | dirty?: false}
  end

  @spec fetch_text_at(t, version()) :: {:ok, String.t()} | :error
  def fetch_text_at(%__MODULE{} = source, line_number) do
    with {:ok, line(text: text)} <- Document.fetch_line(source.document, line_number) do
      {:ok, text}
    else
      _ ->
        :error
    end
  end

  @spec apply_content_changes(t, pos_integer(), [map | ContentChangeEvent.t()]) ::
          {:ok, t} | change_application_error()
  def apply_content_changes(%__MODULE__{version: current_version}, new_version, _)
      when new_version <= current_version do
    {:error, :invalid_version}
  end

  def apply_content_changes(%__MODULE__{} = source, _, []) do
    {:ok, source}
  end

  def apply_content_changes(%__MODULE__{} = source, version, changes) when is_list(changes) do
    result =
      Enum.reduce_while(changes, source, fn change, source ->
        case apply_change(source, change) do
          {:ok, new_source} ->
            {:cont, new_source}

          error ->
            {:halt, error}
        end
      end)

    case result do
      %__MODULE__{} = source ->
        source = mark_dirty(%__MODULE__{source | version: version})

        {:ok, source}

      error ->
        error
    end
  end

  def to_string(%__MODULE__{} = source) do
    source
    |> to_iodata()
    |> IO.iodata_to_binary()
  end

  # private

  defp line_count(%__MODULE__{} = source) do
    Document.size(source.document)
  end

  defp apply_change(
         %__MODULE__{} = source,
         %Range{start: %Position{} = start_pos, end: %Position{} = end_pos},
         new_text
       ) do
    start_line = start_pos.line

    new_lines_iodata =
      cond do
        start_line > line_count(source) ->
          append_to_end(source, new_text)

        start_line <= 0 ->
          prepend_to_beginning(source, new_text)

        true ->
          apply_valid_edits(source, new_text, start_pos, end_pos)
      end

    new_document =
      new_lines_iodata
      |> IO.iodata_to_binary()
      |> Document.new()

    {:ok, %__MODULE__{source | document: new_document}}
  end

  defp apply_change(
         %__MODULE__{} = source,
         %{
           "range" => range(start_line, start_char, end_line, end_char) = range,
           "text" => new_text
         }
       )
       when start_line >= 0 and start_char >= 0 and end_line >= 0 and end_char >= 0 do
    with {:ok, ex_range} <- Conversions.to_elixir(range, source) do
      apply_change(source, ex_range, new_text)
    else
      _ ->
        {:error, {:invalid_range, range}}
    end
  end

  defp apply_change(%__MODULE__{}, %{"range" => invalid_range}) do
    {:error, {:invalid_range, invalid_range}}
  end

  defp apply_change(
         %__MODULE__{} = source,
         %{"text" => new_text}
       ) do
    {:ok, %__MODULE__{source | document: Document.new(new_text)}}
  end

  defp append_to_end(%__MODULE__{} = source, edit_text) do
    [to_iodata(source), edit_text]
  end

  defp prepend_to_beginning(%__MODULE__{} = source, edit_text) do
    [edit_text, to_iodata(source)]
  end

  defp apply_valid_edits(%__MODULE{} = source, edit_text, start_pos, end_pos) do
    Enum.reduce(source.document, [], fn line() = line, acc ->
      case edit_action(line, edit_text, start_pos, end_pos) do
        :drop ->
          acc

        {:append, io_data} ->
          [acc, io_data]
      end
    end)
  end

  defp edit_action(line() = line, edit_text, %Position{} = start_pos, %Position{} = end_pos) do
    %Position{line: start_line, character: start_char} = start_pos
    %Position{line: end_line, character: end_char} = end_pos

    line(line_number: line_number, text: text, ending: ending) = line

    cond do
      line_number < start_line ->
        {:append, [text, ending]}

      line_number > end_line ->
        {:append, [text, ending]}

      line_number == start_line && line_number == end_line ->
        {:ok, prefix_text} = utf16_prefix(line, start_char)

        {:ok, suffix_text} = utf16_suffix(line, end_char)

        {:append, [prefix_text, edit_text, suffix_text, ending]}

      line_number == start_line ->
        {:ok, prefix_text} = utf16_prefix(line, start_char)
        {:append, [prefix_text, edit_text]}

      line_number == end_line ->
        {:ok, suffix_text} = utf16_suffix(line, end_char)
        {:append, [suffix_text, ending]}

      true ->
        :drop
    end
  end

  defp utf16_prefix(line(text: text, ascii?: _), start_index) do
    {:ok, binary_part(text, 0, start_index)}
  end

  defp utf16_prefix(line(text: utf8_text), start_index) do
    with {:ok, utf16_text} <- to_utf16(utf8_text) do
      end_index = min(start_index * 2, byte_size(utf16_text))

      utf16_text
      |> binary_part(0, end_index)
      |> to_utf8()
    end
  end

  defp utf16_suffix(line(text: text, ascii?: _), end_index) do
    count = max(byte_size(text) - end_index, 0)

    {:ok, String.slice(text, end_index, count)}
  end

  defp utf16_suffix(line(text: utf8_text), end_index) do
    with {:ok, utf16_text} <- to_utf16(utf8_text) do
      utf16_length = byte_size(utf16_text)
      utf16_start = min(end_index * 2, utf16_length)
      utf16_end = max(utf16_length - end_index * 2, 0)

      utf16_text
      |> binary_part(utf16_start, utf16_end)
      |> to_utf8()
    end
  end

  defp to_iodata(%__MODULE__{} = source) do
    Document.to_iodata(source.document)
  end

  defp increment_version(%__MODULE__{} = source) do
    version =
      case source.version do
        v when is_integer(v) -> v + 1
        _ -> 1
      end

    %__MODULE__{source | version: version}
  end

  defp to_utf16(b) do
    case :unicode.characters_to_binary(b, :utf8, :utf16) do
      b when is_binary(b) -> {:ok, b}
      {:error, _, _} = err -> err
      {:incomplete, _, _} -> {:error, :incomplete}
    end
  end

  defp to_utf8(b) do
    case :unicode.characters_to_binary(b, :utf16, :utf8) do
      b when is_binary(b) -> {:ok, b}
      {:error, _, _} = err -> err
      {:incomplete, _, _} -> {:error, :incomplete}
    end
  end
end
