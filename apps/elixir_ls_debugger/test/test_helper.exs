Application.put_env(:elixir_ls_debugger, :test_mode, true)
ExUnit.start(exclude: [pending: true])

if Version.match?(System.version(), ">= 1.15.0-dev") do
  # make sue that debugger modules are in code path
  # without starting the app
  Mix.ensure_application!(:debugger)
end
