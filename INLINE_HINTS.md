# Inline Hints: Design & Plan

## Goal
Add LSP inlay hints for two cases:
- Variable types (kind: `type`)
- Call parameter names (kind: `parameter`)

## Wiring in server
- Add provider module: `ElixirLS.LanguageServer.Providers.InlayHints` with `inlay_hints(parser_context, range)`.
- Handle request in `apps/language_server/lib/language_server/server.ex`:
  - Match `GenLSP.Requests.TextDocumentInlayHint`.
  - Convert LSP range to Elixir `{line, column}` with `SourceFile.lsp_position_to_elixir/2`.
  - `parser_context = Parser.parse_immediate(uri, source_file, {line, col})`.
  - Call provider and return `{:ok, list_of_inlay_hints}`.
- Advertise capability in `server_capabilities/1`:
  - `inlay_hint_provider: %GenLSP.Structures.InlayHintOptions{resolve_provider: false}`.

## Provider approach
Input: `Parser.Context{source_file, metadata}`, LSP `range`.
Output: list of `GenLSP.Structures.InlayHint`.

### Variable type hints
- Discover variables from metadata:
  - Iterate `metadata.vars_info_per_scope_id` and each `VarInfo.positions`.
  - Filter occurrences inside requested range.
- Compute type shape per variable occurrence:
  - `env = ElixirSense.Core.Metadata.get_env(metadata, {line, column})`.
  - `binding_env = ElixirSense.Core.Binding.from_env(env, metadata, {line, column})`.
  - `shape = ElixirSense.Core.Binding.expand(binding_env, {:variable, name, version})`.
- Render concise label from shape (coarse pretty-printer):
  - `{:atom, m}` -> `inspect(m)`; `{:struct, _, {:atom, mod}, _}` -> `%Mod{}`; `{:map, _, _}` -> `map`; `{:list, t}` -> `[t]`; unions/unknown -> `any`.
- Build hint:
  - `position`: just after the variable token (convert with `SourceFile.elixir_character_to_lsp/2`).
  - `label`: `": " <> rendered_shape`.
  - `kind`: `GenLSP.Enumerations.InlayHintKind.type()`.

Notes: See patterns in providers `Hover`/`Definition` for metadata/env usage. Example metadata APIs used there:
- `Parser.parse_immediate/3`, `ElixirSense.Core.Metadata.get_env/2`, `ElixirSense.Core.Binding.from_env/3`, `ElixirSense.Core.Binding.expand/2`.

### Call parameter name hints
- Get calls from metadata:
  - For each line in range, use `ElixirSense.Core.Metadata.get_calls(metadata, line)`.
  - Filter calls by column within range.
- Resolve MFA:
  - For each call position `{line, col}`, build `binding_env` as above.
  - Use `ElixirSense.Core.Introspection.actual_mod_fun({mod, fun}, env, metadata.mods_funs_to_positions, metadata.types, {line, col}, false)`.
- Get parameter names:
  - Prefer local defs: lookup `metadata.mods_funs_to_positions[{mod, fun, arity}]` and take `ModFunInfo.params |> List.last() |> Enum.with_index() |> Enum.map(&Introspection.param_to_var/1)`.
  - Fallback to docs: `ElixirSense.Core.Metadata.get_function_signatures(metadata, mod, fun)`; if empty, use `ElixirSense.Core.Introspection.get_signatures(mod, fun)` (internally backed by `ElixirSense.Core.Normalized.Code.get_docs/2`).
- Place hints:
  - Phase 1 (simple): one hint at call open paren with label like `"(a:, b:, c:)"`, kind `parameter`.
  - Phase 2 (accurate): parse AST to get each argument position:
    - Parse whole file with `Code.string_to_quoted/2` (options: `columns: true, token_metadata: true`).
    - Find call AST whose meta line/column matches `CallInfo.position`.
    - For each arg node, use its meta to place a `parameter` hint right before the arg with label like `"a:"`.

### Ranges and positions
- Convert LSP positions using `SourceFile.lsp_position_to_elixir/2` and `SourceFile.elixir_character_to_lsp/2` when building `GenLSP.Structures.Position`.
- Only emit hints for occurrences strictly within the requested range.

## Shapes to string (sketch)
Provide a small helper in the provider:
- `nil | :none | :no_spec` -> `any`
- `{:atom, a}` -> if `is_atom(a)`, `inspect(a)`; modules render as `%Mod{}` when used as struct.
- `{:struct, _fields, {:atom, m}, _}` -> `%#{inspect(m)}{}`
- `{:map, _fields, _}` -> `map`
- `{:list, t}` -> `[shape(t)]`
- `{:tuple, n, _}` -> `{n}`
- Fallback: `any`.

## Testing & toggles
- Behind settings flags (e.g., `inlayHints.variableTypes`, `inlayHints.parameterNames`), default on.
- Add fast paths and bail-outs for large ranges or parse errors.
- Validate on typical files and edge cases (pipes, default args, macros).

## References
- Server wiring: `apps/language_server/lib/language_server/server.ex` (see Hover/Definition/SignatureHelp clauses).
- Metadata APIs: `ElixirSense.Core.Metadata.{get_env,get_calls,get_call_arity,mods_funs_to_positions}`.
- Binding/type shape: `ElixirSense.Core.Binding.{from_env,expand}`.
- Signatures/docs: `ElixirSense.Core.Metadata.get_function_signatures/3`, `ElixirSense.Core.Introspection.get_signatures/2`, `ElixirSense.Core.Normalized.Code.get_docs/2`.
- Parameter names: `ElixirSense.Core.State.ModFunInfo` and `ElixirSense.Core.Introspection.param_to_var/1`.
