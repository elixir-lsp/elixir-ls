# ElixirLS Types/Inlay Hints Audit Tasks

Third review date: 2026-06-11.

Worktree: `/Users/lukaszsamson/vscode-elixir-ls/elixir-ls/.claude/worktrees/practical-roentgen-11f5aa`.

Related ElixirSense worktree: `/Users/lukaszsamson/elixir_sense/.claude/worktrees/trusting-wu-d1f603`.

Inputs consolidated:
- `ELIXIR_LS_TYPES_GPT.md` second review.
- `ELIXIR_LS_TYPES_FABLE.md` third consolidated backlog.
- `/Users/lukaszsamson/vscode-elixir-ls/elixir-ls/ELIXIR_LS_TYPES_GEMINI.md`.

Goal: provide LSP inlay hints that show accurate compiler-style types for remote calls to external modules and best-effort inferred types for current-file calls/variables, without leaking private Elixir typesystem details into ElixirLS.

## Status

The current provider is materially cleaner than in the previous GPT pass:

- Done: provider consumes `ElixirSense.Core.TypeHints` instead of direct `Binding`/`TypePresentation`.
- Done: one `TypeHints.request_context/1` per inlay request, with request-scoped caching in ElixirSense.
- Done: structured parameter names come from `TypeHints.effective_params/4`; provider string parsing was removed.
- Done: server-level `textDocument/inlayHint` tests exist, including capability, request round trip, sub-range behavior, cancellation robustness, and Unicode/UTF-16 safety.
- Done: compiled ExCk fixture integration tests exist for remote-call variable hints and degradation.
- Done: `clamp_range` boundary is fixed (`>=`), and provider-level Unicode tests exist.

Gemini findings incorporated:
- Still open: private local path dependency, release defaults, read-occurrence flow sensitivity, lazy resolve as a future protocol optimization.
- Fixed: facade/layering leak, per-hint binding cost, structured params, server-level/ExCk coverage, clamp off-by-one.
- Reframed: tooltip bloat is bounded by conditional tooltips and ElixirSense's `max_full_length` cap, so lazy resolve is not a release blocker.

## Fix-wave status (2026-06-11 evening, Fable)

Addressed this wave:
- P1 "richer minimumTrust" — the setting now accepts compiler | native | bestEffort
  (schema updated in vscode-elixir-ls package.json) and filters via
  TypeHints.trust_rank/1 over :native_exck/:native_inferred/:spec/:shape; unknown
  future source atoms fail safe to weakest. Observed attribution: ExCk-backed
  remote calls (e.g. Enum.map) classify :native_exck in practice.
- P1 "expand remote-call integration coverage" — overloaded fixture returns selected
  by argument type, struct-returning fixture, ExCk version-mismatch degradation
  (foreign checker tag), missing-chunk module; all degrade without request failure.
- P1 "obvious-binding suppression with destructuring" — policy locked in by tests:
  %Struct{} = call() NOT suppressed, %Struct{} = var suppressed,
  {:ok, value} = call() hints value, [head | _] = remote() behavior pinned.
- P3 "extension docs" — README inlay-hints section + full settings (separate
  vscode-elixir-ls repo, uncommitted there).

Still open: P0 path dep + release defaults (blocked on publishing elixir_sense);
P1 flow-sensitive read occurrences; P2 lazy resolve (parked), return-type hints;
P3 benchmarks.

## P0 - Release Blockers

- [ ] Remove the private local `elixir_sense` path dependency before merge/release.
  - `apps/language_server/mix.exs`, `apps/elixir_ls_utils/mix.exs`, and `apps/debug_adapter/mix.exs` point to `/Users/lukaszsamson/elixir_sense/.claude/worktrees/trusting-wu-d1f603`.
  - Repoint `@dep_versions[:elixir_sense]` and `mix.lock` to the published ElixirSense ref once that branch lands.
  - Add a CI grep or release check rejecting absolute local path dependencies such as `path: "/Users/..."`.

