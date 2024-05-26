current_directory = Path.dirname(__ENV__.file)

impossible_to_format = [
  Path.join([current_directory, "test", "fixtures", "token_missing_error", "lib", "has_error.ex"]),
  Path.join([
    current_directory,
    "test",
    "fixtures",
    "project_with_tests",
    "test",
    "error_test.exs"
  ]),
  Path.join(current_directory, "test/support/modules_with_references.ex")
]

deps =
  if Mix.env() == :test do
    [:patch]
  else
    []
  end

proto_dsl = [
  defalias: 1,
  defenum: 1,
  defnotification: 2,
  defnotification: 3,
  defrequest: 3,
  defresponse: 1,
  deftype: 1
]

[
  import_deps: deps,
  export: [
    locals_without_parens: proto_dsl
  ],
  locals_without_parens: proto_dsl,
  inputs:
    Enum.flat_map(
      [
        Path.join(current_directory, "*.exs"),
        Path.join(current_directory, "{lib,test}/**/*.{ex,exs}")
      ],
      &Path.wildcard(&1, match_dot: true)
    ) -- impossible_to_format
]
