:persistent_term.put(:language_server_test_mode, true)
Application.ensure_started(:stream_data)

# Silence the ElixirSense native-typing backend's verbose degradation logs for
# the test suite. On Elixir 1.18/1.19 the adaptor probes evolving Module.Types
# internals that can still crash on not-yet-expanded macros (Record/defguard/
# struct patterns); each crash is caught and degraded gracefully, but logs a
# full formatted stack trace plus an inspected body. Hundreds of these
# multi-kilobyte entries (driven by locator/definition tests that compile real
# fixtures) flood the suite and can OOM/kill a memory-capped CI runner under log
# capture.
#
# This is scoped to the *offending dep modules* via per-module Logger levels —
# NOT a global level change — so the language server's own LSP logging (which
# several ServerTest/WorkspaceSymbols tests assert flows through to
# `window/logMessage`) is left fully intact.
for mod <- [ElixirSense.Core.ElixirTypes, ElixirSense.Core.Compiler] do
  Logger.put_module_level(mod, :none)
end

type_inference = Code.ensure_loaded?(ElixirSense.Core.Compiler)

ExUnit.start(
  exclude: [
    pending: true,
    requires_source: true,
    type_inference: type_inference,
    release_smoke: true
  ]
)
