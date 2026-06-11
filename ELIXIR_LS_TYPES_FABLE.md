# ElixirLS inlay hints / types integration — audit tasks (Fable)

## Status after the 2026-06-11 fix pass

This worktree now has the `inlay-hints` branch checked out (it was previously wiped/at
master — "task 0" resolved by `git checkout -f inlay-hints` here).

Gates: `apps/language_server` full suite **1631/1632** (one pre-existing failure, below) ·
`MIX_ENV=test mix format --check-formatted` ✅ · provider tests
(inlay_hints 40, hover 11, hover/docs 83, the three ported suggestion tests) all green.

**Done:** #2 (env toggle now ALSO applied at runtime in `language_server.ex` startup),
 #3 (defaulted params dropped right-to-left — verified empirically `T.f(:x, :y)` →
`{:x, 1, :y}`), #4 (range clamped to 1000 lines instead of bailing), #5 (codepoint
arithmetic), #6+#8 (label/tooltip via `TypePresentation.render_hint/3` `max_length:`;
provider-side truncate removed), #7 (blocklist local-only; `__MODULE__`-prefixed
receivers resolved from env), #12 (four `elixirLS.inlayHints.*` properties added to
vscode-elixir-ls `package.json`), #13 (`obvious_value?` requires all-literal leaves),
 #14 (single tokenize + tuple index + one-pass delimiter matching).
Stale ported tests updated: hover docs `type:` field; suggestion `type_spec`
expectations (variable map fields render literals `"1"`/`"%{abc: 123}"`; @attribute
fields render widened `"integer()"`/`"%{abc: integer()}"`; struct defaults `"nil"`/`"\"\""`).

**Deferred:** #1 (path dep on the local elixir_sense worktree — must be repointed to a
published ref when the elixir_sense branch lands; blocks merging, intentionally left for
release), #9 (structured param API in elixir_sense; #3's fix is still signature-string
based), #10 (return-type hints), #11 (defaults kept on — flip to off if releasing before
the engine hardens), #15 (server-wide inference cost benchmark).

**Known pre-existing failures (NOT from this pass; #1731 reproduced on the pre-fix
baseline):**
- `test/providers/definition/locator_test.exs` 1714/1731/1748 — the three
  `ModuleWithTypespecs.Remote` type-definition lookups hang (>240s, mostly system time;
  flaky — sometimes individual runs pass). One shared root cause; likely the deferred
  elixir_sense perf items (clause re-inference / chunk reading). Needs its own
  investigation.
- `test/markdown_utils_test.exs:125` — environment-fragile: the `iex` application
  reports vsn `1.20.0` while `System.version()` is `1.20.1` on this machine; unrelated
  to the types integration.

---

Audit of the **`inlay-hints`** branch in `/Users/lukaszsamson/vscode-elixir-ls/elixir-ls`
against the LSP spec, the elixir_sense branch `claude/trusting-wu-d1f603`, and Elixir
1.20.1 typesystem behavior.

> **Note on branches:** the worktree `claude/practical-roentgen-11f5aa` does NOT contain
> the integration — its HEAD equals master and its working tree is wiped (all files show as
> uncommitted deletions). The actual LSP changes are the 8 commits on the local
> `inlay-hints` branch. Task 0: restore/retire the broken worktree and decide which branch
> carries the work.

---

## P0 — Blockers

### 1. Path dependency on a private local worktree; mix.lock pins a ref without the API
`apps/language_server/mix.exs:46`, `apps/elixir_ls_utils/mix.exs:40`,
`apps/debug_adapter/mix.exs:41`:
`{:elixir_sense, path: "/Users/lukaszsamson/elixir_sense/.claude/worktrees/trusting-wu-d1f603"}`.
`mix.lock` still pins git ref `b8362663`, which contains neither
`ElixirSense.Core.TypePresentation` nor `VarInfo.elixir_types_descr` — reverting the path
dep makes the branch uncompilable. **Fix:** land the elixir_sense branch first, repoint
`@dep_versions[:elixir_sense]` to the published ref; the path dep must not ship.

### 2. `ELIXIR_LS_TYPE_INFERENCE` toggle is compile-time, i.e. dead in releases
`config/config.exs`: `config :elixir_sense, use_elixir_types:
System.get_env("ELIXIR_LS_TYPE_INFERENCE", "true") ...` is evaluated when elixir-ls is
**built**. In released artifacts the advertised A/B kill switch does nothing and native
inference is hard-enabled. **Fix:** read the env var at runtime (launcher /
`Application.put_env` at boot), or wire it to an LSP setting. Note the blast radius:
this flag flips native inference for **every** metadata build (completion, hover, parse),
not just inlay hints — keep a working kill switch given the adaptor couples to unstable
`Module.Types` internals.

---

## P1 — Bugs

