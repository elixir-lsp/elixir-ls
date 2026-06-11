# ElixirLS Types/Inlay Hints Audit Tasks

Second review date: 2026-06-11.

Worktree: `/Users/lukaszsamson/vscode-elixir-ls/elixir-ls/.claude/worktrees/practical-roentgen-11f5aa`.

Related ElixirSense worktree: `/Users/lukaszsamson/elixir_sense/.claude/worktrees/trusting-wu-d1f603`.

Inputs reviewed:
- Current ElixirLS inlay-hints branch.
- `ELIXIR_LS_TYPES_FABLE.md`.
- Updated ElixirSense types integration.

Goal: provide LSP inlay hints that show accurate compiler-style types for remote calls to external modules and best-effort inferred types for current-file calls/variables, without leaking private Elixir typesystem details into ElixirLS.

## Status

The initial LSP P0/P1 items are mostly addressed:

- Done: runtime `ELIXIR_LS_TYPE_INFERENCE` toggle, parameter-name default dropping, range clamping, codepoint-based identifier positioning, provider-side truncation removal, tooltip for truncated type text, local-only blocklist, `__MODULE__` receiver handling, VS Code settings, all-literal "obvious" suppression, token indexing, minimumTrust setting, backend status log, failure-mode tests, and parameter hints staying independent from type inference.
- Still open: path dependency on a private ElixirSense worktree, flow-sensitive read occurrence hints, end-to-end tests with real build/ExCk metadata, structured parameter API, return-type call hints, and release default decisions.
- Important layering note: the provider still builds `Binding.from_env/3` and calls `TypePresentation.render_hint/3`. This is acceptable as an interim seam but not the final ElixirLS abstraction.

## P0 - Release Blockers

- [ ] Remove the private local `elixir_sense` path dependency before merge/release.
  - `apps/language_server/mix.exs`, `apps/elixir_ls_utils/mix.exs`, and `apps/debug_adapter/mix.exs` point to `/Users/lukaszsamson/elixir_sense/.claude/worktrees/trusting-wu-d1f603`.
  - Repoint `@dep_versions[:elixir_sense]`/lockfile to the published ElixirSense ref once that branch lands.
  - Add a CI check or review checklist item preventing absolute local path deps from shipping.

- [ ] Decide release defaults for variable type hints.
  - `variableTypes.enabled` defaults to `true`, and native typing is enabled by default unless `ELIXIR_LS_TYPE_INFERENCE=false`.
  - If ElixirSense still has P0 correctness risks, ship `parameterNames` on and `variableTypes` off, or default `minimumTrust` to `"native"`.
  - Keep the runtime kill switch working and documented.

- [ ] Add end-to-end server coverage for `textDocument/inlayHint`.
  - Current provider tests call `InlayHints.inlay_hints/3` with `ParserContextBuilder.from_string/1`.
  - Add a server-level request test that exercises capability advertisement, async dispatch, dirty-buffer source, request range handling, JSON encoding, and cancellation behavior.

- [ ] Add real project/build metadata tests for ExCk-backed remote calls.
  - The central user goal is accurate external remote-call return types.
  - Add tests with compiled project/dependency modules where ExCk chunks are present, plus missing chunk and version-mismatch scenarios.

## P1 - Correctness And Layering

- [ ] Move variable type-hint resolution behind a single ElixirSense LSP-facing API.
  - Today ElixirLS still assembles `env`, `Binding.from_env/3`, and `TypePresentation.render_hint/3`.
  - ElixirSense should expose `type_hint_for_var(metadata, position, var, opts)` or equivalent returning `:skip | {:ok, %{label, full, source/trust}}`.
  - ElixirLS should not need to know about binding expansion, descriptors, `VarInfo.elixir_types_descr`, or source precedence.

- [ ] Make read occurrence hints flow-sensitive or keep them disabled by default.
  - With `showOnlyBindings=false`, the provider annotates each recorded position using the same `VarInfo`.
  - A read can have a different type than the binding because of guards, case/with refinements, or branch-local narrowing.
  - Needs an ElixirSense API that resolves the variable at the requested position/env.

- [ ] Use richer trust/source values from ElixirSense.
  - Current provider only sees `:native | :shape`; `minimumTrust: "native"` filters on `source == :native`.
  - Once ElixirSense distinguishes ExCk, compiler-native, local best-effort, lossy spec, and shape-only, update `minimumTrust` to filter those levels precisely.

- [ ] Replace parameter-name string parsing with a structured ElixirSense API.
  - The provider still parses rendered signatures/defaults to compute parameter hints.
  - ElixirSense should return effective params for a concrete MFA/arity, including default handling, macros, imports, and generated heads.
  - This keeps signature semantics out of the LSP layer and avoids future drift.

- [ ] Revisit obvious-binding suppression after compiler-style rendering stabilizes.
  - Suppression is now less aggressive for constructors with non-literal leaves, but literal/struct patterns can still hide useful compiler-normalized information.
  - Add tests for `%Struct{} = remote()`, `{:ok, value} = remote()`, destructuring from external calls, and remote calls returning structs with inferred fields.

## P2 - UX And Protocol

- [ ] Consider lazy `inlayHint/resolve` or label parts for large type text.
  - `full` is capped in ElixirSense and placed in `tooltip` only when truncated.
  - For very large compiler types, `resolve_provider: true` could avoid sending tooltip text for every hint up front.

- [ ] Add an explicit `maxFullLength` setting if tooltip caps need user control.
  - ElixirSense defaults `max_full_length` to 1000, but ElixirLS does not expose it.
  - Keep the default conservative; expose only if users need it.

- [ ] Add return-type call hints only after variable hints are trustworthy.
  - The stated goal mentions accurate types for remote calls; variable bindings cover `x = Mod.f()` indirectly, but not standalone calls.
  - If added, implement as opt-in and route entirely through ElixirSense remote-call typing.

- [ ] Keep backend status in logs/telemetry, not labels.
  - One-time log exists. Add telemetry/debug details if needed, but labels should remain clean compiler-style type text.

- [ ] Verify Unicode positions in a provider/server-level test.
  - Codepoint arithmetic is fixed in the provider, but add an LSP UTF-16 assertion with non-ASCII identifiers to guard future regressions.

## P3 - Performance And Maintenance

- [ ] Cache per-request bindings/type-hint results.
  - Each variable hint may call `Binding.from_env/3` and resolve local sigs.
  - Cache by `{env identity, cursor_position}` or use a future ElixirSense API that handles caching internally.

- [ ] Benchmark inlay hints on large files.
  - Token indexing is improved, but native typing can still affect metadata generation and hint resolution.
  - Measure large files with many variables/calls and whole-document client ranges.

- [ ] Keep parameter-name hints independent from type inference.
  - Tests cover disabled native typing. Preserve this property as settings and provider logic evolve.

- [ ] Update extension docs.
  - Document `variableTypes.enabled`, `showOnlyBindings`, `maxLength`, `minimumTrust`, `parameterNames.enabled`, the runtime env kill switch, and the experimental status of variable type hints.

## Acceptance Criteria Before Shipping

- [ ] No absolute local path dependencies remain.
- [ ] Remote-call variables show compiler-style return types when ExCk/native data is available.
- [ ] Current-file hints are clearly best-effort unless backed by native descriptors.
- [ ] ElixirLS consumes a stable ElixirSense hint API and does not inspect private Elixir typesystem data.
- [ ] Type inference failures skip affected type hints without breaking parameter hints or the LSP request.
