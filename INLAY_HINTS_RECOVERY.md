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

LSP `textDocument/inlayHint`, two intended cases:

1. **Variable type hints** (`kind: type`) — inferred type rendered after a variable's *binding*
   occurrence (LHS of a match: `value = 42` → `integer`). Reads are not annotated. **Implemented.**
2. **Call parameter-name hints** (`kind: parameter`) — `foo(a:, b:)` at call sites. **Designed only**
   (see `INLINE_HINTS.md` → "Call parameter name hints").

Type text comes entirely from `ElixirSense.Core.TypePresentation.render_hint/2` (the LSP-facing type
surface). It resolves the stored shape (`VarInfo.type`) through `Binding`, falls back to the native
`Module.Types` descriptor (`VarInfo.elixir_types_descr`), guarantees a thunk-free result, and returns
`:skip` for uninformative `term()`/`none()`/unknown types. The provider no longer renders types itself
(the old local `render_shape/2` was deleted) — it only positions hints and applies a max-length cap.

Guardrails: ≤500 range lines, ≤200 variables, label ≤40 chars, shape depth ≤3; underscore-prefixed
vars ignored; opt-in via `elixirLS.inlayHints.variableTypes.enabled` (default true).

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

Tests (21, all green against the engine): variable literals/tuple/map/list/`%URI{}`/`fn` arrow,
suppression, binding-vs-read, var settings; and parameter hints for local/remote calls, pipe window
shift, arg==param suppression, comma-in-string and comma-in-`fn` robustness, toggle.

Open problems / next steps:
- Parameter hints: only paren calls are annotated (no-paren calls and operators are skipped); heredocs /
  interpolation fall back to no hints for that call if the tokenizer can't cleanly split.
- Richer *type* precision is gated on the type engine (L2 — not touched from this repo): branch-narrowing
  (`case binary_or_nil do nil -> …; v -> …` → `binary()`), map/union (`%{a: 1 | 2}`), and precise struct
  field types (`%URI{host: binary()}`) currently resolve to thunks and `render_hint` returns `:skip`.
- `@spec` vs inferred precedence undecided.
- Client-side: `package.json` settings contributions in the VS Code extension not yet added
  (`elixirLS.inlayHints.variableTypes.{enabled,maxLength,showOnlyBindings}`, `…parameterNames.enabled`).
