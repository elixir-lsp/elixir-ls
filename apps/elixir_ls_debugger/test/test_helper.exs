if Version.match?(System.version(), ">= 1.11.0") do
  Code.put_compiler_option(:warnings_as_errors, true)
end

Application.put_env(:elixir_ls_debugger, :test_mode, true)
ExUnit.start(exclude: [pending: true])
