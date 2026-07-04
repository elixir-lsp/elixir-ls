defmodule ElixirLS.LanguageServer.Providers.InlayHints do
  @moduledoc """
  Inlay hints: inferred variable types and call parameter names.

  ## Variable type hints (`InlayHintKind.type`)

  The inferred type of a variable rendered just after its binding occurrence,
  e.g. `total = a + b` shows `: integer()`. A binding is skipped when *either*
  side of its match is a syntactically-obvious value
  (literal/struct/map/list/tuple/bitstring) — `x = 1`, `m = %{…}`, or
  `%User{} = user` — since the type is then already evident from the source.
  Reads are not annotated unless `showOnlyBindings` is disabled. Type text is
  produced by `ElixirSense.Core.TypeHints.type_hint_for_var/4`, the stable
  LSP-facing facade that owns env/binding assembly, rendering policy
  (suppression of uninformative `term()` / `none()` / unknown values), and the
  per-request caching — this provider no longer touches `Binding` or
  `TypePresentation` directly.

  ## Call parameter-name hints (`InlayHintKind.parameter`)

  The parameter name rendered before each argument of a function call, e.g.
  `Map.put(map: m, key: :k, value: v)`. Calls are collected from the parsed AST
  (`Parser.Context.ast`); the MFA is resolved through
  `ElixirSense.Core.Introspection.actual_mod_fun/6` and structured parameter
  names come from `ElixirSense.Core.TypeHints.effective_params/4` (AST-level for
  metadata modules, signature-string fallback for remote/stdlib, both already
  default-elided for the concrete arity). Per-argument columns are
  computed from the Elixir tokenizer (robust against strings/sigils/nesting and
  `fn`/`do` blocks). Pipes shift the parameter window by one. An argument is not
  annotated when its source text already matches the parameter name.
  """

  require Logger

  alias ElixirLS.LanguageServer.{Parser, SourceFile}
  alias ElixirSense.Core.{Introspection, Metadata}
  alias ElixirSense.Core.ElixirTypes
  alias ElixirSense.Core.ModuleResolver
  alias ElixirSense.Core.State.VarInfo
  alias ElixirSense.Core.TypeHints
  alias GenLSP.Enumerations.InlayHintKind
  alias GenLSP.Structures.{InlayHint, Position, Range}

  # Key used to ensure the backend-status log is emitted only once per VM lifetime.
  @backend_status_key {__MODULE__, :backend_status_logged}

  # Key prefix used to ensure unrecognized minimumTrust value warnings are logged once per value per VM.
  @unrecognized_trust_key_prefix {__MODULE__, :unrecognized_trust}

  @max_range_lines 1000
  # Whole-line sentinel end column used when clamp_range trims a range: large
  # enough to exceed any realistic line length, so the clamped boundary line
  # is fully covered.
  @max_line_column 1_000_000
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
    maybe_log_backend_status()
    config = config(Keyword.get(opts, :settings) || %{})
    lines = SourceFile.lines(context.source_file)
    # Clamp the requested range to the first @max_range_lines so whole-document
    # clients (Neovim/helix/emacs) on large files still get hints for the
    # clamped window instead of nothing.
    {range_start, range_end} = clamp_range(elixir_range(lines, range))

    # One per-request context (request-scoped, process-dictionary caches inside
    # the facade). Built once here, in the request process, and threaded into
    # both hint paths.
    ctx = TypeHints.request_context(context.metadata)

    var_hints =
      if config.variable_types.enabled,
        do: variable_hints(ctx, context, lines, range_start, range_end, config.variable_types),
        else: []

    param_hints =
      if config.parameter_names.enabled,
        do: parameter_hints(ctx, context, lines, range_start, range_end),
        else: []

    hints =
      (var_hints ++ param_hints)
      |> Enum.sort_by(&{&1.position.line, &1.position.character})
      |> Enum.take(@max_hints)

    {:ok, hints}
  end

  # --- settings: elixirLS.inlayHints.{variableTypes,parameterNames}.* ---

  defp config(settings) when is_map(settings) do
    var = get_in(settings, ["inlayHints", "variableTypes"]) || %{}
    param = get_in(settings, ["inlayHints", "parameterNames"]) || %{}

    minimum_trust_value = trust(Map.get(var, "minimumTrust"))

    %{
      variable_types: %{
        enabled: bool(Map.get(var, "enabled"), true),
        show_only_bindings: bool(Map.get(var, "showOnlyBindings"), true),
        max_label_length: pos_int(Map.get(var, "maxLength"), @default_max_label_length),
        minimum_trust: minimum_trust_value,
        minimum_rank:
          try do
            TypeHints.trust_rank(minimum_trust_value)
          rescue
            _ -> 3
          end
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

  # minimumTrust setting → the minimum source atom used as the trust threshold.
  # trust_rank(hint.source) <= trust_rank(minimum_source) → keep hint.
  #
  # "compiler"   → admit only :native_exck (ExCk compiler-verified)
  # "native"     → admit :native_exck and :native_inferred (any native-engine result)
  # "bestEffort" → admit everything (default)
  #
  # We store the *minimum acceptable source* (the weakest source that still passes).
  # Unrecognized non-nil values (e.g. "strict") log a warning (once per VM) and fall back to :shape (bestEffort).
  defp trust("compiler"), do: :native_exck
  defp trust("native"), do: :native_inferred
  defp trust("bestEffort"), do: :shape
  defp trust(nil), do: :shape

  defp trust(value) when is_binary(value) do
    maybe_log_unrecognized_trust(value)
    :shape
  end

  defp trust(_other), do: :shape

  # Log a warning once per unique unrecognized minimumTrust value, using :persistent_term
  # to track which values have been warned about (mirroring maybe_log_backend_status).
  defp maybe_log_unrecognized_trust(value) do
    key = {@unrecognized_trust_key_prefix, value}

    case :persistent_term.get(key, :not_logged) do
      :logged ->
        :ok

      :not_logged ->
        :persistent_term.put(key, :logged)

        Logger.warning(
          "[ElixirLS.InlayHints] unrecognized minimumTrust setting: \"#{value}\". " <>
            "Valid values are: \"compiler\", \"native\", \"bestEffort\" (default). " <>
            "Using bestEffort."
        )
    end
  end

  # Emit exactly one Logger.info line (per VM lifetime) describing the active
  # type backend. Stored via :persistent_term so it survives module reloads and
  # works in async test environments without a GenServer.
  defp maybe_log_backend_status do
    case :persistent_term.get(@backend_status_key, :not_logged) do
      :logged ->
        :ok

      :not_logged ->
        :persistent_term.put(@backend_status_key, :logged)

        # Check availability before the enabled setting: enabled?/0 already
        # includes available?/0, so testing `not enabled?` first would report
        # "disabled" on Elixirs where native typing simply isn't available.
        backend =
          cond do
            not ElixirTypes.available?() ->
              "structural (native typing unavailable on this Elixir)"

            not ElixirTypes.enabled?() ->
              "structural (native typing disabled)"

            true ->
              "compiler-native (Module.Types adaptor active)"
          end

        Logger.info("[ElixirLS.InlayHints] type backend: #{backend}")
    end
  end

  # ===========================================================================
  # Variable type hints
  # ===========================================================================

  defp variable_hints(
         ctx,
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
    |> Enum.map(fn {pos, occurrence} -> variable_hint(ctx, pos, occurrence, lines, config) end)
    |> Enum.reject(&is_nil/1)
  end

  defp variables(%Metadata{vars_info_per_scope_id: vars}) do
    vars |> Map.values() |> Enum.flat_map(&Map.values/1)
  end

  # Positions of variables bound by a match `left = right` where the *other*
  # side is a syntactically-obvious value (literal/struct/map/list/tuple/
  # bitstring) — `=` is a match, so the obvious side can be the RHS (`x = 1`,
  # `t = {:ok, 1}`) or the LHS (`%User{} = user`). The variable's type is then
  # evident from the source. Bindings against calls, operators, `fn`, other
  # vars, or control-flow keep their hint. (Collecting variables from the value
  # side too is harmless: those occurrences are reads, whose binding positions
  # live elsewhere.)
  defp obvious_binding_positions(nil), do: MapSet.new()

  defp obvious_binding_positions(ast) do
    {_ast, positions} =
      Macro.prewalk(ast, MapSet.new(), fn
        {:=, _meta, [lhs, rhs]} = node, acc ->
          acc = if obvious_value?(rhs), do: pattern_var_positions(lhs, acc), else: acc
          acc = if obvious_value?(lhs), do: pattern_var_positions(rhs, acc), else: acc
          {node, acc}

        node, acc ->
          {node, acc}
      end)

    positions
  end

  # A value is "obvious" only when ALL of its leaves are literals: the type is
  # then fully evident from the source. A constructor with a variable or call
  # element (`{:ok, compute()}`) is NOT obvious — the interesting type is the
  # element's, which the source does not reveal — so its hint is kept.

  # A chained match (`a = b = 1`) propagates the inner rhs.
  defp obvious_value?({:=, _meta, [_lhs, inner]}), do: obvious_value?(inner)
  # Map / struct constructor: obvious iff every key and value is obvious.
  defp obvious_value?({:%{}, _meta, pairs}), do: Enum.all?(pairs, &obvious_value?/1)

  # Struct: the name is an alias (`%URI{}`, `%__MODULE__{}`) — judge only the
  # field values. A struct with all-literal (or no) fields is obvious.
  defp obvious_value?({:%, _meta, [_name, {:%{}, _, pairs}]}),
    do: Enum.all?(pairs, &obvious_value?/1)

  # Tuple constructor (3+ elements): obvious iff every element is obvious.
  defp obvious_value?({:{}, _meta, elements}), do: Enum.all?(elements, &obvious_value?/1)
  # Bitstring: obvious iff every segment is obvious.
  defp obvious_value?({:<<>>, _meta, segments}), do: Enum.all?(segments, &obvious_value?/1)
  # A `::` segment spec inside a bitstring — judge by the value being encoded.
  defp obvious_value?({:"::", _meta, [value, _spec]}), do: obvious_value?(value)
  # Charlist/string sigils without interpolation render as `{:sigil_*, _, [{:<<>>,
  # _, [literal]}, []]}`; interpolation injects a non-literal `<<>>` segment.
  defp obvious_value?({sigil, _meta, [arg, mods]})
       when is_atom(sigil) and is_list(mods) do
    case Atom.to_string(sigil) do
      "sigil_" <> _ -> obvious_value?(arg)
      _ -> false
    end
  end

  # Any other 3-tuple is a call / var / operator / control-flow — not obvious.
  defp obvious_value?({_, _meta, _}), do: false
  # A literal 2-tuple `{a, b}` (AST keeps these as raw tuples).
  defp obvious_value?({a, b}), do: obvious_value?(a) and obvious_value?(b)
  # A literal list / keyword list: obvious iff every element is obvious.
  defp obvious_value?(value) when is_list(value), do: Enum.all?(value, &obvious_value?/1)

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
  #
  # When `show_only_bindings` is true (default), every occurrence is tagged
  # `{:binding, var}` — only binding positions are emitted and `variable_hint`
  # calls `type_hint_for_var` with the VarInfo.
  #
  # When `show_only_bindings` is false, binding positions are tagged
  # `{:binding, var}` (same path as above) and read positions are tagged
  # `{:read, var_name}` so `variable_hint` can call `type_hint_at` to get the
  # flow-sensitive (narrowed) type at each read site.
  defp occurrences(%VarInfo{name: name} = var, config) do
    if ignored?(name) do
      []
    else
      binding_occs = Enum.map(binding_positions(var), &{&1, {:binding, var}})

      if config.show_only_bindings do
        binding_occs
      else
        binding_pos_set = binding_positions(var) |> MapSet.new()

        read_occs =
          var.positions
          |> Enum.filter(&position?/1)
          |> Enum.reject(&MapSet.member?(binding_pos_set, &1))
          |> Enum.map(&{&1, {:read, name}})

        binding_occs ++ read_occs
      end
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

  # Binding occurrence: use type_hint_for_var with the VarInfo from the binding
  # site (carries binding-type and source attribution).
  defp variable_hint(
         ctx,
         {line, column} = pos,
         {:binding, %VarInfo{name: name} = var},
         lines,
         config
       ) do
    with {:ok, %{label: label, full: full, source: source}} <-
           TypeHints.type_hint_for_var(ctx, pos, var, max_length: config.max_label_length),
         # Keep hint when trust_rank(source) <= trust_rank(minimum acceptable source).
         # Unrecognised future source atoms (not yet in TypeHints.trust_rank/1) are
         # treated as the weakest rank (safe fallback: shown in bestEffort, hidden in
         # stricter modes). The minimum_rank is computed once in config/1, so use it directly.
         source_rank =
           (try do
              TypeHints.trust_rank(source)
            rescue
              _ -> 3
            end),
         true <- source_rank <= config.minimum_rank do
      # The tokenizer column is a codepoint offset, so advance by the
      # identifier's codepoint count (not graphemes) before the UTF-16
      # conversion in lsp_position/3.
      token_length = name |> Atom.to_string() |> String.to_charlist() |> length()

      %InlayHint{
        position: lsp_position(lines, line, column + token_length),
        label: ": " <> label,
        # When elided, surface the untruncated type as the hover tooltip.
        tooltip: if(full != label, do: full),
        kind: InlayHintKind.type(),
        padding_left: false,
        padding_right: false
      }
    else
      _ -> nil
    end
  end

  # Read occurrence: use type_hint_at to get the flow-sensitive (narrowed) type
  # at the read position. Obvious-value suppression does not apply to reads
  # (no RHS to inspect). minimumTrust filtering applies identically.
  defp variable_hint(ctx, {line, column} = pos, {:read, name}, lines, config) do
    with {:ok, %{label: label, full: full, source: source}} <-
           TypeHints.type_hint_at(ctx, pos, name, max_length: config.max_label_length),
         source_rank =
           (try do
              TypeHints.trust_rank(source)
            rescue
              _ -> 3
            end),
         true <- source_rank <= config.minimum_rank do
      token_length = name |> Atom.to_string() |> String.to_charlist() |> length()

      %InlayHint{
        position: lsp_position(lines, line, column + token_length),
        label: ": " <> label,
        tooltip: if(full != label, do: full),
        kind: InlayHintKind.type(),
        padding_left: false,
        padding_right: false
      }
    else
      _ -> nil
    end
  end

  # ===========================================================================
  # Call parameter-name hints
  # ===========================================================================

  defp parameter_hints(_ctx, %Parser.Context{ast: nil}, _lines, _rs, _re), do: []

  defp parameter_hints(
         ctx,
         %Parser.Context{ast: ast, metadata: metadata, source_file: source_file},
         lines,
         rs,
         re
       ) do
    tokens = tokenize(source_file.text)

    if tokens == [] do
      []
    else
      # Tokenize once per request and precompute an O(1) token index so each
      # call's argument span is located without re-scanning the whole token
      # list (was O(n²): `Enum.with_index` per call + `Enum.at` per step).
      index = token_index(tokens)
      def_positions = positions(ast, &def_head_position/1)
      piped = positions(ast, &piped_call_position/1)

      ast
      |> collect_calls(def_positions)
      |> Enum.filter(&relevant_call?(&1, rs, re))
      |> Enum.map(&safe_resolve(ctx, &1, metadata, piped))
      |> Enum.reject(&is_nil/1)
      |> Enum.flat_map(&call_hints(&1, index, lines, rs, re))
    end
  end

  # An O(1)-access view over the token list, built once per request:
  #   * `tuple` — `elem/2` access by index
  #   * `close_for_position` — closing-`)` token position -> its token index
  #   * `open_for_close` — closing-delimiter index -> matching opening index
  defp token_index(tokens) do
    tuple = List.to_tuple(tokens)

    {close_for_position, open_for_close, _stack} =
      tokens
      |> Enum.with_index()
      |> Enum.reduce({%{}, %{}, []}, fn {token, index}, {by_pos, pairs, stack} ->
        type = token_type(token)

        cond do
          type in @openers ->
            {by_pos, pairs, [index | stack]}

          type in @closers ->
            {pairs, stack} =
              case stack do
                [open | rest] -> {Map.put(pairs, index, open), rest}
                [] -> {pairs, []}
              end

            by_pos =
              if type == :")" do
                Map.put(by_pos, token_position(token), index)
              else
                by_pos
              end

            {by_pos, pairs, stack}

          true ->
            {by_pos, pairs, stack}
        end
      end)

    %{tuple: tuple, close_for_position: close_for_position, open_for_close: open_for_close}
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
  defp safe_resolve(ctx, call, metadata, piped) do
    resolve_call(ctx, call, metadata, piped)
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
      # The blocklist names special forms / operators, which only occur as LOCAL
      # calls. A remote call like `MyMod.alias(x)` is an ordinary function and
      # must not be suppressed.
      kind == :local and fun in @call_blocklist -> acc
      not Keyword.has_key?(meta, :closing) -> acc
      args == [] -> acc
      pos == nil -> acc
      MapSet.member?(def_positions, pos) -> acc
      true -> [{kind, mod_ast, fun, pos, meta_position(meta[:closing]), length(args)} | acc]
    end
  end

  defp resolve_call(ctx, {kind, mod_ast, fun, pos, closing, arity}, metadata, piped) do
    piped? = MapSet.member?(piped, pos)
    effective_arity = if piped?, do: arity + 1, else: arity
    expand_aliases? = match?({:__aliases__, _, _}, mod_ast)

    with env when not is_nil(env) <- Metadata.get_env(metadata, pos),
         raw_mod = if(kind == :remote, do: module_of(mod_ast, env), else: nil),
         true <- raw_mod != :error,
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
           parameter_names(ctx, resolved_mod, resolved_fun, effective_arity) do
      names = if piped?, do: Enum.drop(names, 1), else: names
      if length(names) == arity, do: {closing, names}, else: nil
    else
      _ -> nil
    end
  end

  # Structured params for the resolved MFA come from the facade (AST-level for
  # metadata modules, signature-string fallback for remote/stdlib, both already
  # default-elided for the concrete arity). Each entry is
  # `%{name: String.t() | nil, has_default: boolean()}`; we keep the name (or
  # nil) per position so `clean_identifier?` downstream can drop non-identifier
  # params (literals, struct-only patterns).
  defp parameter_names(ctx, mod, fun, arity) do
    case TypeHints.effective_params(ctx, mod, fun, arity) do
      {:ok, params} -> Enum.map(params, fn %{name: name} -> name end)
      :error -> nil
    end
  end

  # Only resolve statically-known remote modules. Dynamic receivers (variables,
  # calls, attributes — `mod.put(...)`, `factory().call(...)`) yield `:error` so
  # the call is skipped rather than passing raw AST into introspection (which
  # would reach `Code.ensure_loaded/1` and raise).
  # Delegates to `ModuleResolver.resolve/2` so that alias expansion (e.g.
  # `alias Foo.Bar` then `Bar.f(x)` → `Foo.Bar`) is handled correctly.
  # Dynamic / attribute / variable receivers are not handled by ModuleResolver
  # and it returns `:error`, which propagates to skip the call gracefully.
  defp module_of(ast, env) do
    # Pass a plain map (not the %State.Env{} struct) — ModuleResolver.resolve/2's
    # env type is an anonymous map, and a struct is not a subtype of it (dialyzer).
    case ModuleResolver.resolve(ast, %{module: env.module, aliases: env.aliases}) do
      {:ok, mod} -> mod
      :error -> :error
    end
  end

  # Build per-argument hints by locating the call's argument tokens (between the
  # matching `(` and the `closing` `)`) and splitting them on top-level commas.
  defp call_hints({closing, names}, index, lines, rs, re) do
    case argument_segments(index, closing) do
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

  # nil names (non-identifier patterns: literals, struct-only) are not displayable.
  # Leading underscores are intentionally rejected here for display suppression —
  # elixir_sense's identifier_or_nil accepts them, but we do not show `_foo:` hints.
  defp clean_identifier?(nil), do: false
  defp clean_identifier?(name), do: Regex.match?(~r/^[a-z][a-zA-Z0-9_]*[?!]?$/, name)

  defp single_identifier_equal?([{:identifier, _pos, value}], name) when is_atom(value),
    do: Atom.to_string(value) == name

  defp single_identifier_equal?(_segment, _name), do: false

  defp segment_start([token | _]), do: token_position(token)
  defp segment_start([]), do: nil

  defp argument_segments(index, closing) do
    with close_index when is_integer(close_index) <-
           Map.get(index.close_for_position, closing, :error),
         open_index when is_integer(open_index) <-
           Map.get(index.open_for_close, close_index, :error),
         :"(" <- token_type(elem(index.tuple, open_index)) do
      inner = slice_tuple(index.tuple, open_index + 1, close_index - 1)
      {:ok, split_arguments(inner)}
    else
      _ -> :error
    end
  end

  # Tokens at indices `from..to` (inclusive) from the precomputed tuple.
  defp slice_tuple(_tuple, from, to) when from > to, do: []

  defp slice_tuple(tuple, from, to) do
    for i <- from..to, do: elem(tuple, i)
  end

  defp split_arguments(tokens) do
    # Prepend completed segments and reverse at the end to stay O(N).
    # The naive `segments ++ [segment]` inside the reduce was O(K^2) in the
    # number of arguments K (each append walked the whole list).
    {rev_segments, current, _depth} =
      Enum.reduce(tokens, {[], [], 0}, fn token, {rev_segments, current, depth} ->
        type = token_type(token)

        cond do
          type == :"," and depth == 0 -> {[Enum.reverse(current) | rev_segments], [], depth}
          type in @openers -> {rev_segments, [token | current], depth + 1}
          type in @closers -> {rev_segments, [token | current], depth - 1}
          true -> {rev_segments, [token | current], depth}
        end
      end)

    [Enum.reverse(current) | rev_segments]
    |> Enum.reverse()
    |> Enum.reject(&(&1 == []))
  end

  defp tokenize(text) do
    case :elixir_tokenizer.tokenize(String.to_charlist(text), 1, 1, []) do
      {:ok, _, _, _, tokens, _} -> source_order(tokens)
      {:ok, _, _, _, tokens} -> source_order(tokens)
      {:ok, _, _, tokens} -> source_order(tokens)
      _ -> []
    end
  rescue
    _ -> []
  catch
    _, _ -> []
  end

  # `:elixir_tokenizer.tokenize/4`'s token order is not stable across Elixir
  # releases: 1.17+ returns the accumulator in reverse source order (so a
  # blind `Enum.reverse/1` yields source order), but **1.16 returns it already
  # in forward source order** — reversing it there scrambled the open/close
  # delimiter stack and silently dropped every parameter-name hint. Normalize
  # explicitly by inspecting the endpoints' positions instead of assuming a
  # version. Empty / single-token lists are already trivially ordered.
  defp source_order([] = tokens), do: tokens
  defp source_order([_only] = tokens), do: tokens

  defp source_order(tokens) do
    first_pos = token_position(hd(tokens))
    last_pos = token_position(List.last(tokens))

    case {first_pos, last_pos} do
      {{fl, fc}, {ll, lc}} when {fl, fc} > {ll, lc} -> Enum.reverse(tokens)
      _ -> tokens
    end
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
    {{sl, sc}, {el, ec}}
  end

  # Clamp so at most @max_range_lines lines are ever processed: the inclusive
  # window sl..el spans `el - sl + 1` lines, so anything with `el - sl >=
  # @max_range_lines` (i.e. > @max_range_lines lines) is trimmed to the first
  # @max_range_lines lines (sl .. sl + @max_range_lines - 1). The new end
  # column must be a whole-line sentinel, not the original range's `ec` — that
  # column belongs to a different (later) line and would spuriously cut off
  # hints on the clamped boundary line.
  defp clamp_range({{sl, _sc} = start, {el, _ec}} = range) do
    if el - sl >= @max_range_lines do
      {start, {sl + @max_range_lines - 1, @max_line_column}}
    else
      range
    end
  end

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