### 3. Wrong parameter-name labels with non-trailing default params
`apps/language_server/lib/language_server/providers/inlay_hints.ex`
(`parameter_names/4`): `params |> Enum.take(arity)`. For `def f(a, b \\ 1, c)` called as
`f(x, y)`, Elixir maps `x→a, y→c`, but the hint labels the second argument `b:`.
**Fix:** when `arity < length(params)`, drop *defaulted* params right-to-left instead of
taking a prefix — ideally via an elixir_sense API that returns the effective param list
for a concrete arity (see #9). Add a regression test.

### 4. Files >1000 lines silently get zero hints
`exceeds_line_budget?` → `{:ok, []}`. VS Code sends viewport ranges, but several clients
(Neovim plugins, helix, some emacs clients) request the whole document — any large file
gets no hints at all. **Fix:** clamp the requested range to `@max_range_lines` from its
start instead of bailing.

### 5. Position arithmetic: grapheme count added to a codepoint column
`variable_hint/5`: `column + String.length(name)` adds graphemes to the tokenizer's
codepoint column before `elixir_position_to_lsp` (UTF-16) conversion — misplaced hints for
identifiers where graphemes ≠ codepoints. **Fix:** `length(String.to_charlist(name))`.
(The UTF-16 conversion itself is correct on both hint paths.)

### 6. `truncate/2` mixes bytes and graphemes
Guard is `byte_size(text) <= max` but slicing uses `String.slice` — multi-byte labels
(e.g. `%Café{}`) truncate even when within the character budget. Use `String.length` in
the guard.

### 7. Call blocklist suppresses *remote* calls with keyword-like names
`@call_blocklist` is checked against `fun` for both local and remote calls
(`maybe_call/7`), so `MyMod.alias(x)`, `Mod.use(y)`, `Mod.if(...)` get no hints. Apply the
blocklist to local/special-form positions only. Related minor gap: `__MODULE__.Sub.f(...)`
receivers raise inside `Module.concat` and are swallowed by `safe_resolve` — hints lost
silently; handle the `__MODULE__` alias head.

---

## P2 — Protocol / UX gaps

### 8. No `tooltip` with the full (untruncated) type
Labels are truncated to `maxLength` (default 60) with `…` and the full text is discarded.
Put the untruncated type in `InlayHint.tooltip` (or use label parts). Cheap — the text is
already computed. Depends on the elixir_sense task to return full+elided text from
`render_hint` (ELIXIR_SENSE_TYPES_FABLE.md #25).

### 9. Parameter-name extraction is string-parsing of rendered signatures in the LSP layer
`parameter_names/4` + `clean_param_name/1` split `Introspection.get_signatures` strings
and count defaults via `String.contains?(param, "\\\\")`. This is type/signature logic
living in the LSP layer, against the layering goal. **Fix:** add an elixir_sense API
returning structured params `{name, has_default}` (or the effective param list per arity)
and consume that; this also fixes #3 properly.

### 10. No return-type hints for calls
Only variable-binding hints exist (`x = f()` covers it indirectly). Stated goal mentions
accurate types for remote calls — consider opt-in return-type hints
(`elixirLS.inlayHints.returnTypes`) as a follow-up once rendering fidelity tasks land.

### 11. Feature defaults: on-by-default for an experimental engine
Both `variableTypes` and `parameterNames` default `true`; the type engine underneath is
experimental and the commit history enables native inference by default. Recommend
default-off (or parameterNames on / variableTypes off) for the first release, flipping
after the elixir_sense P0 soundness fixes land.

### 12. VS Code extension declares no `elixirLS.inlayHints.*` settings
`/Users/lukaszsamson/vscode-elixir-ls/package.json` has no schema for the new settings —
no settings UI, and undeclared settings warn in VS Code. Add the contribution points and
document interplay with `editor.inlayHints.enabled`.

### 13. Over-suppression: constructors with non-literal elements count as "obvious"
`obvious_value?` treats any tuple/list/map constructor as obvious even when elements are
calls: `x = {:ok, compute()}` suppresses the hint though the interesting type isn't
evident. Refine to "all leaves literal" or document the trade-off. (The suppression
mechanism itself is sound: AST-based via `Macro.prewalk` over `:=`, both match directions,
token-based identifier comparison — keep it.)

---

## P3 — Performance

### 14. O(n²) token scans per call hint
`argument_segments/2` re-runs `Enum.with_index(tokens)` over the whole-file token list per
call, and `matching_open/2` uses `Enum.at(tokens, index)` inside `reduce_while` (O(n) per
step). Large files with many calls in range degrade badly. **Fix:** index tokens once per
request (tuple/`:array`/map index→token) and precompute matching-delimiter positions in a
single pass.

### 15. Whole-server inference cost
With `use_elixir_types` on, every parse/metadata build pays native-typing cost server-wide
(completion, hover, document symbols), not just inlay-hint requests. Benchmark on large
files; coordinate with elixir_sense perf tasks (per-clause O(n²) re-inference, sigs-map
memoization — ELIXIR_SENSE_TYPES_FABLE.md #39/#40) before enabling by default.

---

## Tests to add

- Non-trailing default params (#3) — currently uncovered, would have caught the bug.
- Multi-byte / Unicode identifier hint positions (#5, #6).
- Whole-document range on a >1000-line file (#4).
- Remote call named `alias`/`use` gets hints (#7).
- End-to-end server test: `textDocument/inlayHint` request → encoded response (capability
  advertised, async dispatch, `$/cancelRequest`).

## Verified correct (no action needed)

- LSP shapes: `InlayHintOptions{resolve_provider: false}` capability, fully-populated
  hints (no resolve needed), async dispatch with cancellation support, correct
  result encoding.
- Dirty buffers: uses in-memory `get_source_file` + `Parser.parse_immediate/2`
  (version-cached, `ContentModifiedError` on staleness) — no per-request re-inference.
- Layering: all type resolution/rendering goes through `TypePresentation`
  (`render_hint/2` → `{:ok, text} | :skip`, `render/1`); no descr tuples or
  `Binding.expand` in the LSP layer; old local `render_shape/2` removed. This is the right
  seam to swap for a future public Elixir type API.
- API surface check against the elixir_sense worktree: `render_hint/2`, `render/1`,
  `Binding.from_env/3`, `Introspection.actual_mod_fun/6`,
  `Metadata.get_function_signatures/3`, `Introspection.get_signatures/2` all exist with
  the consumed arities/returns; hover handles `:skip`; completion drops `term()`/`none()`.
- Tokenizer-based argument splitting holds up against `%{}`, interpolation, `fn/end`,
  `do/end`, `<<>>`; dynamic receivers correctly refused; introspection failures isolated
  via `safe_resolve`.