- [ ] Decide release defaults for variable type hints.
  - `variableTypes.enabled` and native inference currently default on.
  - If ElixirSense still has open fidelity/performance risk, consider `parameterNames` on and `variableTypes` off, or default `minimumTrust` to a stricter level once richer trust is exposed.
  - Keep `ELIXIR_LS_TYPE_INFERENCE=false` documented as a runtime kill switch.

## P1 - Correctness And Trust

- [ ] Support richer `minimumTrust` values once ElixirSense exposes richer provenance.
  - Current provider can only filter `source == :native` versus `:shape`.
  - Desired levels: compiler/ExCk-native, native-inferred, spec fallback, best-effort shape.
  - Update settings schema and filtering once `TypeHints.type_hint_for_var/4` returns those values.

- [ ] Keep read occurrence hints conservative.
  - `showOnlyBindings` defaults to `true`; keep that default.
  - If `showOnlyBindings=false`, document that read hints use the variable info currently available from metadata and may not be fully flow-sensitive.
  - True flow-sensitive read hints need an ElixirSense position-aware API that resolves the variable under the read occurrence context.

- [ ] Expand remote-call integration coverage.
  - The compiled ExCk fixture suite exists; add more cases for dependency modules, overloaded returns selected by argument type, missing chunks, version mismatch, and modules with optional map/struct return types.
  - This is the headline feature and should stay ahead of local best-effort inference.

- [ ] Revisit obvious-binding suppression with remote-call destructuring.
  - Add coverage for `%Struct{} = remote()`, `{:ok, value} = remote()`, and destructuring from external calls returning structs/maps.
  - Ensure suppression does not hide useful compiler-normalized remote-call facts.

## P2 - UX And Protocol

- [ ] Consider lazy `inlayHint/resolve` only if real payloads justify it.
  - Tooltips are conditional and capped by ElixirSense, so this is not a release blocker.
  - If large workspaces show oversized responses, set `resolve_provider: true` and resolve full tooltips lazily.

- [ ] Expose `maxFullLength` only if needed.
  - ElixirSense caps full tooltip text at 1000 graphemes.
  - Keep it internal unless users need control.

- [ ] Add return-type call hints only after variable hints are trusted.
  - Variable bindings cover `x = Mod.f()` indirectly, but standalone calls are not annotated.
  - If added, make it opt-in and route through ElixirSense remote-call typing.

- [ ] Keep backend status in logs/telemetry, not labels.
  - One-time logging exists.
  - Add telemetry/debug data if needed, but hint labels should remain clean compiler-style type text.

## P3 - Performance And Maintenance

- [ ] Benchmark inlay hints on large files.
  - Token indexing and TypeHints request caching are in place.
  - Measure whole-document ranges, many variables, many calls, and native typing enabled/disabled.

- [ ] Keep parameter-name hints independent from type inference.
  - Tests cover disabled native typing.
  - Preserve this property as the TypeHints facade and settings evolve.

- [ ] Update extension documentation.
  - Document `variableTypes.enabled`, `showOnlyBindings`, `maxLength`, `minimumTrust`, `parameterNames.enabled`, the runtime env kill switch, and the experimental status of variable type hints.
  - Ensure the settings schema in the VS Code extension repo is committed with the ElixirLS changes.

## Acceptance Criteria Before Shipping

- [ ] No absolute local path dependencies remain.
- [ ] Remote-call variables show compiler-style return types when ExCk/native data is available.
- [ ] Current-file hints are clearly best-effort unless backed by native descriptors.
- [ ] ElixirLS consumes stable ElixirSense facade APIs and does not inspect private Elixir typesystem data.
- [ ] Type inference failures skip affected type hints without breaking parameter hints or the LSP request.

## Closed Or Reframed

- [x] Direct `Binding.from_env` / `TypePresentation` provider coupling: fixed via `TypeHints`.
- [x] Per-hint local-sigs rebuild: fixed via request context caching.
- [x] Parameter-name string parsing: fixed via `TypeHints.effective_params/4`.
- [x] Server-level inlay request coverage: added.
- [x] Compiled ExCk fixture coverage: added.
- [x] Clamp off-by-one and Unicode/UTF-16 tests: fixed.
- [x] Tooltip bloat: bounded; lazy resolve remains optional future work.
