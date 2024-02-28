defmodule ElixirLS.LanguageServer.Location do
  @moduledoc """
  A location in a source file or buffer
  """

  alias ElixirSense.Core.Metadata
  alias ElixirSense.Core.Parser
  alias ElixirSense.Core.Source
  alias ElixirSense.Core.State.ModFunInfo
  alias ElixirSense.Core.Normalized.Code, as: CodeNormalized
  require ElixirSense.Core.Introspection, as: Introspection

  @type t :: %__MODULE__{
          type: :module | :function | :variable | :typespec | :macro | :attribute,
          file: String.t() | nil,
          line: pos_integer,
          column: pos_integer
        }
  defstruct [:type, :file, :line, :column]

  @spec find_mod_fun_source(module, atom, non_neg_integer | {:gte, non_neg_integer} | :any) ::
          t() | nil
  def find_mod_fun_source(mod, fun, arity) do
    case find_mod_file(mod) do
      file when is_binary(file) ->
        find_fun_position({mod, file}, fun, arity)

      _ ->
        nil
    end
  end

  @spec find_type_source(module, atom, non_neg_integer | {:gte, non_neg_integer} | :any) ::
          t() | nil
  def find_type_source(mod, type, arity) do
    case find_mod_file(mod) do
      file when is_binary(file) ->
        find_type_position({mod, file}, type, arity)

      _ ->
        nil
    end
  end

  defp find_mod_file(Elixir), do: nil

  defp find_mod_file(module) do
    find_elixir_file(module) || find_erlang_file(module)
  end

  defp find_elixir_file(module) do
    file =
      if Code.ensure_loaded?(module) do
        case module.module_info(:compile)[:source] do
          nil -> nil
          source -> List.to_string(source)
        end
      end

    if file do
      if File.exists?(file, [:raw]) do
        file
      else
        # If Elixir was built in a sandboxed environment,
        # `module.module_info(:compile)[:source]` would point to a non-existing
        # location; in this case try to find a "core" Elixir source file under
        # the configured Elixir source path.
        with elixir_src when is_binary(elixir_src) <-
               Application.get_env(:elixir_sense, :elixir_src),
             file =
               String.replace(
                 file,
                 Regex.recompile!(~r<^(?:.+)(/lib/.+\.ex)$>U),
                 elixir_src <> "\\1"
               ),
             true <- File.exists?(file, [:raw]) do
          file
        else
          _ -> nil
        end
      end
    end
  end

  defp find_erlang_file(module) do
    with {_module, _binary, beam_filename} <- :code.get_object_code(module),
         erl_file =
           beam_filename
           |> to_string
           |> String.replace(
             Regex.recompile!(~r/(.+)\/ebin\/([^\s]+)\.beam$/),
             "\\1/src/\\2.erl"
           ),
         true <- File.exists?(erl_file, [:raw]) do
      erl_file
    else
      _ -> nil
    end
  end

  defp find_fun_position({mod, file}, fun, arity) do
    result =
      if String.ends_with?(file, ".erl") do
        # erlang function docs point to `-spec` instead of function
        # module docs point to the begin of a file
        # we get better results by regex
        # the downside is we don't handle arity well
        find_fun_position_in_erl_file(file, fun)
      else
        %Metadata{mods_funs_to_positions: mods_funs_to_positions} =
          Parser.parse_file(file, false, false, nil)

        case get_function_position_using_metadata(mod, fun, arity, mods_funs_to_positions) do
          %ModFunInfo{} = mi ->
            # assume function head or first clause is last in metadata
            {List.last(mi.positions), ModFunInfo.get_category(mi)}

          nil ->
            # not found in metadata, fall back to docs
            get_function_position_using_docs(mod, fun, arity)
        end
      end

    case result do
      {{line, column}, category} ->
        %__MODULE__{type: category, file: file, line: line, column: column}

      _ ->
        nil
    end
  end

  defp find_fun_position_in_erl_file(file, nil) do
    case find_line_by_regex(file, ~r/^-module/u) do
      nil -> nil
      position -> {position, :module}
    end
  end

  defp find_fun_position_in_erl_file(file, name) do
    escaped =
      name
      |> Atom.to_string()
      |> Regex.escape()

    case find_line_by_regex(file, ~r/^#{escaped}\b/u) do
      nil -> nil
      position -> {position, :function}
    end
  end

  defp find_type_position_in_erl_file(file, name) do
    escaped =
      name
      |> Atom.to_string()
      |> Regex.escape()

    find_line_by_regex(file, ~r/^-(typep?|opaque)\s#{escaped}\b/u)
  end

  defp find_line_by_regex(file, regex) do
    index =
      file
      |> File.read!()
      |> Source.split_lines()
      |> Enum.find_index(&String.match?(&1, regex))

    case index do
      nil -> nil
      i -> {i + 1, 1}
    end
  end

  defp find_type_position(_, nil, _), do: nil

  defp find_type_position({mod, file}, name, arity) do
    result =
      if String.ends_with?(file, ".erl") do
        find_type_position_in_erl_file(file, name)
      else
        file_metadata = Parser.parse_file(file, false, false, nil)
        get_type_position(file_metadata, mod, name, arity)
      end

    case result do
      {line, column} ->
        %__MODULE__{type: :typespec, file: file, line: line, column: column}

      _ ->
        nil
    end
  end

  defp get_function_position_using_docs(module, nil, _) do
    case CodeNormalized.fetch_docs(module) do
      {:error, _} ->
        nil

      {_, anno, _, _, _, _, _} ->
        line = :erl_anno.line(anno)

        line =
          if line == 0 do
            1
          else
            line
          end

        column = :erl_anno.column(anno)

        column =
          if column == :undefined do
            1
          else
            column
          end

        {{line, column}, :module}
    end
  end

  defp get_function_position_using_docs(module, function, arity) do
    case CodeNormalized.fetch_docs(module) do
      {:error, _} ->
        nil

      {_, _, _, _, _, _, docs} ->
        docs
        |> Enum.filter(fn
          {{category, ^function, doc_arity}, _line, _, _, meta}
          when category in [:function, :macro] ->
            default_args = Map.get(meta, :defaults, 0)
            Introspection.matches_arity_with_defaults?(doc_arity, default_args, arity)

          _ ->
            false
        end)
        |> Enum.map(fn
          {{category, _function, _arity}, line, _, _, _} when is_integer(line) ->
            {{line, 1}, category}

          {{category, _function, _arity}, keyword, _, _, _} when is_list(keyword) ->
            {{Keyword.get(keyword, :location, 1), 1}, category}
        end)
        |> Enum.min_by(fn {{line, 1}, _category} -> line end, &<=/2, fn -> nil end)
    end
  end

  def get_type_position(metadata, module, type, arity) do
    case get_type_position_using_metadata(module, type, arity, metadata.types) do
      nil ->
        get_type_position_using_docs(module, type, arity)

      %ElixirSense.Core.State.TypeInfo{positions: positions} ->
        List.last(positions)
    end
  end

  def get_type_position_using_docs(module, type_name, arity) do
    case CodeNormalized.fetch_docs(module) do
      {:error, _} ->
        nil

      {_, _, _, _, _, _, docs} ->
        docs
        |> Enum.filter(fn
          {{:type, ^type_name, doc_arity}, _line, _, _, _meta} ->
            Introspection.matches_arity?(doc_arity, arity)

          _ ->
            false
        end)
        |> Enum.map(fn
          {{_category, _function, _arity}, line, _, _, _} when is_integer(line) ->
            {line, 1}

          {{_category, _function, _arity}, keyword, _, _, _} when is_list(keyword) ->
            {Keyword.get(keyword, :location, 1), 1}
        end)
        |> Enum.min_by(fn {line, 1} -> line end, &<=/2, fn -> nil end)
    end
  end

  def get_function_position_using_metadata(
        mod,
        fun,
        call_arity,
        mods_funs_to_positions,
        predicate \\ fn _ -> true end
      )

  def get_function_position_using_metadata(
        mod,
        nil,
        _call_arity,
        mods_funs_to_positions,
        predicate
      ) do
    mods_funs_to_positions
    |> Enum.find_value(fn
      {{^mod, nil, nil}, fun_info} ->
        if predicate.(fun_info) do
          fun_info
        end

      _ ->
        false
    end)
  end

  def get_function_position_using_metadata(
        mod,
        fun,
        call_arity,
        mods_funs_to_positions,
        predicate
      ) do
    mods_funs_to_positions
    |> Enum.filter(fn
      {{^mod, ^fun, fn_arity}, fun_info} when not is_nil(fn_arity) ->
        # assume function head is first in code and last in metadata
        default_args = fun_info.params |> Enum.at(-1) |> Introspection.count_defaults()

        Introspection.matches_arity_with_defaults?(fn_arity, default_args, call_arity) and
          predicate.(fun_info)

      _ ->
        false
    end)
    |> min_by_line
  end

  def get_type_position_using_metadata(mod, fun, call_arity, types, predicate \\ fn _ -> true end) do
    types
    |> Enum.filter(fn
      {{^mod, ^fun, type_arity}, type_info}
      when not is_nil(type_arity) and Introspection.matches_arity?(type_arity, call_arity) ->
        predicate.(type_info)

      _ ->
        false
    end)
    |> min_by_line
  end

  defp min_by_line(list) do
    result =
      list
      |> Enum.min_by(
        fn {_, %{positions: positions}} ->
          positions |> List.last() |> elem(0)
        end,
        &<=/2,
        fn -> nil end
      )

    case result do
      {_, info} -> info
      nil -> nil
    end
  end
end
