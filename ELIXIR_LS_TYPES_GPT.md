# ElixirLS Types/Inlay Hints Audit Tasks

Fifth review date: 2026-06-12.

Worktree: `/Users/lukaszsamson/vscode-elixir-ls/elixir-ls/.claude/worktrees/practical-roentgen-11f5aa`.

Related ElixirSense worktree: `/Users/lukaszsamson/elixir_sense/.claude/worktrees/trusting-wu-d1f603`.

Inputs consolidated:
- `ELIXIR_LS_TYPES_GPT.md` fourth review.
- `ELIXIR_LS_TYPES_FABLE.md` 2026-06-12 architectural wave.
- `/Users/lukaszsamson/vscode-elixir-ls/elixir-ls/ELIXIR_LS_TYPES_GEMINI.md`.
- Current ElixirSense `TypeHints` facade and ElixirLS provider/tests.

Goal: provide LSP inlay hints that show accurate compiler-style types for remote calls to external modules and best-effort inferred types for current-file calls/variables, without leaking private Elixir typesystem details into ElixirLS.

## Status

The provider architecture is in good shape. The remaining blockers are release mechanics and packaging, not inlay-hint type plumbing.

Done in current code:
- `ElixirLS.LanguageServer.Providers.InlayHints` consumes `ElixirSense.Core.TypeHints` only; it does not inspect `Binding`, `TypePresentation`, raw signatures, or private descriptor data.
- One `TypeHints.request_context/1` is built per inlay request.
- Parameter-name hints use `TypeHints.effective_params/4`; provider string parsing was removed.
- Variable binding hints use `TypeHints.type_hint_for_var/4`.
- Read hints, when `showOnlyBindings: false`, use flow-sensitive `TypeHints.type_hint_at/4`.
- `minimumTrust` accepts `compiler`, `native`, and `bestEffort`, using `TypeHints.trust_rank/1`.
- Unrecognized `minimumTrust` values warn once per value per VM and fall back to best effort.
- Server/provider/integration tests cover request round trips, sub-ranges, cancellation, disabled native typing, Unicode/UTF-16 positions, clamp behavior, parameter independence, ExCk fixtures, overloaded returns, struct returns, version mismatch, missing chunks, destructuring suppression, and flow-sensitive reads.
- A `release-gate` CI job greps for absolute local path dependencies. It is intentionally `continue-on-error: true` while the development branch uses a local ElixirSense path dep.
- Benchmark data supports keeping native variable hints enabled: the measured hint path is faster with native typing than without it.

Gemini/Fable reconciliation:
- Fixed: facade/layering leak, per-hint local signature cost, structured params, server-level coverage, ExCk fixture coverage, Unicode/UTF-16 tests, clamp off-by-one, richer `minimumTrust`, destructuring suppression coverage, unrecognized trust warnings, flow-sensitive read hints, and initial benchmark work.
- Still open: absolute local path dependency, flipping the release gate to hard-fail, final release defaults/docs, packaged-dependency smoke testing, lazy resolve if payloads justify it, and optional return-type call hints.
- Reframed: tooltip bloat is bounded by conditional tooltips and ElixirSense's full-text cap, so lazy resolve remains future work.

## P0 - Release Blockers

- [ ] Remove the private local `elixir_sense` path dependency before merge/release.
  - `apps/language_server/mix.exs`, `apps/elixir_ls_utils/mix.exs`, and `apps/debug_adapter/mix.exs` still point to `/Users/lukaszsamson/elixir_sense/.claude/worktrees/trusting-wu-d1f603`.
  - Repoint `@dep_versions[:elixir_sense]` and `mix.lock` to the published ElixirSense ref once that branch lands.
  - Verify a clean checkout can fetch and compile the packaged dependency.

- [ ] Flip the release-gate CI job from advisory to enforcing.
  - `.github/workflows/ci.yml` has a release-gate grep for absolute `path: "/..."` deps.
  - It currently uses `continue-on-error: true` because the branch intentionally depends on the local ElixirSense worktree during development.
  - Set it to hard-fail before release.

- [ ] Freeze release defaults for variable type hints.
  - Benchmark data supports keeping `variableTypes.enabled` and native inference on.
  - If ElixirSense release evidence is incomplete, consider keeping hints on but defaulting `minimumTrust` to `"native"`.
  - Keep `ELIXIR_LS_TYPE_INFERENCE=false` documented as the runtime kill switch.

- [ ] Land VS Code extension schema/docs with the ElixirLS release.
  - The inlay-hints README/settings schema updates live in the sibling `vscode-elixir-ls` repo.
  - Ensure `minimumTrust`, `variableTypes.enabled`, `showOnlyBindings`, `maxLength`, `parameterNames.enabled`, and the kill switch are documented in the released extension.

