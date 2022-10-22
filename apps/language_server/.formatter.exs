impossible_to_format = [
  "test/fixtures/token_missing_error/lib/has_error.ex",
  "test/fixtures/project_with_tests/test/error_test.exs"
]

[
  inputs:
    Enum.flat_map(
      [
        "*.exs",
        "{lib,test,config}/**/*.{ex,exs}"
      ],
      &Path.wildcard(&1, match_dot: true)
    ) -- impossible_to_format
]
