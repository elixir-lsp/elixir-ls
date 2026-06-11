# ElixirLS Types/Inlay Hints Audit Tasks

Fourth review date: 2026-06-11.

Worktree: `/Users/lukaszsamson/vscode-elixir-ls/elixir-ls/.claude/worktrees/practical-roentgen-11f5aa`.

Related ElixirSense worktree: `/Users/lukaszsamson/elixir_sense/.claude/worktrees/trusting-wu-d1f603`.

Inputs consolidated:
- `ELIXIR_LS_TYPES_GPT.md` third review.
- `ELIXIR_LS_TYPES_FABLE.md` latest fix-wave/backlog.
- `/Users/lukaszsamson/vscode-elixir-ls/elixir-ls/ELIXIR_LS_TYPES_GEMINI.md`.
- Current ElixirSense `TypeHints` facade and ElixirLS provider/tests.

Goal: provide LSP inlay hints that show accurate compiler-style types for remote calls to external modules and best-effort inferred types for current-file calls/variables, without leaking private Elixir typesystem details into ElixirLS.

## Status

The provider is now on the right architectural boundary. The remaining release blockers are packaging/default decisions, not provider layering.

Done in current code:
- `ElixirLS.LanguageServer.Providers.InlayHints` consumes `ElixirSense.Core.TypeHints` only; it no longer instantiates `Binding` or calls `TypePresentation` directly.
- One `TypeHints.request_context/1` is built per inlay request, so ElixirSense can cache local signatures request-wide.
- Parameter-name hints use `TypeHints.effective_params/4`; provider string parsing was removed.
- `minimumTrust` accepts `compiler`, `native`, and `bestEffort`, using `TypeHints.trust_rank/1` over `:native_exck`, `:native_inferred`, `:spec`, and `:shape`.
- Unknown future source atoms fail safe to weakest trust.
- Server and provider tests cover request round trips, sub-ranges, cancellation robustness, disabled native typing, Unicode/UTF-16 positions, clamp range behavior, and parameter hints independent from type inference.
- Compiled ExCk integration tests cover remote-call variables, overloaded returns selected by argument type, struct returns, ExCk version mismatch degradation, and missing chunks.
- Obvious-binding suppression policy is now tested for `%Struct{} = call()`, `%Struct{} = var`, `{:ok, value} = call()`, and `[head | _] = remote()`.

Gemini/Fable reconciliation:
- Fixed: facade/layering leak, per-hint local signature cost, structured params, server-level coverage, ExCk fixture coverage, Unicode/UTF-16 tests, clamp off-by-one, richer `minimumTrust`, and destructuring suppression coverage.
- Still open: absolute local path dependency, release defaults, flow-sensitive read occurrences, optional lazy resolve/return-type hints, and large-file benchmarks.
- Reframed: tooltip bloat is bounded by conditional tooltips and ElixirSense's full-text cap, so lazy resolve is not a release blocker.

## P0 - Release Blockers

- [ ] Remove the private local `elixir_sense` path dependency before merge/release.
  - `apps/language_server/mix.exs`, `apps/elixir_ls_utils/mix.exs`, and `apps/debug_adapter/mix.exs` still point to `/Users/lukaszsamson/elixir_sense/.claude/worktrees/trusting-wu-d1f603`.
  - Repoint `@dep_versions[:elixir_sense]` and `mix.lock` to the published ElixirSense ref once that branch lands.
  - Add a CI or release check rejecting absolute local path dependencies such as `path: "/Users/..."`.

- [ ] Decide release defaults for variable type hints.
  - `variableTypes.enabled` and native inference currently default on.
  - If ElixirSense ships with unresolved fidelity/performance risk, prefer one of: `parameterNames` on with `variableTypes` off, or `variableTypes` on with `minimumTrust: "native"`.
  - Keep `ELIXIR_LS_TYPE_INFERENCE=false` documented as a runtime kill switch.

- [ ] Land the VS Code extension schema/docs with the ElixirLS release.
  - The inlay-hints README/settings schema updates were made in the sibling `vscode-elixir-ls` repo, but are not part of this worktree.
  - Ensure `minimumTrust`, `variableTypes.enabled`, `showOnlyBindings`, `maxLength`, `parameterNames.enabled`, and the kill switch are documented in the release branch users install.