## P1 - Correctness And Trust

- [ ] Add a packaged-dependency release smoke test.
  - Verify no path dependency remains.
  - Verify a clean project gets remote-call type hints from the packaged ElixirSense version.
  - Verify type inference failures skip affected hints without breaking parameter-name hints or the LSP request.

- [ ] Preserve remote-call coverage as the headline feature.
  - Existing fixture coverage is good; keep expanding with real dependency modules, stdlib calls, overloaded specs, optional map/struct returns, missing chunks, and version mismatch cases.
  - Remote-call variables backed by ExCk/native data should remain the strongest supported use case.

- [ ] Keep `minimumTrust` semantics aligned with ElixirSense.
  - The provider filters by `TypeHints.trust_rank/1`; do not reimplement trust ordering locally.
  - `compiler` means `:native_exck`; `native` includes `:native_exck` and `:native_inferred`; `bestEffort` includes `:spec` and `:shape`.
  - Parameter-name hints must remain independent from this setting.

- [ ] Keep read-occurrence behavior explicit in docs.
  - Default `showOnlyBindings: true` means read positions are not annotated.
  - With `showOnlyBindings: false`, reads now use `TypeHints.type_hint_at/4` and can reflect flow-sensitive narrowing.
  - Document that this is best effort and depends on ElixirSense metadata precision.

## P2 - UX And Protocol

- [ ] Consider lazy `inlayHint/resolve` only if measured payloads justify it.
  - Tooltips are conditional and capped by ElixirSense, so this is not a release blocker.
  - If large workspaces show oversized responses, set `resolve_provider: true` and resolve full tooltips lazily.

- [ ] Add return-type call hints only after variable hints ship cleanly.
  - Variable bindings already cover `x = Mod.f()` indirectly, but standalone calls are not annotated.
  - If added, make it opt-in and route entirely through ElixirSense remote-call typing.

- [ ] Expose `maxFullLength` only if users need it.
  - ElixirSense caps full tooltip text internally.
  - Keep the setting internal unless real usage shows a need for user control.

- [ ] Keep backend status out of labels.
  - Hint labels should remain clean compiler-style type text.
  - Use logs or telemetry for backend mode, degradation, trust fallback, and kill-switch state.

## P3 - Performance And Maintenance

- [ ] Turn benchmark data into a repeatable regression check.
  - Round-4 data closed the immediate benchmark question.
  - A reusable large-file fixture/threshold would catch future performance regressions.

- [ ] Keep parameter-name hints independent from type inference.
  - Tests cover disabled native typing and strict trust filtering.
  - Preserve this property as ElixirSense and settings evolve.

- [ ] Keep CI and docs aligned with development vs release state.
  - Development branch may intentionally carry a local path dependency.
  - Release branch must hard-fail on local path dependencies and ship matching extension settings.

## Acceptance Criteria Before Shipping

- [ ] No absolute local path dependencies remain.
- [ ] The release-gate CI job fails on absolute path dependencies.
- [ ] The installed extension exposes the same settings that the server accepts.
- [ ] Remote-call variables show compiler-style return types when ExCk/native data is available.
- [ ] Read hints, when enabled, use `TypeHints.type_hint_at/4`.
- [ ] Current-file hints are clearly best-effort unless backed by native descriptors.
- [ ] ElixirLS consumes stable ElixirSense facade APIs and does not inspect private Elixir typesystem data.
- [ ] Type inference failures skip affected type hints without breaking parameter hints or the LSP request.

## Closed Or Reframed

- [x] Direct `Binding.from_env` / `TypePresentation` provider coupling: fixed via `TypeHints`.
- [x] Per-hint local-sigs rebuild: fixed via request context caching.
- [x] Parameter-name string parsing: fixed via `TypeHints.effective_params/4`.
- [x] Richer `minimumTrust`: fixed with `compiler`, `native`, and `bestEffort`.
- [x] Unrecognized `minimumTrust` behavior: fixed with once-per-value warning and best-effort fallback.
- [x] Server-level inlay request coverage: added.
- [x] Compiled ExCk fixture coverage: added and expanded.
- [x] Clamp off-by-one and Unicode/UTF-16 tests: fixed.
- [x] Obvious-binding suppression/destructuring policy: covered by tests.
- [x] Flow-sensitive read hints: fixed via `TypeHints.type_hint_at/4`.
- [x] Initial benchmark question: closed with measured native-on/native-off data.
- [x] Tooltip bloat: bounded; lazy resolve remains optional future work.
