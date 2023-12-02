:persistent_term.put(:debug_adapter_test_mode, true)
ExUnit.start(exclude: [pending: true])

if Version.match?(System.version(), ">= 1.15.0") do
  # make sue that OTP debugger modules are in code path
  # without starting the app
  Mix.ensure_application!(:debugger)
end
