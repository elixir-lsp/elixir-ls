defmodule ElixirLS.LanguageServer.Providers.InlayHints do
  @moduledoc """
  Inlay hints: inferred variable types and call parameter names.

  ## Variable type hints (`InlayHintKind.type`)

  The inferred type of a variable rendered just after its binding occurrence,
  e.g. `total = a + b` shows `: integer()`. Bindings whose RHS is a
  syntactically-obvious value (literal/struct/map/list/tuple/bitstring, e.g.
  `x = 1`, `m = %{…}`) are skipped — the type is already evident. Reads are not
  annotated unless `showOnlyBindings` is disabled. Type text is produced by
  `ElixirSense.Core.TypePresentation`, which resolves the stored shape through
  `Binding` (descriptor fallback), stays thunk-free, and suppresses
  uninformative `term()` / `none()` / unknown values.

  ## Call parameter-name hints (`InlayHintKind.parameter`)

  The parameter name rendered before each argument of a function call, e.g.
  `Map.put(map: m, key: :k, value: v)`. Calls are collected from the parsed AST
  (`Parser.Context.ast`); the MFA is resolved through
  `ElixirSense.Core.Introspection.actual_mod_fun/6` and parameter names come
  from `Metadata.get_function_signatures/3` (local) or
  `Introspection.get_signatures/2` (remote/stdlib). Per-argument columns are
  computed from the Elixir tokenizer (robust against strings/sigils/nesting and
  `fn`/`do` blocks). Pipes shift the parameter window by one. An argument is not
  annotated when its source text already matches the parameter name.
  """

  alias ElixirLS.LanguageServer.{Parser, SourceFile}
  alias ElixirSense.Core.{Binding, Introspection, Metadata, TypePresentation}
  alias ElixirSense.Core.State.VarInfo
  alias GenLSP.Enumerations.InlayHintKind
  alias GenLSP.Structures.{InlayHint, Position, Range}

  @max_range_lines 1000
  @max_hints 1000
  @default_max_label_length 60

  # Macros whose first argument is a definition head, not a call.
  @def_forms ~w(def defp defmacro defmacrop defguard defguardp defdelegate)a
  # Names that are special forms / operators rather than ordinary calls.
  @call_blocklist ~w(fn %{} {} <<>> __aliases__ __block__ |> = when :: % & @ and or not in
                     if unless case cond with for receive try quote unquote require import alias use)a
  @openers [:"(", :"[", :"{", :"<<", :fn, :do]
  @closers [:")", :"]", :"}", :">>", :end]

  @type options :: [settings: map() | nil]

  @spec inlay_hints(%Parser.Context{}, Range.t(), options()) :: {:ok, list(InlayHint.t())}
  def inlay_hints(context, range, opts \\ [])

  def inlay_hints(%Parser.Context{metadata: nil}, _range, _opts), do: {:ok, []}

  def inlay_hints(%Parser.Context{} = context, %Range{} = range, opts) do
    config = config(Keyword.get(opts, :settings) || %{})
    lines = SourceFile.lines(context.source_file)
    {range_start, range_end} = elixir_range(lines, range)

    if exceeds_line_budget?(range_start, range_end) do
      {:ok, []}
    else
      var_hints =
        if config.variable_types.enabled,
          do: variable_hints(context, lines, range_start, range_end, config.variable_types),
          else: []

      param_hints =
        if config.parameter_names.enabled,
          do: parameter_hints(context, lines, range_start, range_end),
          else: []

      hints =
        (var_hints ++ param_hints)
        |> Enum.sort_by(&{&1.position.line, &1.position.character})
        |> Enum.take(@max_hints)

      {:ok, hints}
    end
  end

  # --- settings: elixirLS.inlayHints.{variableTypes,parameterNames}.* ---

  defp config(settings) when is_map(settings) do
    var = get_in(settings, ["inlayHints", "variableTypes"]) || %{}
    param = get_in(settings, ["inlayHints", "parameterNames"]) || %{}

    %{
      variable_types: %{
        enabled: bool(Map.get(var, "enabled"), true),
        show_only_bindings: bool(Map.get(var, "showOnlyBindings"), true),
        max_label_length: pos_int(Map.get(var, "maxLength"), @default_max_label_length)
      },
      parameter_names: %{
        enabled: bool(Map.get(param, "enabled"), true)
      }
    }
  end

  defp bool(value, _default) when is_boolean(value), do: value
  defp bool(_value, default), do: default

  defp pos_int(value, _default) when is_integer(value) and value > 0, do: value
  defp pos_int(_value, default), do: default

  # ===========================================================================
  # Variable type hints
  # ===========================================================================

  defp variable_hints(
         %Parser.Context{ast: ast, metadata: metadata},
         lines,
         range_start,
         range_end,
         config
       ) do
    # Bindings whose RHS is a literal value or literal data constructor
    # (`x = 1`, `s = "foo"`, `t = {:ok, 1}`, `m = %{…}`, `l = […]`, `%S{…}`):
    # the type is already evident from the source, so the hint is noise.
    obvious = obvious_binding_positions(ast)

    metadata
    |> variables()
    |> Enum.flat_map(&occurrences(&1, config))
    |> Enum.filter(fn {pos, _var} -> in_range?(pos, range_start, range_end) end)
    |> Enum.reject(fn {pos, _var} -> MapSet.member?(obvious, pos) end)
    |> Enum.uniq_by(fn {pos, _var} -> pos end)
    |> Enum.map(fn {pos, var} -> variable_hint(pos, var, metadata, lines, config) end)
    |> Enum.reject(&is_nil/1)
  end

  defp variables(%Metadata{vars_info_per_scope_id: vars}) do
    vars |> Map.values() |> Enum.flat_map(&Map.values/1)
  end

  # Positions of variables bound by a `pattern = rhs` match where `rhs` is a
  # syntactically-obvious value (literal/struct/map/list/tuple/bitstring). Other
  # bindings (calls, operators, `fn`, vars, control-flow) keep their hint.
  defp obvious_binding_positions(nil), do: MapSet.new()

  defp obvious_binding_positions(ast) do
    {_ast, positions} =
      Macro.prewalk(ast, MapSet.new(), fn
        {:=, _meta, [lhs, rhs]} = node, acc ->
          if obvious_value?(rhs), do: {node, pattern_var_positions(lhs, acc)}, else: {node, acc}

        node, acc ->
          {node, acc}
      end)

    positions
  end

  # A chained match (`a = b = 1`) propagates the inner rhs.
  defp obvious_value?({:=, _meta, [_lhs, inner]}), do: obvious_value?(inner)
  defp obvious_value?({:%{}, _meta, _}), do: true
  defp obvious_value?({:%, _meta, _}), do: true
  defp obvious_value?({:{}, _meta, _}), do: true
  defp obvious_value?({:<<>>, _meta, _}), do: true
  # Any other 3-tuple is a call / var / operator / control-flow — keep its hint.
  defp obvious_value?({_, _meta, _}), do: false
  defp obvious_value?(value) when is_list(value), do: true
  defp obvious_value?(value) when is_tuple(value) and tuple_size(value) == 2, do: true

  defp obvious_value?(value)
       when is_integer(value) or is_float(value) or is_binary(value) or is_atom(value),
       do: true

  defp obvious_value?(_other), do: false

  defp pattern_var_positions(pattern, acc) do
    {_p, positions} =
      Macro.prewalk(pattern, acc, fn
        {name, meta, ctx} = node, acc when is_atom(name) and (is_nil(ctx) or is_atom(ctx)) ->
          if ignored?(name) do
            {node, acc}
          else
            case meta_position(meta) do
              {_l, _c} = pos -> {node, MapSet.put(acc, pos)}
              _ -> {node, acc}
            end
          end

        node, acc ->
          {node, acc}
      end)

    positions
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

  defp ignored?(name) when is_atom(name) do
    string = Atom.to_string(name)
    string == "_" or String.starts_with?(string, "_")
  end

  defp ignored?(_), do: true

  defp variable_hint({line, column} = pos, %VarInfo{name: name} = var, metadata, lines, config) do
    with env when not is_nil(env) <- Metadata.get_env(metadata, pos),
         binding_env <- Binding.from_env(env, metadata, pos),
         {:ok, text} <- TypePresentation.render_hint(binding_env, var) do
      token_length = name |> Atom.to_string() |> String.length()

      %InlayHint{
        position: lsp_position(lines, line, column + token_length),
        label: ": " <> truncate(text, config.max_label_length),
        kind: InlayHintKind.type(),
        padding_left: false,
        padding_right: false
      }
    else
      _ -> nil
    end
  end

  defp truncate(text, max) when byte_size(text) <= max, do: text
  defp truncate(text, max), do: String.slice(text, 0, max(max - 1, 0)) <> "…"

  # ===========================================================================
  # Call parameter-name hints
  # ===========================================================================

  defp parameter_hints(%Parser.Context{ast: nil}, _lines, _rs, _re), do: []

  defp parameter_hints(
         %Parser.Context{ast: ast, metadata: metadata, source_file: source_file},
         lines,
         rs,
         re
       ) do
    tokens = tokenize(source_file.text)

    if tokens == [] do
      []
    else
      def_positions = positions(ast, &def_head_position/1)
      piped = positions(ast, &piped_call_position/1)

      ast
      |> collect_calls(def_positions)
      |> Enum.filter(&relevant_call?(&1, rs, re))
      |> Enum.map(&safe_resolve(&1, metadata, piped))
      |> Enum.reject(&is_nil/1)
      |> Enum.flat_map(&call_hints(&1, tokens, lines, rs, re))
    end
  end

  # Keep only calls whose source span (function name .. closing paren) intersects
  # the requested line range, so we don't introspect/tokenize the whole file for
  # a small viewport request.
  defp relevant_call?({_kind, _mod, _fun, {pl, _pc}, closing, _arity}, {rsl, _}, {rel, _}) do
    cl =
      case closing do
        {l, _} -> l
        _ -> pl
      end

    pl <= rel and cl >= rsl
  end

  # Resolving a call introspects arbitrary modules; isolate failures so one bad
  # call (e.g. an exotic receiver) can never crash the whole inlay-hint request.
  defp safe_resolve(call, metadata, piped) do
    resolve_call(call, metadata, piped)
  rescue
    _ -> nil
  catch
    _, _ -> nil
  end

  defp positions(ast, fun) do
    {_ast, acc} =
      Macro.prewalk(ast, MapSet.new(), fn node, acc ->
        case fun.(node) do
          nil -> {node, acc}
          pos -> {node, MapSet.put(acc, pos)}
        end
      end)

    acc
  end

  defp def_head_position({form, _meta, [head | _]}) when form in @def_forms,
    do: head_position(head)

  defp def_head_position(_node), do: nil

  defp head_position({:when, _meta, [inner | _]}), do: head_position(inner)

  defp head_position({name, meta, args}) when is_atom(name) and is_list(args),
    do: meta_position(meta)

  defp head_position(_other), do: nil

  defp piped_call_position({:|>, _meta, [_lhs, {name, meta, args}]})
       when is_atom(name) and is_list(args),
       do: meta_position(meta)

  defp piped_call_position({:|>, _meta, [_lhs, {{:., _dm, _mf}, meta, args}]}) when is_list(args),
    do: meta_position(meta)

  defp piped_call_position(_node), do: nil

  defp collect_calls(ast, def_positions) do
    {_ast, acc} =
      Macro.prewalk(ast, [], fn
        {{:., _dm, [mod_ast, fun]}, meta, args} = node, acc when is_atom(fun) and is_list(args) ->
          {node, maybe_call(acc, :remote, mod_ast, fun, meta, args, def_positions)}

        {fun, meta, args} = node, acc when is_atom(fun) and is_list(args) ->
          {node, maybe_call(acc, :local, nil, fun, meta, args, def_positions)}

        node, acc ->
          {node, acc}
      end)

    Enum.reverse(acc)
  end

  defp maybe_call(acc, kind, mod_ast, fun, meta, args, def_positions) do
    pos = meta_position(meta)

    cond do
      fun in @call_blocklist -> acc
      not Keyword.has_key?(meta, :closing) -> acc
      args == [] -> acc
      pos == nil -> acc
      MapSet.member?(def_positions, pos) -> acc
      true -> [{kind, mod_ast, fun, pos, meta_position(meta[:closing]), length(args)} | acc]
    end
  end

  defp resolve_call({kind, mod_ast, fun, pos, closing, arity}, metadata, piped) do
    piped? = MapSet.member?(piped, pos)
    effective_arity = if piped?, do: arity + 1, else: arity
    raw_mod = if kind == :remote, do: module_of(mod_ast), else: nil
    expand_aliases? = match?({:__aliases__, _, _}, mod_ast)

    with true <- raw_mod != :error,
         env when not is_nil(env) <- Metadata.get_env(metadata, pos),
         {resolved_mod, resolved_fun, true, :mod_fun} <-
           Introspection.actual_mod_fun(
             {raw_mod, fun},
             env,
             metadata.mods_funs_to_positions,
             metadata.types,
             pos,
             expand_aliases?
           ),
         false <- resolved_mod == Kernel.SpecialForms,
         names when is_list(names) <-
           parameter_names(metadata, resolved_mod, resolved_fun, effective_arity) do
      names = if piped?, do: Enum.drop(names, 1), else: names
      if length(names) == arity, do: {closing, names}, else: nil
    else
      _ -> nil
    end
  end

  defp parameter_names(metadata, mod, fun, arity) do
    signatures =
      case Metadata.get_function_signatures(metadata, mod, fun) do
        [] -> Introspection.get_signatures(mod, fun)
        signatures -> signatures
      end

    signature =
      Enum.find(signatures, fn %{params: params} ->
        required = Enum.count(params, &(not String.contains?(&1, "\\\\")))
        required <= arity and arity <= length(params)
      end)

    case signature do
      nil -> nil
      %{params: params} -> params |> Enum.take(arity) |> Enum.map(&clean_param_name/1)
    end
  end

  defp clean_param_name(param) do
    param |> String.split(" \\\\ ") |> hd() |> String.trim()
  end

  # Only resolve statically-known remote modules. Dynamic receivers (variables,
  # calls, attributes — `mod.put(...)`, `factory().call(...)`) yield `:error` so
  # the call is skipped rather than passing raw AST into introspection (which
  # would reach `Code.ensure_loaded/1` and raise).
  defp module_of({:__aliases__, _meta, parts}), do: Module.concat(parts)
  defp module_of(mod) when is_atom(mod), do: mod
  defp module_of(_dynamic), do: :error

  # Build per-argument hints by locating the call's argument tokens (between the
  # matching `(` and the `closing` `)`) and splitting them on top-level commas.
  defp call_hints({closing, names}, tokens, lines, rs, re) do
    case argument_segments(tokens, closing) do
      {:ok, segments} ->
        segments
        |> Enum.zip(names)
        |> Enum.flat_map(fn {segment, name} -> parameter_hint(segment, name, lines, rs, re) end)

      :error ->
        []
    end
  end

  defp parameter_hint(segment, name, lines, rs, re) do
    with {line, column} <- segment_start(segment),
         true <- in_range?({line, column}, rs, re),
         true <- clean_identifier?(name),
         false <- single_identifier_equal?(segment, name) do
      [
        %InlayHint{
          position: lsp_position(lines, line, column),
          label: name <> ":",
          kind: InlayHintKind.parameter(),
          padding_left: false,
          padding_right: true
        }
      ]
    else
      _ -> []
    end
  end

  defp clean_identifier?(name), do: Regex.match?(~r/^[a-z][a-zA-Z0-9_]*[?!]?$/, name)

  defp single_identifier_equal?([{:identifier, _pos, value}], name) when is_atom(value),
    do: Atom.to_string(value) == name

  defp single_identifier_equal?(_segment, _name), do: false

  defp segment_start([token | _]), do: token_position(token)
  defp segment_start([]), do: nil

  defp argument_segments(tokens, closing) do
    indexed = Enum.with_index(tokens)

    close_index =
      Enum.find_value(indexed, fn {token, index} ->
        if token_type(token) == :")" and token_position(token) == closing, do: index
      end)

    with index when is_integer(index) <- close_index,
         open_index when is_integer(open_index) <- matching_open(tokens, index) do
      inner = Enum.slice(tokens, (open_index + 1)..(index - 1)//1)
      {:ok, split_arguments(inner)}
    else
      _ -> :error
    end
  end

  defp matching_open(tokens, close_index) do
    Enum.reduce_while((close_index - 1)..0//-1, 0, fn index, depth ->
      token = Enum.at(tokens, index)
      type = token_type(token)

      cond do
        type in @closers -> {:cont, depth + 1}
        type == :"(" and depth == 0 -> {:halt, {:found, index}}
        type in @openers -> {:cont, depth - 1}
        true -> {:cont, depth}
      end
    end)
    |> case do
      {:found, index} -> index
      _ -> nil
    end
  end

  defp split_arguments(tokens) do
    {segments, current, _depth} =
      Enum.reduce(tokens, {[], [], 0}, fn token, {segments, current, depth} ->
        type = token_type(token)

        cond do
          type == :"," and depth == 0 -> {segments ++ [Enum.reverse(current)], [], depth}
          type in @openers -> {segments, [token | current], depth + 1}
          type in @closers -> {segments, [token | current], depth - 1}
          true -> {segments, [token | current], depth}
        end
      end)

    (segments ++ [Enum.reverse(current)]) |> Enum.reject(&(&1 == []))
  end

  defp tokenize(text) do
    case :elixir_tokenizer.tokenize(String.to_charlist(text), 1, 1, []) do
      {:ok, _, _, _, tokens, _} -> Enum.reverse(tokens)
      {:ok, _, _, _, tokens} -> Enum.reverse(tokens)
      {:ok, _, _, tokens} -> Enum.reverse(tokens)
      _ -> []
    end
  rescue
    _ -> []
  catch
    _, _ -> []
  end

  defp token_type(token), do: elem(token, 0)

  defp token_position(token) do
    case elem(token, 1) do
      {line, column, _} -> {line, column}
      {line, column} -> {line, column}
      _ -> nil
    end
  end

  # ===========================================================================
  # Shared helpers
  # ===========================================================================

  defp meta_position(nil), do: nil

  defp meta_position(meta) when is_list(meta) do
    case {meta[:line], meta[:column]} do
      {line, column} when is_integer(line) and is_integer(column) -> {line, column}
      _ -> nil
    end
  end

  defp position?({line, column}) when is_integer(line) and is_integer(column), do: true
  defp position?(_), do: false

  defp lsp_position(lines, elixir_line, elixir_column) do
    {lsp_line, lsp_char} = SourceFile.elixir_position_to_lsp(lines, {elixir_line, elixir_column})
    %Position{line: lsp_line, character: lsp_char}
  end

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
