defmodule ElixirLS.LanguageServer.Providers.InlayHints do
  @moduledoc false

  alias ElixirLS.LanguageServer.{Parser, SourceFile}
  alias ElixirSense.Core.{Binding, Metadata}
  alias ElixirSense.Core.State.VarInfo
  alias GenLSP.Enumerations.InlayHintKind
  alias GenLSP.Structures.{InlayHint, Position, Range}

  @max_range_lines 500
  @max_variables 200
  @max_label_length 40
  @max_shape_depth 3

  @type options :: [settings: map() | nil]

  @spec inlay_hints(%Parser.Context{}, Range.t(), options()) :: {:ok, list(InlayHint.t())}
  def inlay_hints(context, range, opts \\ [])

  def inlay_hints(%Parser.Context{metadata: nil}, _range, _opts), do: {:ok, []}

  def inlay_hints(%Parser.Context{} = context, %Range{} = range, opts) do
    settings = Keyword.get(opts, :settings) || %{}

    if variable_types_enabled?(settings) do
      {:ok, build_variable_hints(context, range, settings)}
    else
      {:ok, []}
    end
  end

  defp variable_types_enabled?(settings) when is_map(settings) do
    get_in(settings, ["inlayHints", "variableTypes", "enabled"]) |> default_true()
  end

  defp default_true(nil), do: true
  defp default_true(value), do: value

  defp build_variable_hints(%Parser.Context{} = context, %Range{} = range, _settings) do
    %{source_file: source_file, metadata: metadata} = context
    lines = SourceFile.lines(source_file)

    {range_start, range_end} = range_to_elixir(span(lines, range))

    if exceeds_line_budget?(range_start, range_end) do
      []
    else
      metadata
      |> variable_bindings_in_range(range_start, range_end)
      |> Enum.take(@max_variables)
      |> Enum.map(&variable_hint(&1, context, lines))
      |> Enum.filter(& &1)
    end
  end

  defp span(lines, %Range{start: start_pos, end: end_pos}) do
    start_elixir = SourceFile.lsp_position_to_elixir(lines, {start_pos.line, start_pos.character})
    end_elixir = SourceFile.lsp_position_to_elixir(lines, {end_pos.line, end_pos.character})
    {start_elixir, end_elixir}
  end

  defp range_to_elixir({{start_line, start_col}, {end_line, end_col}}) do
    start_col = start_col || 1
    end_col = end_col || 1
    {{start_line, start_col}, {end_line, end_col}}
  end

  defp exceeds_line_budget?({start_line, _}, {end_line, _}) do
    end_line - start_line > @max_range_lines
  end

  defp variable_bindings_in_range(%Metadata{vars_info_per_scope_id: vars}, range_start, range_end) do
    vars
    |> Map.values()
    |> Enum.flat_map(&Map.values/1)
    |> Enum.flat_map(&build_binding_entries(&1, range_start, range_end))
  end

  defp build_binding_entries(%VarInfo{name: name} = var_info, range_start, range_end) do
    cond do
      ignore_variable?(name) ->
        []

      true ->
        var_info.positions
        |> Enum.find(&binding_position?/1)
        |> case do
          nil ->
            []

          {_line, column} = position ->
            if column && in_range?(position, range_start, range_end) do
              [%{var_info: var_info, position: position}]
            else
              []
            end
        end
    end
  end

  defp binding_position?({line, column}) when is_integer(line) and is_integer(column), do: true
  defp binding_position?(_), do: false

  defp ignore_variable?(name) when is_atom(name) do
    string = Atom.to_string(name)
    string == "_" or String.starts_with?(string, "_")
  end

  defp ignore_variable?(_), do: true

  defp in_range?({line, column}, {start_line, start_col}, {end_line, end_col}) do
    cond do
      line < start_line -> false
      line > end_line -> false
      line == start_line and column < start_col -> false
      line == end_line and column > max(end_col, 1) -> false
      true -> true
    end
  end

  defp variable_hint(
         %{var_info: %VarInfo{name: name} = var_info, position: {line, column}},
         context,
         lines
       ) do
    metadata = context.metadata
    env = Metadata.get_env(metadata, {line, column})

    with {:env, env} when not is_nil(env) <- {:env, env},
         binding_env <- Binding.from_env(env, metadata, {line, column}),
         version <- var_info.version || :any,
         shape <- Binding.expand(binding_env, {:variable, name, version}),
         {:shape, label} when is_binary(label) <- {:shape, render_shape(shape)} do
      hint_position = variable_hint_position(lines, {line, column}, name)

      %InlayHint{
        position: hint_position,
        label: label,
        kind: InlayHintKind.type()
      }
    else
      _ -> nil
    end
  end

  defp variable_hint_position(lines, {line, column}, name) do
    token_length = name |> Atom.to_string() |> String.length()
    column_end = column + token_length

    {lsp_line, lsp_char} = SourceFile.elixir_position_to_lsp(lines, {line, column_end})

    %Position{line: lsp_line, character: lsp_char}
  end

  defp render_shape(shape), do: render_shape(shape, 0)

  defp render_shape(:none, _depth), do: nil
  defp render_shape(:no_spec, _depth), do: nil
  defp render_shape(nil, _depth), do: nil
  defp render_shape(:any, _depth), do: "any"
  defp render_shape({:atom, atom}, _depth) when is_atom(atom), do: truncated(inspect(atom))

  defp render_shape({:struct, _fields, {:atom, module}, _}, _depth) when is_atom(module) do
    truncated("%#{inspect(module)}{}")
  end

  defp render_shape({:struct, _fields, _module, _}, _depth), do: "struct"

  defp render_shape({:map, fields, _}, depth) do
    if depth >= @max_shape_depth do
      "%{}"
    else
      if Enum.empty?(fields) do
        "%{}"
      else
        "%{…}"
      end
    end
  end

  defp render_shape({:list, subtype}, depth) do
    rendered = render_shape(subtype, depth + 1) || "any"
    truncated("[#{rendered}]")
  end

  defp render_shape({:tuple, _size, elements}, depth) when is_list(elements) do
    if depth >= @max_shape_depth do
      "{…}"
    else
      inner =
        elements
        |> Enum.map(&(render_shape(&1, depth + 1) || "…"))
        |> Enum.join(", ")

      truncated("{#{inner}}")
    end
  end

  defp render_shape({:tuple, size, _elements}, _depth) when is_integer(size) do
    "{#{size}}"
  end

  defp render_shape({:union, members}, depth) when is_list(members) do
    members
    |> Enum.map(&render_shape(&1, depth + 1))
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
    |> case do
      [] ->
        nil

      items ->
        items
        |> Enum.take(3)
        |> Enum.join(" | ")
        |> maybe_append_ellipsis(length(items), length(members))
        |> truncated()
    end
  end

  defp render_shape({:binary, _}, _depth), do: "binary"
  defp render_shape({:integer, _}, _depth), do: "integer"
  defp render_shape({:float, _}, _depth), do: "float"
  defp render_shape({:fun, _}, _depth), do: "fun"

  defp render_shape(other, _depth) do
    cond do
      is_atom(other) -> truncated(Atom.to_string(other))
      true -> truncated(inspect(other))
    end
  end

  defp truncated(string) when byte_size(string) <= @max_label_length, do: string

  defp truncated(string) do
    string
    |> String.slice(0, @max_label_length - 1)
    |> Kernel.<>("…")
  end

  defp maybe_append_ellipsis(label, shown, total) when total > shown do
    truncated(label <> " | …")
  end

  defp maybe_append_ellipsis(label, _shown, _total), do: label
end
