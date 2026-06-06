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

Types come from `ElixirSense.Core.Binding.expand/2` shape tuples, rendered by `render_shape/2`. On the
`elixir-types` engine those shapes are produced by the set-theoretic type engine
(`ElixirSense.Core.ElixirTypes`, wrapping `Module.Types.Descr`; `to_shape/1` = descr→shape bridge).

Guardrails: ≤500 range lines, ≤200 variables, label ≤40 chars, shape depth ≤3; underscore-prefixed
vars ignored; opt-in via `elixirLS.inlayHints.variableTypes.enabled` (default true).

## Build / test

```bash
cd /Users/lukaszsamson/elixir-ls-inlay-hints
mix deps.get
cd apps/language_server
mix test test/providers/inlay_hints_test.exs
```

## Open problems / next steps

- Param-name hints not built (both the simple `(a:, b:)` and AST-accurate phase-2 variants).
- Multi-var destructuring (`{:ok, %User{name: name, age: age}} = result`): only the first binding
  position per `VarInfo` is taken; design wants a hint on each bound var.
- Pipe-chain intermediate types skipped in v1.
- `@spec` vs inferred precedence undecided.
- Map/struct rendering is coarse (`%{…}`, `%Mod{}`); no key/field detail.
- Client-side: `package.json` settings contributions in the VS Code extension not yet added
  (`elixirLS.inlayHints.variableTypes.{enabled,maxLength,showOnlyBindings}`, `…parameterNames`).
