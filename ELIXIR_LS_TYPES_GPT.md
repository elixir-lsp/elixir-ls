# ElixirLS Types/Inlay Hints Audit Tasks

## Status after the 2026-06-11 fix pass (Fable)

Gates: inlay_hints 51/51 (+11 GPT-audit tests), provider suites (hover, hover/docs,
completion suggestions) 345 green total, `MIX_ENV=test mix format --check-formatted` ✅.

**Done:**
- "Type-hint policy behind an ElixirSense API" — the provider consumes
  `TypePresentation.render_hint/3` returning `{:ok, %{label, full, source}} | :skip`;
  suppression of term()/none()/dynamic(), truncation, literal widening, and tooltip
  capping all live in elixir_sense.
- "Compiler-style presentation" — hint labels widen literals to compiler spellings
  (`integer()`/`binary()`); tests assert no raw-literal leakage; descr-backed text is
  `to_quoted_string` parity-verified on the elixir_sense side.
- "Trust gating" — new `elixirLS.inlayHints.variableTypes.minimumTrust`
  ("native" | "bestEffort", default "bestEffort") drops `:shape`-sourced hints in
  native mode; parameter hints unaffected. Declared in vscode-elixir-ls package.json.
- "Backend status in logs" — one-time Logger.info on first request states
  compiler-native / structural-disabled / structural-unavailable.
- "Param-hint independence" + "failure-mode tests" — covered (inference disabled,
  nonexistent module, graceful degradation).

**Deferred:** flow-sensitive read-occurrence typing (needs an elixir_sense
position-env API); InlayHintLabelPart/resolve for very large types (tooltip is capped
at 1000 graphemes instead); end-to-end tests against ExCk-compiled project modules;
compile-time elixir_sense version pinning (blocked on publishing the elixir_sense
branch — same as the path-dep item in ELIXIR_LS_TYPES_FABLE.md).

---

Audit target: branch/worktree `/Users/lukaszsamson/vscode-elixir-ls/elixir-ls/.claude/worktrees/practical-roentgen-11f5aa`.

Related ElixirSense worktree: `/Users/lukaszsamson/elixir_sense/.claude/worktrees/trusting-wu-d1f603`.

Goal: provide LSP inlay hints that show accurate compiler-style types for remote calls to external modules and best-effort inferred types for current-file calls/variables, while keeping ElixirLS insulated from private Elixir `Module.Types` APIs.

## High Priority

- [ ] Move type-hint policy behind an ElixirSense API.
  - `ElixirLS.LanguageServer.Providers.InlayHints` currently builds a `Binding` and calls `TypePresentation.render_hint/3` directly.
  - ElixirLS should not decide how `VarInfo.type`, `VarInfo.elixir_types_descr`, compiler descriptors, shape expansion, fallback rendering, suppression, and truncation combine.
  - Add a stable ElixirSense function such as `Metadata.type_hint(metadata, position, var_info, opts)` or `TypePresentation.lsp_hint/4`, and have the provider consume only `:skip | {:ok, label/full/tooltip}`.

- [ ] Keep all private Elixir typesystem knowledge out of ElixirLS.
  - ElixirLS should not rely on `Module.Types.Descr`, ExCk chunks, native signature tuple shapes, or `elixir_types_descr` fields.
  - The provider should only pass source metadata/range/settings and display the stable string returned by ElixirSense.

- [ ] Gate type inlay hints on verified capability, not just default-on config.
  - `LanguageServer.main/0` enables `:use_elixir_types` by default through `ELIXIR_LS_TYPE_INFERENCE`.
  - If running on an Elixir version where the adapter partially disables native typing, ElixirLS should either surface only structural best-effort hints or disable type hints while keeping parameter-name hints.
  - Add a capability check and telemetry/log line that states which type source is active: compiler-native, ExCk-only, shape-only, or disabled.

- [ ] Require compiler-style presentation for type hints.
  - Hints should use the same type text style as official Elixir type warnings.
  - Add provider tests that assert no structural-only spellings leak into variable type hints unless explicitly accepted: literal `"foo"`/`1`, `not_set()`, `if_set(...)`, `struct()`, ad-hoc open tuple markers, or custom function formatting that conflicts with compiler output.
  - Prefer descriptor-rendered text from ElixirSense whenever available.

- [ ] Make remote-call hint scenarios first-class in tests.
  - Add integration tests where a variable is assigned from an external module call with ExCk/native signatures, for example stdlib calls returning structs, booleans, maps, tuples, and overloaded returns.
  - Assert the displayed type matches Elixir's compiler formatting and changes with argument types when the signature has multiple clauses.

## Provider Behavior

