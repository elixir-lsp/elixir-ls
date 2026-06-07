# Inlay Hints — recovery & status

This checkout restores the experimental ElixirLS **type inlay-hint** feature that was lost when the
original branch was destroyed. Reconstructed from the Codex session of 2025-10-02
(`~/.codex/sessions/2025/10/02/rollout-…0199a1da….jsonl`), which was the sole implementation source.

## What's here (branch `inlay-hints`, based on `master` @ 98e983dd)

- `apps/language_server/lib/language_server/providers/inlay_hints.ex` — the provider.
- `apps/language_server/test/providers/inlay_hints_test.exs` — tests.
- `apps/language_server/lib/language_server/server.ex` — wiring: `InlayHints` alias, a
  `textDocument/inlayHint` request handler (before the `TextDocumentSelectionRange` clause), and the
  `inlay_hint_provider` capability (after `execute_command_provider`).
- `apps/language_server/mix.exs` — `:elixir_sense` switched to a **path dep** pointing at
  `/Users/lukaszsamson/elixir_sense/.claude/worktrees/trusting-wu-d1f603` (the `elixir-types` type
  engine — module `ElixirSense.Core.ElixirTypes`, branch `claude/trusting-wu-d1f603`).
- `INLINE_HINTS.md` — original design doc (verbatim recovered).

## Feature

LSP `textDocument/inlayHint`, two cases — **both implemented**:

1. **Variable type hints** (`kind: type`) — inferred type rendered after a variable's *binding*
   occurrence (LHS of a match: `total = a + b` → `: integer()`). A binding is skipped when *either*
   side of its match is a syntactically-obvious value (literal/struct/map/list/tuple/bitstring) —
   `x = 1`, `m = %{…}`, or `%User{} = user` — since the type is already evident. Reads are not
   annotated (unless `showOnlyBindings` is disabled).
2. **Call parameter-name hints** (`kind: parameter`) — parameter names before each call argument
   (`Map.put(map: m, key: :k, value: v)`).

Type text comes entirely from `ElixirSense.Core.TypePresentation.render_hint/2` (the LSP-facing type
surface). It resolves the stored shape (`VarInfo.type`) through `Binding`, falls back to the native
`Module.Types` descriptor (`VarInfo.elixir_types_descr`), guarantees a thunk-free result, and returns
`:skip` for uninformative `term()`/`none()`/unknown types. The provider does not render types itself
(the old local `render_shape/2` was deleted) — it only positions hints and truncates to `maxLength`.
The precision of the rendered types (branch narrowing, map/union fields, structural struct shapes) is
entirely up to the elixir_sense type engine; the provider renders whatever it returns.

Guardrails: ≤1000 range lines and ≤1000 total hints per request; variable-type labels truncated to
`maxLength` (default 60); underscore-prefixed vars ignored; the server skips non-Elixir files;
each is opt-out via `elixirLS.inlayHints.{variableTypes,parameterNames}.enabled` (default true).

## Build / test

```bash
cd /Users/lukaszsamson/elixir-ls-inlay-hints
mix deps.get
cd apps/language_server
mix test test/providers/inlay_hints_test.exs
```

## Status (after API rewire)

Done — variable type hints:
- Rendering rewired to `TypePresentation.render_hint/2` (local `render_shape/2` deleted).
- Binding occurrence = head of `VarInfo.positions`; reads (tail) are not annotated. Each destructured
  variable is its own `VarInfo`, so every bound name is covered.
- Labels carry the leading colon (`: integer()`, `: %URI{…}`); provider-side `maxLength` truncation only.
- Settings `inlayHints.variableTypes.{enabled, showOnlyBindings, maxLength}`.

Done — call parameter-name hints (`InlayHintKind.parameter`):
- Calls collected from the parsed AST (`Parser.Context.ast`, already `columns`/`token_metadata`), with
  def-heads and special forms/operators excluded.
- MFA resolved via `Introspection.actual_mod_fun/6`; param names from `Metadata.get_function_signatures/3`
  (local) or `Introspection.get_signatures/2` (remote/stdlib); the arity-matching signature is selected
  (defaults accounted for).
- Per-argument columns computed from the Elixir tokenizer (`:elixir_tokenizer`) by matching the call's
  `(`…`)` and splitting top-level commas — robust against commas inside strings/sigils and `fn`/`do`
  blocks.
- Pipes shift the parameter window by one (the piped value is implicit).
- Noise filter: an argument is not annotated when its source text already equals the parameter name.
- Setting `inlayHints.parameterNames.enabled` (default true).

Done — robustness / correctness:
- Dynamic remote receivers (`mod.put(…)`, `factory().call(…)`) are skipped instead of passing raw AST
  into introspection (which reached `Code.ensure_loaded/1` and crashed the whole request); per-call
  resolution is also wrapped so one bad call can never fail the request.
- Calls are filtered to the requested line range *before* resolution/introspection, so a small viewport
  request in a large file doesn't walk/introspect/tokenize every call.
- The server request handler skips non-Elixir files (`.ex`/`.exs` or `language_id == "elixir"`),
  mirroring the sibling providers.
- Type and parameter hints are merged and sorted by position before the `@max_hints` cap, so neither
  category starves the other and output is in document order.

Tests (24, all green against the engine): variable literals/tuple/map/list-union/`%URI{}`/`fn` arrow,
suppression, binding-vs-read, var settings; parameter hints for local/remote calls, pipe window shift,
arg==param suppression, comma-in-string and comma-in-`fn` robustness, toggle; dynamic-receiver no-crash,
range filtering, document-order.

Done — type refinement in other providers (mirroring elixir_sense's elixir-types changes):
- **Hover**: `Hover.Docs` now computes a variable's inferred type via
  `TypePresentation.render_hint/2` and `hover.ex` renders it as a `### Type` section.
- **Completion**: `ElixirLS.Utils.CompletionEngine.match_map_fields/5` falls back to the inferred
  field type (`TypePresentation.render/1`) for map/struct fields without a declared `@type`, so
  field completions show e.g. `%{asdf: term()}` / `%MyStruct{}`. Bare `term()`/`none()` are dropped
  to avoid noise (a small, deliberate divergence from elixir_sense, which keeps them).

Open problems / next steps:
- Parameter hints: only paren calls are annotated (no-paren calls and operators are skipped); heredocs /
  interpolation fall back to no hints for that call if the tokenizer can't cleanly split.
- Type precision depends on the elixir_sense type engine and the `use_elixir_types` config flag (the
  native `Module.Types` descriptor path is off by default); whatever the engine resolves is rendered.
- `@spec` vs inferred precedence undecided (engine-side).
- Client-side: `package.json` settings contributions in the VS Code extension not yet added
  (`elixirLS.inlayHints.variableTypes.{enabled,maxLength,showOnlyBindings}`, `…parameterNames.enabled`).
- A server-handler test for the non-Elixir-file guard isn't added (sibling guarded providers aren't
  server-tested either; the guard is copy-identical to them).