## P1 - Correctness And Trust

- [ ] Keep read occurrence hints conservative.
  - `showOnlyBindings` defaults to `true`; keep that default for release.
  - If `showOnlyBindings=false`, document that read hints are based on currently available metadata and may not reflect all compiler flow refinements.
  - True flow-sensitive reads need a position-aware ElixirSense API that resolves the variable under the read occurrence context.

- [ ] Preserve remote-call coverage as the headline feature.
  - Existing fixture coverage is good; keep expanding it with real dependency modules, stdlib calls, overloaded specs, optional map/struct returns, missing chunks, and version mismatch cases.
  - Remote-call variables backed by ExCk/native data should remain the strongest supported use case.

- [ ] Keep `minimumTrust` semantics aligned with ElixirSense.
  - The provider now filters by `TypeHints.trust_rank/1`; do not reimplement trust ordering locally.
  - Ensure `compiler` means `:native_exck`, `native` includes `:native_exck` and `:native_inferred`, and `bestEffort` includes `:spec` and `:shape`.
  - Parameter-name hints must remain independent from this setting.

## P2 - UX And Protocol

- [ ] Consider lazy `inlayHint/resolve` only if measured payloads justify it.
  - Tooltips are conditional and capped by ElixirSense, so this is not a release blocker.
  - If large workspaces show oversized responses, set `resolve_provider: true` and resolve full tooltips lazily.

- [ ] Add return-type call hints only after variable hints are trusted.
  - Variable bindings already cover `x = Mod.f()` indirectly, but standalone calls are not annotated.
  - If added, make it opt-in and route entirely through ElixirSense remote-call typing.

- [ ] Expose `maxFullLength` only if users need it.
  - ElixirSense caps full tooltip text internally.
  - Keep the setting internal unless real usage shows a need for user control.

- [ ] Keep backend status out of labels.
  - Hint labels should remain clean compiler-style type text.
  - Use logs or telemetry for backend mode, degradation, and kill-switch state.

## P3 - Performance And Maintenance

- [ ] Benchmark inlay hints on large files.
  - Token indexing and `TypeHints` request caching are in place.
  - Measure whole-document ranges, many variables, many remote calls, native typing enabled/disabled, and `minimumTrust` filters.

- [ ] Keep parameter-name hints independent from type inference.
  - Tests cover disabled native typing and strict trust filtering.
  - Preserve this property as ElixirSense and settings evolve.

- [ ] Add a release smoke test for packaging.
  - Verify no path dependency remains.
  - Verify a clean project gets remote-call type hints from the packaged ElixirSense version.
  - Verify type inference failures skip affected hints without breaking parameter hints or the LSP request.

## Acceptance Criteria Before Shipping

- [ ] No absolute local path dependencies remain.
- [ ] The installed extension exposes the same settings that the server accepts.
- [ ] Remote-call variables show compiler-style return types when ExCk/native data is available.
- [ ] Current-file hints are clearly best-effort unless backed by native descriptors.
- [ ] ElixirLS consumes stable ElixirSense facade APIs and does not inspect private Elixir typesystem data.
- [ ] Type inference failures skip affected type hints without breaking parameter hints or the LSP request.

## Closed Or Reframed

- [x] Direct `Binding.from_env` / `TypePresentation` provider coupling: fixed via `TypeHints`.
- [x] Per-hint local-sigs rebuild: fixed via request context caching.
- [x] Parameter-name string parsing: fixed via `TypeHints.effective_params/4`.
- [x] Richer `minimumTrust`: fixed with `compiler`, `native`, and `bestEffort`.
- [x] Server-level inlay request coverage: added.
- [x] Compiled ExCk fixture coverage: added and expanded.
- [x] Clamp off-by-one and Unicode/UTF-16 tests: fixed.
- [x] Obvious-binding suppression/destructuring policy: covered by tests.
- [x] Tooltip bloat: bounded; lazy resolve remains optional future work.
