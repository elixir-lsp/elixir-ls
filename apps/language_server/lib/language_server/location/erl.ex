defmodule ElixirLS.LanguageServer.Location.Erl do
  alias ElixirSense.Core.Source
  require Logger

  @moduledoc """
  A parser for Erlang (.erl) files to locate positions of types, functions, and module declarations.
  """

  @doc """
  Finds the position range of a type definition in an Erlang `.erl` file.

  ## Parameters

    - `file`: The path to the Erlang file.
    - `name`: The name of the type (as an atom).

  ## Returns

    - `{{line, start_column}, {line, end_column}}` if found.
    - `nil` if not found.
  """
  def find_type_range(file, name) do
    escaped =
      name
      |> Atom.to_string()
      |> Regex.escape()

    regex = ~r/^-(typep?|opaque)\s+(?<name>#{escaped})\b/u

    find_range_by_regex(file, regex)
  end

  @doc """
  Finds the position range of a callback definition in an Erlang `.erl` file.

  ## Parameters

    - `file`: The path to the Erlang file.
    - `name`: The name of the type (as an atom).

  ## Returns

    - `{{line, start_column}, {line, end_column}}` if found.
    - `nil` if not found.
  """
  def find_callback_range(file, name) do
    escaped =
      name
      |> Atom.to_string()
      |> Regex.escape()

    regex = ~r/^-callback\s+(?<name>#{escaped})\b/u

    find_range_by_regex(file, regex)
  end

  @doc """
  Finds the position range of a function definition in an Erlang `.erl` file.

  ## Parameters

    - `file`: The path to the Erlang file.
    - `name`: The name of the function (as an atom).

  ## Returns

    - `{{line, start_column}, {line, end_column}}` if found.
    - `nil` if not found.
  """
  def find_fun_range(file, name) do
    escaped =
      name
      |> Atom.to_string()
      |> Regex.escape()

    regex = ~r/^(?<name>#{escaped})\b\(/u

    find_range_by_regex(file, regex)
  end

  @doc """
  Finds the position range of a module declaration in an Erlang `.erl` file.

  ## Parameters

    - `file`: The path to the Erlang file.
    - `module_name`: The name of the module (as an atom).

  ## Returns

    - `{{line, start_column}, {line, end_column}}` if found.
    - `nil` if not found.
  """
  def find_module_range(file, module_name) do
    escaped =
      module_name
      |> Atom.to_string()
      |> Regex.escape()

    # Regex to capture the module name within -module(Name).
    # It allows optional whitespace around the module name.
    regex = ~r/^-module\(\s*(?<name>#{escaped})\s*\)\./u

    find_range_by_regex(file, regex)
  end

  @doc false
  # Generalized function to find the range of a captured group in a file based on a regex.
  defp find_range_by_regex(file, regex) do
    case File.read(file) do
      {:ok, content} ->
        content
        |> Source.split_lines()
        # Line numbers start at 1
        |> Enum.with_index(1)
        |> Enum.find_value(fn {line, line_number} ->
          # Use Regex.run with :index to get match positions
          case Regex.run(regex, line, return: :index, capture: :all_names) do
            [{name_start, name_length}] ->
              # Columns are 1-based
              start_column = name_start + 1
              end_column = name_start + 1 + name_length

              # Return the range as {{line, start}, {line, end}}
              {{line_number, start_column}, {line_number, end_column}}

            _ ->
              nil
          end
        end)

      {:error, reason} ->
        Logger.error("Error reading file: #{inspect(reason)}")
        nil
    end
  end
end