- [ ] Revisit "obvious binding" suppression once compiler-style types are available.
  - The provider suppresses `x = 1`, literal maps/lists/tuples, and `%Struct{} = var`.
  - That is reasonable for noise, but it can hide useful compiler-normalized types for literals with widened types, structs with default fields, and pattern matches where the source does not show the inferred return type.
  - Keep suppression configurable and add tests for `x = Some.remote()`, `%Struct{} = call()`, `{:ok, value} = remote()`, and destructuring assignments.

- [ ] Avoid showing hints for stale or untrusted best-effort types.
  - Current provider trusts `render_hint/3`; once ElixirSense exposes trust/source metadata, skip or visually downgrade `:legacy_spec_lossy` and `:shape_only` hints when they would look authoritative.
  - At minimum, do not show lossy current-file local inference as if it were compiler-native.

- [ ] Ensure read-occurrence hints use the environment at the occurrence, not only the binding.
  - With `showOnlyBindings=false`, the provider annotates every recorded variable position but passes the same `VarInfo` to `render_hint/3`.
  - For flow-sensitive refinements, the type at a read can differ from the binding type. Add an ElixirSense API that resolves the variable at the requested position/env.

- [ ] Add range/performance safeguards around type resolution.
  - The provider caps ranges and hint counts, but each variable hint may rebuild a binding and compute local signatures.
  - Cache per-request `Binding.from_env/3` and type-hint results by `{env, var, position}` once ElixirSense exposes a stable API.
  - Add tests or benchmarks for large files with many variables.

- [ ] Keep parameter-name hints independent from type inference.
  - The provider combines variable type hints and parameter-name hints. Type backend failures should not affect parameter hints.
  - Add regression tests where ElixirSense type inference is disabled/unavailable and parameter hints still work.

## LSP Semantics And UX

- [ ] Consider using `InlayHintLabelPart` or `data`/resolve for long type tooltips.
  - Current provider sets `resolve_provider: false` and embeds the full type in `tooltip` only when truncated.
  - For very large compiler types, prefer lazy resolution if client support is available, or cap tooltip size to avoid huge responses.

- [ ] Add source-aware settings.
  - Suggested settings:
    - `elixirLS.inlayHints.variableTypes.enabled`
    - `showOnlyBindings`
    - `maxLength`
    - `minimumTrust`: `compiler | native | bestEffort`
    - `includeReadOccurrences`
  - Keep defaults conservative until the ElixirSense adapter has compiler-comparison coverage.

- [ ] Surface backend status in logs, not in hints.
  - Users need a way to know whether hints are compiler-native or best-effort for debugging, but hint labels themselves should remain clean compiler-style type text.

- [ ] Ensure UTF-16 positions are correct for Unicode identifiers and labels.
  - `variable_hint/6` advances by `String.to_charlist/1` length before converting to UTF-16. Confirm this matches Elixir tokenizer columns for non-ASCII identifiers and combining marks.

## Integration With ElixirSense

- [ ] Pin compatible ElixirSense API/branch before merging.
  - This ElixirLS branch depends on new ElixirSense modules/fields (`TypePresentation`, `VarInfo.elixir_types_descr`, native signature metadata).
  - Add compile-time checks or version constraints so ElixirLS does not build against an older ElixirSense without those APIs.

- [ ] Do not duplicate module/function resolution for type hints in the provider.
  - Parameter hints currently resolve calls locally via `Introspection.actual_mod_fun/6`; type hints are variable-based through metadata.
  - If future call-return inlay hints are added, reuse the ElixirSense remote-call typing API instead of adding another resolver in ElixirLS.

- [ ] Add end-to-end tests with the real parser/build metadata path.
  - Current inlay hint tests use `ParserContextBuilder.from_string/1`.
  - Add tests for project modules compiled with ExCk chunks, current-file local definitions, aliases/imports/requires, default arguments, and modules loaded from dependencies.

- [ ] Add failure-mode tests.
  - Missing ExCk chunk.
  - ExCk version mismatch.
  - Elixir without the required `Module.Types` arities.
  - Module not loaded.
  - Parser metadata missing or stale.
  - Type adapter exception. Expected result: no type hint for that item, request still succeeds, parameter hints unaffected.

## Acceptance Criteria Before Shipping

- [ ] Remote calls to external modules display accurate compiler-style return types when ExCk/native signatures are available.
- [ ] Current-file local calls and variables display best-effort types only through an abstraction that records trust/source.
- [ ] No ElixirLS module reaches into private Elixir typesystem details.
- [ ] Type text in hints is generated by the same rendering path Elixir uses for type warnings whenever a native descriptor exists.
- [ ] All type-inference failures degrade to skipped type hints, not request failures.
