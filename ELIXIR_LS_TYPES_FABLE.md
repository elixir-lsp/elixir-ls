# ElixirLS inlay hints / types integration — consolidated backlog (Fable)

Third review pass, 2026-06-11. This file is now the SINGLE prioritized backlog for the
elixir-ls side, consolidating:
- ELIXIR_LS_TYPES_GPT.md (second GPT review, same date)
- ELIXIR_LS_TYPES_GEMINI.md (Gemini review, lives in the main elixir-ls checkout)
- the two earlier Fable audit/fix rounds (full details in git history of this file:
  commits a258201f, 38f886e4)

Every inherited claim was re-verified against the current `inlay-hints` branch.
Gates at review time: inlay_hints 51/51 · provider suites (hover, hover/docs,
completion suggestions) 345 green · `MIX_ENV=test mix format --check-formatted` ✅.
Known pre-existing failures (NOT from this work): the three
`ModuleWithTypespecs.Remote` locator hangs and the env-fragile markdown version test
(see git history of this file for details).

## Verification verdicts on second-round claims

| Claim (source) | Verdict |
|---|---|
| `Binding.from_env/3` called per variable hint (Gemini perf) | **Confirmed.** `variable_hint/5` calls `Metadata.get_env` + `Binding.from_env` once per rendered hint (`inlay_hints.ex:292-293`); 100 viewport variables → 100 of each. No batching/memoization. |
| Read-occurrence hints reuse the binding-site VarInfo (GPT/Gemini) | **Confirmed but reframed.** Reads showing the binding type is semantically correct for most code; flow-sensitive narrowing is the refinement. `showOnlyBindings` defaults to `true` (provider + package.json), so reads are off by default. Downgraded to P2-with-docs. |
| Tooltip payload bloat (Gemini) | **Bounded.** Tooltip is set only when the label was elided; the dep caps `full` at 1000 graphemes; worst case ≈200 KB at 200 long-type hints. `resolve_provider: false` is correct today; lazy resolve is premature until real responses are measured. |
| Param-name extraction still string-parses signatures (GPT) | **Confirmed (improved).** `parse_param/1` splits on `" \\ "` with `parts: 2` (multiple `\\` handled); pattern-match defaults like `%{} = opts \\ %{}` are silently DROPPED by `clean_identifier?` (no wrong label, but a lost hint). |
| New-bug sweep of a258201f + 38f886e4 | **Mostly clean.** minimumTrust gating ordering is sound (`:shape` drops don't count against `@max_hints`); persistent_term key is fine. One real nit: `clamp_range` uses `el - sl > @max_range_lines`, letting exactly-1001-line ranges through (should be `>=`). Clamp-from-start policy is correct for viewport clients. |
| No server-level/ExCk end-to-end tests (GPT P0) | **Confirmed absent.** Zero `textDocument/inlayHint` server-layer tests; all 51 tests use `ParserContextBuilder.from_string/1`; no compiled-module/ExCk fixture coverage. |

## P0 — Release blockers (gates, not code bugs)

### 0.1 Remove the private local path dependency before merge/release
`apps/{language_server,elixir_ls_utils,debug_adapter}/mix.exs` point at
`/Users/lukaszsamson/elixir_sense/.claude/worktrees/trusting-wu-d1f603`; mix.lock pins
a ref without the new APIs. Repoint `@dep_versions[:elixir_sense]` once the
elixir_sense branch lands, and add a CI grep rejecting `path: "/Users/` deps.
[all three audits — blocked on publishing elixir_sense]

### 0.2 Decide release defaults for variable type hints
`variableTypes.enabled` and native inference both default on. Options if shipping
before the elixir_sense backlog burns down: parameterNames on / variableTypes off, or
default `minimumTrust: "native"`. Keep the runtime `ELIXIR_LS_TYPE_INFERENCE` kill
switch documented. [GPT]

## P1 — DONE (fix wave, 2026-06-11 evening)

All four P1 items shipped (commit follows this update):
- **1.1** Provider fully rewired onto `ElixirSense.Core.TypeHints`: one
  `request_context` per request (process-dict caches shared across all hints);
  `Binding`/`TypePresentation` no longer referenced in the LSP layer.
- **1.2** Server-level e2e suite (`server_inlay_hints_test.exs`, real Server GenServer):
  capability advertisement, full request round-trip with JSON-encodable structs,
  sub-range scoping, exact UTF-16 position for non-ASCII identifiers (closes 2.5),
  cancellation robustness.
- **1.3** ExCk compiled-fixture integration suite (`inlay_hints_integration_test.exs`):
  beam written to a tmp code path, remote-call binding hint asserted, degradation
  without the fixture, minimumTrust interplay.
- **1.4** `parse_param` string-splitting deleted; param names come from
  `TypeHints.effective_params/4` (AST-level) — pattern-match defaults like
  `%{} = opts \\ %{}` now produce an `opts:` hint instead of being dropped.
- **2.3** (pulled forward) `clamp_range` processes at most 1000 lines inclusive,
  boundary-tested.

Combined gates after the wave: 362 tests green across inlay unit + integration +
server e2e + hover/docs/completion; format clean.

## P1 (historical) — Correctness, layering, coverage

### 1.1 Consume the elixir_sense facade (kills the per-hint cost and the layering leak)
Blocked on elixir_sense backlog item 1.2 (`type_hint_for_var/4`). Once available,
`variable_hint/5` stops assembling `get_env`/`Binding.from_env`/`render_hint` per hint;
the facade owns per-request caching. Until then, an interim mitigation is possible
provider-side: group hint positions by env scope and reuse one binding per scope.
[Gemini perf — verified; GPT layering]

### 1.2 Server-level end-to-end test for `textDocument/inlayHint`
Capability advertisement, async dispatch, dirty-buffer source, range handling, JSON
encoding, cancellation. Currently zero coverage above the provider unit level.
[GPT P0 — verified absent]

### 1.3 ExCk-backed remote-call integration tests
Compile a fixture module (real beam with ExCk chunk), call it remotely in the buffer,
assert the displayed hint text; cover missing-chunk and version-mismatch degradation.
This is the project's headline feature and currently untested end-to-end.
[GPT P0 + Gemini P2 — verified absent]

### 1.4 Structured parameter API
Replace `parse_param/1` string-splitting with an elixir_sense API returning effective
params per concrete arity (`{name, has_default}` at AST level). Also fixes the silent
hint loss for pattern-match defaults (`%{} = opts \\ %{}`). [GPT — verified]

## Wave 3 status (2026-06-11 evening — GPT third-review fixes)

Done this wave (details in ELIXIR_LS_TYPES_GPT.md status block and commit 372c9291):
- **2.1 done** — minimumTrust supports compiler | native | bestEffort via
  `TypeHints.trust_rank/1`; ExCk-backed remote calls classify `:native_exck` in
  practice; unknown future sources fail safe to weakest.
- **2.4 done** — destructuring suppression policy locked in by tests.
- Expanded ExCk integration coverage (overloads by arg type, version mismatch,
  missing chunk) and extension docs/schema (vscode repo, uncommitted there).

Still open: P0 release mechanics (path dep, defaults), 2.2 read-occurrence policy
docs/flow-sensitivity, 2.5 done earlier, P3 items (lazy resolve parked, benchmarks).

## P2 — UX and precision

- **2.1 Richer `minimumTrust` levels** — blocked on elixir_sense 1.4 exposing
  `:native_exck | :native_inferred | :spec | :shape`; map the setting onto them
  (`compiler | native | bestEffort`). [GPT]
- **2.2 Read-occurrence policy** — keep `showOnlyBindings: true` default; document the
  binding-type semantics of read hints. Flow-sensitive reads need an elixir_sense
  position-env API (long-term, pairs with the facade). [GPT/Gemini — reframed]
- **2.3 `clamp_range` off-by-one** — `>` → `>=` (one character, fold into the next fix
  batch). [this pass]
- **2.4 Obvious-suppression coverage** — tests for `%Struct{} = remote()`,
  `{:ok, value} = remote()`, destructuring from external calls returning structs with
  inferred fields; revisit whether struct-pattern suppression hides useful
  compiler-normalized info. [GPT]
- **2.5 Server-level Unicode/UTF-16 assertion** — provider arithmetic is codepoint-safe
  and unit-tested; add one request-level test with non-ASCII identifiers as a
  regression guard. [GPT + Gemini]

## P3 — Protocol polish, perf, docs

- **3.1 Lazy `inlayHint/resolve` or label parts** — premature: tooltips are conditional
  and capped (~200 KB worst case at 200 hints). Revisit if real-world measurements show
  oversized responses. [Gemini — verified bounded]
- **3.2 `maxFullLength` setting** — expose only if users ask; dep default (1000) is
  conservative. [GPT]
- **3.3 Return-type call hints** — opt-in, only after variable hints are trustworthy,
  routed entirely through elixir_sense remote-call typing. [GPT]
- **3.4 Benchmarks on large files** — whole-document ranges, many variables/calls;
  pairs with elixir_sense 3.1. [GPT]
- **3.5 Extension docs** — document all `elixirLS.inlayHints.*` settings (incl.
  `minimumTrust`), the env kill switch, and the experimental status. The settings
  schema (incl. minimumTrust) already exists in vscode-elixir-ls package.json —
  uncommitted in that repo. [GPT]

## Closed this pass (no action needed)

- Gemini tooltip-bloat P1 — bounded by design (conditional tooltip + 1000-grapheme cap).
- minimumTrust gating ordering / persistent_term marker / `parts: 2` default splitting —
  verified sound.
- All items listed as Done in the status block of ELIXIR_LS_TYPES_GPT.md (runtime
  toggle, default-param mapping, range clamping, codepoint positions, tooltip via
  render_hint/3, local-only blocklist, `__MODULE__` receivers, all-literal suppression,
  token indexing, minimumTrust setting + schema, backend-status log, failure-mode and
  param-independence tests).
