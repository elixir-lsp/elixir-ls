:persistent_term.put(:language_server_test_mode, true)
Application.ensure_started(:stream_data)
ExUnit.start(exclude: [pending: true, requires_source: true])
