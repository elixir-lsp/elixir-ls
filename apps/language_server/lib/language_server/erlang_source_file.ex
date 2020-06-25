defmodule ElixirLS.LanguageServer.ErlangSourceFile do
  alias ElixirLS.LanguageServer.SourceFile

  def get_beam_file(module, :preloaded) do
    case :code.get_object_code(module) do
      {_module, _binary, beam_file} -> beam_file
      :error -> nil
    end
  end

  def get_beam_file(_module, beam_file), do: beam_file

  def beam_file_to_erl_file(beam_file) do
    beam_file
    |> to_string
    |> String.replace(
      Regex.recompile!(~r/(.+)\/ebin\/([^\s]+)\.beam$/),
      "\\1/src/\\2.erl"
    )
  end

  def module_line(file) do
    find_line_by_regex(file, Regex.recompile!(~r/^-module/))
  end

  def function_line(file, function) do
    # TODO use arity?
    escaped =
      function
      |> Atom.to_string()
      |> Regex.escape()

    find_line_by_regex(file, Regex.recompile!(~r/^#{escaped}\b/))
  end

  defp find_line_by_regex(file, regex) do
    index =
      file
      |> File.read!()
      |> SourceFile.lines()
      |> Enum.find_index(&String.match?(&1, regex))

    case index do
      nil -> nil
      i -> i + 1
    end
  end
end
