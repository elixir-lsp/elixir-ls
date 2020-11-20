Application.put_env(:language_server, :test_mode, true)
ExUnit.start(exclude: [pending: true])
