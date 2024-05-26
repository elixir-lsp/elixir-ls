:persistent_term.put(:language_server_test_mode, true)
Application.ensure_started(:stream_data)
type_inference = Code.ensure_loaded?(ElixirSense.Core.Compiler)
ExUnit.start(exclude: [pending: true, requires_source: true, type_inference: type_inference])
