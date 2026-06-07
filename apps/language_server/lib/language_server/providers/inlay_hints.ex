defmodule ElixirLS.LanguageServer.Providers.InlayHints do
  @moduledoc """
  Inlay hints for inferred variable types.

  Renders the inferred type of a variable just after its binding occurrence,
  e.g. `value = 42` shows `: 42`. Reads are not annotated unless
  `showOnlyBindings` is disabled.

  Type text is produced by `ElixirSense.Core.TypePresentation`, the LSP-facing
  type surface. It resolves the stored shape (`VarInfo.type`) through
  `ElixirSense.Core.Binding` (falling back to the native `Module.Types`
  descriptor), guarantees a thunk-free result, and suppresses uninformative
  `term()` / `none()` / unknown values. The provider does no type rendering of
  its own — it only positions hints and applies a max-length cap.
  """

  alias ElixirLS.LanguageServer.{Parser, SourceFile}
  alias ElixirSense.Core.{Binding, Metadata, TypePresentation}
  alias ElixirSense.Core.State.VarInfo
  alias GenLSP.Enumerations.InlayHintKind
  alias GenLSP.Structures.{InlayHint, Position, Range}

  @max_range_lines 1000
  @max_variables 500
  @default_max_label_length 60

  @type options :: [settings: map() | nil]

  @spec inlay_hints(%Parser.Context{}, Range.t(), options()) :: {:ok, list(InlayHint.t())}
  def inlay_hints(context, range, opts \\ [])

  def inlay_hints(%Parser.Context{metadata: nil}, _range, _opts), do: {:ok, []}

  def inlay_hints(%Parser.Context{} = context, %Range{} = range, opts) do
    config = config(Keyword.get(opts, :settings) || %{})

    if config.enabled do
      {:ok, build_variable_hints(context, range, config)}
    else
      {:ok, []}
    end
  end

  # --- settings: elixirLS.inlayHints.variableTypes.* ---

  defp config(settings) when is_map(settings) do
    base = get_in(settings, ["inlayHints", "variableTypes"]) || %{}

    %{
      enabled: bool(Map.get(base, "enabled"), true),
      show_only_bindings: bool(Map.get(base, "showOnlyBindings"), true),
      max_label_length: pos_int(Map.get(base, "maxLength"), @default_max_label_length)
    }
  end

  defp bool(value, _default) when is_boolean(value), do: value
  defp bool(_value, default), do: default

  defp pos_int(value, _default) when is_integer(value) and value > 0, do: value
  defp pos_int(_value, default), do: default

  # --- build ---

  defp build_variable_hints(
         %Parser.Context{source_file: source_file, metadata: metadata},
         %Range{} = range,
         config
       ) do
    lines = SourceFile.lines(source_file)
    {range_start, range_end} = elixir_range(lines, range)

    if exceeds_line_budget?(range_start, range_end) do
      []
    else
      metadata
      |> variables()
      |> Enum.flat_map(&occurrences(&1, config))
      |> Enum.filter(fn {pos, _var} -> in_range?(pos, range_start, range_end) end)
      |> Enum.uniq_by(fn {pos, _var} -> pos end)
      |> Enum.take(@max_variables)
      |> Enum.map(fn {pos, var} -> variable_hint(pos, var, metadata, lines, config) end)
      |> Enum.reject(&is_nil/1)
    end
  end

  defp variables(%Metadata{vars_info_per_scope_id: vars}) do
    vars |> Map.values() |> Enum.flat_map(&Map.values/1)
  end

  # The binding (write) occurrence is the head of `positions`; the tail are
  # reads (see ElixirSense.Core.Compiler.State.add_var_write/add_var_read). Each
  # destructured variable is its own VarInfo, so taking the binding of every
  # VarInfo annotates every bound name — including those bound inside patterns.
  defp occurrences(%VarInfo{name: name} = var, config) do
    cond do
      ignored?(name) -> []
      config.show_only_bindings -> Enum.map(binding_positions(var), &{&1, var})
      true -> var.positions |> Enum.filter(&position?/1) |> Enum.map(&{&1, var})
    end
  end

  defp binding_positions(%VarInfo{positions: positions}) do
    case Enum.find(positions, &position?/1) do
      nil -> []
      pos -> [pos]
    end
  end

  defp position?({line, column}) when is_integer(line) and is_integer(column), do: true
  defp position?(_), do: false

  defp ignored?(name) when is_atom(name) do
    string = Atom.to_string(name)
    string == "_" or String.starts_with?(string, "_")
  end

  defp ignored?(_), do: true

  defp variable_hint({line, column} = pos, %VarInfo{name: name} = var, metadata, lines, config) do
    with env when not is_nil(env) <- Metadata.get_env(metadata, pos),
         binding_env <- Binding.from_env(env, metadata, pos),
         {:ok, text} <- TypePresentation.render_hint(binding_env, var) do
      %InlayHint{
        position: hint_position(lines, line, column, name),
        label: ": " <> truncate(text, config.max_label_length),
        kind: InlayHintKind.type(),
        padding_left: false,
        padding_right: false
      }
    else
      _ -> nil
    end
  end

  defp hint_position(lines, line, column, name) do
    token_length = name |> Atom.to_string() |> String.length()
    {lsp_line, lsp_char} = SourceFile.elixir_position_to_lsp(lines, {line, column + token_length})
    %Position{line: lsp_line, character: lsp_char}
  end

  defp truncate(text, max) when byte_size(text) <= max, do: text
  defp truncate(text, max), do: String.slice(text, 0, max(max - 1, 0)) <> "…"

  # --- range helpers ---

  defp elixir_range(lines, %Range{start: start_pos, end: end_pos}) do
    {sl, sc} = SourceFile.lsp_position_to_elixir(lines, {start_pos.line, start_pos.character})
    {el, ec} = SourceFile.lsp_position_to_elixir(lines, {end_pos.line, end_pos.character})
    {{sl, sc || 1}, {el, ec || 1}}
  end

  defp exceeds_line_budget?({sl, _}, {el, _}), do: el - sl > @max_range_lines

  defp in_range?({line, column}, {sl, sc}, {el, ec}) do
    cond do
      line < sl -> false
      line > el -> false
      line == sl and column < sc -> false
      line == el and column > max(ec, 1) -> false
      true -> true
    end
  end
end
