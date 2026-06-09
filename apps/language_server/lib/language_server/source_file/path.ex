defmodule ElixirLS.LanguageServer.SourceFile.Path do
  @file_scheme "file"

  @doc """
  Returns path from URI in a way that handles windows file:///c%3A/... URLs correctly
  """
  def from_uri(%URI{scheme: @file_scheme, path: nil}) do
    # treat no path as root path
    convert_separators_to_native("/")
  end

  def from_uri(%URI{scheme: @file_scheme, path: path, authority: authority})
      when path != "" and authority not in ["", nil] do
    # UNC path
    convert_separators_to_native("//#{URI.decode(authority)}#{URI.decode(path)}")
  end

  def from_uri(%URI{scheme: @file_scheme, path: path}) do
    decoded_path = URI.decode(path)

    if windows?() and String.match?(decoded_path, ~r/^\/[a-zA-Z]:/) do
      # Windows drive letter path
      # drop leading `/` and downcase drive letter
      <<"/", letter::binary-size(1), path_rest::binary>> = decoded_path
      "#{String.downcase(letter)}#{path_rest}"
    else
      decoded_path
    end
    |> convert_separators_to_native()
  end

  def from_uri(%URI{scheme: scheme}) do
    raise ArgumentError, message: "unexpected URI scheme #{inspect(scheme)}"
  end

  def from_uri(uri) do
    uri |> URI.parse() |> from_uri()
  end

  def absolute_from_uri(uri) do
    uri |> from_uri |> Path.absname()
  end

  def absolute_from_uri(uri, project_dir) when is_binary(project_dir) or is_nil(project_dir) do
    if project_dir == nil do
      uri |> from_uri |> Path.absname()
    else
      uri |> from_uri |> Path.absname(project_dir)
    end
  end

  def absolute(path) do
    path |> Path.expand() |> convert_separators_to_native()
  end

  def absolute(path, project_dir) do
    path |> Path.expand(project_dir) |> convert_separators_to_native()
  end

  def to_uri(path) when not is_nil(path) do
    path =
      path
      |> Path.expand()
      |> convert_separators_to_universal()

    to_uri_impl(path)
  end

  def to_uri(path, project_dir) when not is_nil(path) do
    path =
      if project_dir == nil do
        Path.expand(path)
      else
        Path.expand(path, project_dir)
      end
      |> convert_separators_to_universal()

    to_uri_impl(path)
  end

  defp to_uri_impl(path) do
    {authority, path} =
      case path do
        "//" <> rest ->
          # UNC path - extract authority
          case String.split(rest, "/", parts: 2) do
            [_] ->
              # no path part, use root path
              {rest, "/"}

            [authority, ""] ->
              # empty path part, use root path
              {authority, "/"}

            [authority, p] ->
              {authority, "/" <> p}
          end

        "/" <> _rest ->
          {"", path}

        other ->
          # treat as relative to root path
          {"", "/" <> other}
      end

    %URI{
      scheme: @file_scheme,
      authority: authority |> URI.encode(),
      # file system paths allow reserved URI characters that need to be escaped
      # the exact rules are complicated but for simplicity we escape all reserved except `/`
      # that's what https://github.com/microsoft/vscode-uri does
      path: path |> URI.encode(&(&1 == ?/ or URI.char_unreserved?(&1)))
    }
    |> URI.to_string()
  end

  def windows? do
    case os_type() do
      {:win32, _} -> true
      _ -> false
    end
  end

  defp convert_separators_to_native(path) do
    if windows?() do
      # convert path separators from URI to Windows
      String.replace(path, ~r/\//, "\\")
    else
      path
    end
  end

  defp convert_separators_to_universal(path) do
    if windows?() do
      # convert path separators from Windows to URI
      String.replace(path, ~r/\\/, "/")
    else
      path
    end
  end

  # this is here to be mocked in tests
  defp os_type do
    :os.type()
  end

  # This function expects absolute paths with universal separators
  def path_in_dir?(file, dir) do
    dir = if dir == "/", do: "", else: String.trim_trailing(dir, "/")

    case String.starts_with?(file, dir) do
      true ->
        # Get the grapheme after the directory in the file path
        next_char_index = String.length(dir)
        next_char = String.slice(file, next_char_index, 1)

        # If the next character is either "" (end of string) or a "/", it's a valid match
        next_char in ["", "/"]

      false ->
        false
    end
  end

  def escape_for_wildcard(path) when is_list(path), do: escape_for_wildcard(to_string(path))

  def escape_for_wildcard(path) when is_binary(path) do
    # Path.wildcard expects universal separators even on windows
    # escape all special chars
    path
    |> convert_separators_to_universal()
    |> String.replace("\\", "\\\\")
    |> String.replace("?", "\\?")
    |> String.replace("*", "\\*")
    |> String.replace("{", "\\{")
    |> String.replace("}", "\\}")
    |> String.replace("[", "\\[")
    |> String.replace("]", "\\]")
    |> String.replace(",", "\\,")
  end
end
