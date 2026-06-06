:persistent_term.put(:debug_adapter_test_mode, true)
ExUnit.start(exclude: [pending: true])

# make sure that OTP debugger modules are in code path
# without starting the app
Mix.ensure_application!(:debugger)
