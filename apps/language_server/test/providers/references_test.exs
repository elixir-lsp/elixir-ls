defmodule ElixirLS.LanguageServer.Providers.ReferencesTest do
  use ExUnit.Case, async: true

  alias ElixirLS.LanguageServer.Providers.References
  alias ElixirLS.LanguageServer.SourceFile
  require ElixirLS.Test.TextLoc

  test "finds references to a function" do
    file_path = Path.join(__DIR__, "../support/references_b.ex") |> Path.expand()
    text = File.read!(file_path)
    uri = SourceFile.path_to_uri(file_path)

    {line, char} = {2, 8}

    ElixirLS.Test.TextLoc.annotate_assert(file_path, line, char, """
        some_var = 42
            ^
    """)

    ElixirLS.Utils.TestUtils.assert_match_list(
      References.references(text, uri, line, char, true),
      [
        %{
          "range" => %{
            "start" => %{"line" => 2, "character" => 4},
            "end" => %{"line" => 2, "character" => 12}
          },
          "uri" => uri
        },
        %{
          "range" => %{
            "start" => %{"line" => 4, "character" => 12},
            "end" => %{"line" => 4, "character" => 20}
          },
          "uri" => uri
        }
      ]
    )
  end

  test "cannot find a references to a macro generated function call" do
    file_path = Path.join(__DIR__, "../support/uses_macro_a.ex") |> Path.expand()
    text = File.read!(file_path)
    uri = SourceFile.path_to_uri(file_path)
    {line, char} = {6, 13}

    ElixirLS.Test.TextLoc.annotate_assert(file_path, line, char, """
        macro_a_func()
                 ^
    """)

    assert References.references(text, uri, line, char, true) == []
  end

  test "finds a references to a macro imported function call" do
    file_path = Path.join(__DIR__, "../support/uses_macro_a.ex") |> Path.expand()
    text = File.read!(file_path)
    uri = SourceFile.path_to_uri(file_path)
    {line, char} = {10, 4}

    ElixirLS.Test.TextLoc.annotate_assert(file_path, line, char, """
        macro_imported_fun()
        ^
    """)

    assert References.references(text, uri, line, char, true) == [
             %{
               "range" => %{
                 "start" => %{"line" => 10, "character" => 4},
                 "end" => %{"line" => 10, "character" => 22}
               },
               "uri" => uri
             }
           ]
  end

  test "finds references to a variable" do
    file_path = Path.join(__DIR__, "../support/references_b.ex") |> Path.expand()
    text = File.read!(file_path)
    uri = SourceFile.path_to_uri(file_path)
    {line, char} = {4, 14}

    ElixirLS.Test.TextLoc.annotate_assert(file_path, line, char, """
        IO.puts(some_var + 1)
                  ^
    """)

    assert References.references(text, uri, line, char, true) == [
             %{
               "range" => %{
                 "end" => %{"character" => 12, "line" => 2},
                 "start" => %{"character" => 4, "line" => 2}
               },
               "uri" => uri
             },
             %{
               "range" => %{
                 "end" => %{"character" => 20, "line" => 4},
                 "start" => %{"character" => 12, "line" => 4}
               },
               "uri" => uri
             }
           ]
  end
end
