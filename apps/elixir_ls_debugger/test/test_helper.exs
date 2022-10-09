Application.put_env(:elixir_ls_debugger, :test_mode, true)
ExUnit.start(exclude: [pending: true])
