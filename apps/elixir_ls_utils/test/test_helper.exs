if Version.match?(System.version(), ">= 1.11.0") do
  Code.put_compiler_option(:warnings_as_errors, true)
end

ExUnit.start(exclude: [pending: true])
