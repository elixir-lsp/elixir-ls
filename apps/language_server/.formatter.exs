impossible_to_format = [
  "test/fixtures/token_missing_error/lib/has_error.ex",
  "test/fixtures/project_with_tests/test/error_test.exs"
]

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
  import_deps: [:patch],
  export: [
    locals_without_parens: proto_dsl
  ],
  locals_without_parens: proto_dsl,
  inputs:
    Enum.flat_map(
      [
        "*.exs",
        "{lib,test,config}/**/*.{ex,exs}"
      ],
      &Path.wildcard(&1, match_dot: true)
    ) -- impossible_to_format
]
