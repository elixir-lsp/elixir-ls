impossible_to_format = ["test/fixtures/token_missing_error/lib/has_error.ex"]

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
