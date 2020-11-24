Application.put_env(:language_server, :test_mode, true)
Application.ensure_started(:stream_data)
ExUnit.start(exclude: [pending: true])
