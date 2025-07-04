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
    uri |> from_uri |> absname()
  end

  def absolute_from_uri(uri, project_dir) when is_binary(project_dir) or is_nil(project_dir) do
    if project_dir == nil do
      uri |> from_uri |> absname()
    else
      uri |> from_uri |> absname(project_dir)
    end
  end

  def absolute(path) do
    path |> expand() |> convert_separators_to_native()
  end

  def absolute(path, project_dir) do
    path |> expand(project_dir) |> convert_separators_to_native()
  end

  def to_uri(path) when not is_nil(path) do
    path =
      path
      |> expand()
      |> convert_separators_to_universal()

    to_uri_impl(path)
  end

  def to_uri(path, project_dir) when not is_nil(path) do
    path =
      if project_dir == nil do
        expand(path)
      else
        expand(path, project_dir)
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
    dir = if dir == "/", do: "/", else: String.trim_trailing(dir, "/")

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

  # the functions below are copied from elixir project
  # https://github.com/lukaszsamson/elixir/blob/bf3e2fd3ad78235bda059b80994a90d9a4184353/lib/elixir/lib/path.ex
  # with applied https://github.com/elixir-lang/elixir/pull/13061
  # TODO remove when we require elixir 1.16
  # The original code is licensed as follows:
  #
  # Copyright 2012 Plataformatec
  # Copyright 2021 The Elixir Team
  #
  # Licensed under the Apache License, Version 2.0 (the "License");
  # you may not use this file except in compliance with the License.
  # You may obtain a copy of the License at
  #
  #    https://www.apache.org/licenses/LICENSE-2.0
  #
  # Unless required by applicable law or agreed to in writing, software
  # distributed under the License is distributed on an "AS IS" BASIS,
  # WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  # See the License for the specific language governing permissions and
  # limitations under the License.

  @type t :: IO.chardata()

  @spec absname(t) :: binary
  def absname(path) do
    absname(path, &File.cwd!/0)
  end

  @spec absname(t, t | (-> t)) :: binary
  def absname(path, relative_to) do
    path = IO.chardata_to_string(path)

    case Path.type(path) do
      :relative ->
        relative_to =
          if is_function(relative_to, 0) do
            relative_to.()
          else
            relative_to
          end

        absname_join([relative_to, path])

      :absolute ->
        absname_join([path])

      :volumerelative ->
        relative_to =
          if is_function(relative_to, 0) do
            relative_to.()
          else
            relative_to
          end
          |> IO.chardata_to_string()

        absname_vr(Path.split(path), Path.split(relative_to), relative_to)
    end
  end

  # Absolute path on current drive
  defp absname_vr(["/" | rest], [volume | _], _relative), do: absname_join([volume | rest])

  # Relative to current directory on current drive
  defp absname_vr([<<x, ?:>> | rest], [<<x, _::binary>> | _], relative),
    do: absname(absname_join(rest), relative)

  # Relative to current directory on another drive
  defp absname_vr([<<x, ?:>> | name], _, _relative) do
    cwd =
      case :file.get_cwd([x, ?:]) do
        {:ok, dir} -> IO.chardata_to_string(dir)
        {:error, _} -> <<x, ?:, ?/>>
      end

    absname(absname_join(name), cwd)
  end

  @slash [?/, ?\\]

  defp absname_join([]), do: ""
  defp absname_join(list), do: absname_join(list, major_os_type())

  defp absname_join([name1, name2 | rest], os_type) do
    joined = do_absname_join(IO.chardata_to_string(name1), Path.relative(name2), [], os_type)
    absname_join([joined | rest], os_type)
  end

  defp absname_join([name], os_type) do
    do_absname_join(IO.chardata_to_string(name), <<>>, [], os_type)
  end

  defp do_absname_join(<<uc_letter, ?:, rest::binary>>, relativename, [], :win32)
       when uc_letter in ?A..?Z,
       do: do_absname_join(rest, relativename, [?:, uc_letter + ?a - ?A], :win32)

  defp do_absname_join(<<c1, c2, rest::binary>>, relativename, [], :win32)
       when c1 in @slash and c2 in @slash,
       do: do_absname_join(rest, relativename, ~c"//", :win32)

  defp do_absname_join(<<?\\, rest::binary>>, relativename, result, :win32),
    do: do_absname_join(<<?/, rest::binary>>, relativename, result, :win32)

  defp do_absname_join(<<?/, rest::binary>>, relativename, [?., ?/ | result], os_type),
    do: do_absname_join(rest, relativename, [?/ | result], os_type)

  defp do_absname_join(<<?/, rest::binary>>, relativename, [?/ | result], os_type),
    do: do_absname_join(rest, relativename, [?/ | result], os_type)

  defp do_absname_join(<<>>, <<>>, result, os_type),
    do: IO.iodata_to_binary(reverse_maybe_remove_dir_sep(result, os_type))

  defp do_absname_join(<<>>, relativename, [?: | rest], :win32),
    do: do_absname_join(relativename, <<>>, [?: | rest], :win32)

  defp do_absname_join(<<>>, relativename, [?/ | result], os_type),
    do: do_absname_join(relativename, <<>>, [?/ | result], os_type)

  defp do_absname_join(<<>>, relativename, result, os_type),
    do: do_absname_join(relativename, <<>>, [?/ | result], os_type)

  defp do_absname_join(<<char, rest::binary>>, relativename, result, os_type),
    do: do_absname_join(rest, relativename, [char | result], os_type)

  defp reverse_maybe_remove_dir_sep([?/, ?:, letter], :win32), do: [letter, ?:, ?/]
  defp reverse_maybe_remove_dir_sep([?/], _), do: [?/]
  defp reverse_maybe_remove_dir_sep([?/ | name], _), do: :lists.reverse(name)
  defp reverse_maybe_remove_dir_sep(name, _), do: :lists.reverse(name)

  @spec expand(t) :: binary
  def expand(path) do
    expand_dot(absname(expand_home(path), &File.cwd!/0))
  end

  @spec expand(t, t) :: binary
  def expand(path, relative_to) do
    expand_dot(absname(absname(expand_home(path), expand_home(relative_to)), &File.cwd!/0))
  end

  defp expand_home(type) do
    case IO.chardata_to_string(type) do
      "~" <> rest -> resolve_home(rest)
      rest -> rest
    end
  end

  defp resolve_home(""), do: System.user_home!()

  defp resolve_home(rest) do
    case {rest, major_os_type()} do
      {"\\" <> _, :win32} -> System.user_home!() <> rest
      {"/" <> _, _} -> System.user_home!() <> rest
      _ -> "~" <> rest
    end
  end

  # expands dots in an absolute path represented as a string
  defp expand_dot(path) do
    [head | tail] = :binary.split(path, "/", [:global])
    IO.iodata_to_binary(expand_dot(tail, [head <> "/"]))
  end

  defp expand_dot([".." | t], [_, _ | acc]), do: expand_dot(t, acc)
  defp expand_dot([".." | t], acc), do: expand_dot(t, acc)
  defp expand_dot(["." | t], acc), do: expand_dot(t, acc)
  defp expand_dot([h | t], acc), do: expand_dot(t, ["/", h | acc])
  defp expand_dot([], ["/", head | acc]), do: :lists.reverse([head | acc])
  defp expand_dot([], acc), do: :lists.reverse(acc)

  defp major_os_type do
    :os.type() |> elem(0)
  end
end
