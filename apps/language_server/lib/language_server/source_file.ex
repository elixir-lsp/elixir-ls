defmodule ElixirLS.LanguageServer.SourceFile do
  defstruct text: nil,
            version: nil

  def lines(%__MODULE__{text: text}) do
    String.split(text, ["\r\n", "\r", "\n"])
  end

  def apply_content_changes(source_file, []) do
    source_file
  end

  # TODO: Support incremental changes
  def apply_content_changes(source_file, [%{"text" => text} | rest]) do
    apply_content_changes(%{source_file | text: text}, rest)
  end

  @doc """
  Returns path from URI in a way that handles windows file:///c%3A/... URLs correctly
  """
  def path_from_uri(uri) do
    uri_path = URI.decode(URI.parse(uri).path)

    case :os.type() do
      {:win32, _} -> String.trim_leading(uri_path, "/")
      _ -> uri_path
    end
  end

  def path_to_uri(path) do
    uri_path =
      path
      |> Path.expand()
      |> URI.encode()
      |> String.replace(":", "%3A")

    case :os.type() do
      {:win32, _} -> "file:///" <> uri_path
      _ -> "file://" <> uri_path
    end
  end

  def full_range(source_file) do
    lines = lines(source_file)

    %{
      "start" => %{"line" => 0, "character" => 0},
      "end" => %{"line" => Enum.count(lines) - 1, "character" => String.length(List.last(lines))}
    }
  end
end
