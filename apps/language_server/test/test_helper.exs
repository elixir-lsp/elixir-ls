if Version.match?(System.version(), ">= 1.11.0") do
  Code.put_compiler_option(:warnings_as_errors, true)
end

Application.put_env(:language_server, :test_mode, true)
Application.ensure_started(:stream_data)
ExUnit.start(exclude: [pending: true])
