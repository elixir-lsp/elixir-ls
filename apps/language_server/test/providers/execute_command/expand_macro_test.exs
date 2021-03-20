defmodule ElixirLS.LanguageServer.Providers.ExecuteCommand.ExpandMacroTest do
  use ExUnit.Case

  alias ElixirLS.LanguageServer.{Server, SourceFile}
  alias ElixirLS.LanguageServer.Providers.ExecuteCommand.ExpandMacro

  test "nothing to expand" do
    uri = "file:///some_file.ex"

    text = """
    defmodule Abc do
      use ElixirLS.Test.MacroA
    end
    """

    assert {:ok, res} =
             ExpandMacro.execute([uri, "", 1], %Server{
               source_files: %{
                 uri => %SourceFile{
                   text: text
                 }
               }
             })

    assert res == %{
             "expand" => "\n",
             "expandAll" => "\n",
             "expandOnce" => "\n",
             "expandPartial" => "\n"
           }

    assert {:ok, res} =
             ExpandMacro.execute([uri, "abc", 1], %Server{
               source_files: %{
                 uri => %SourceFile{
                   text: text
                 }
               }
             })

    assert res == %{
             "expand" => "abc\n",
             "expandAll" => "abc\n",
             "expandOnce" => "abc\n",
             "expandPartial" => "abc\n"
           }
  end

  test "expands macro" do
    uri = "file:///some_file.ex"

    text = """
    defmodule Abc do
      use ElixirLS.Test.MacroA
    end
    """

    assert {:ok, res} =
             ExpandMacro.execute([uri, "use ElixirLS.Test.MacroA", 1], %Server{
               source_files: %{
                 uri => %SourceFile{
                   text: text
                 }
               }
             })

    assert res == %{
             "expand" => """
             require(ElixirLS.Test.MacroA)
             ElixirLS.Test.MacroA.__using__([])
             """,
             "expandAll" => """
             require(ElixirLS.Test.MacroA)

             (
               import(ElixirLS.Test.MacroA)

               def(macro_a_func) do
                 :ok
               end
             )
             """,
             "expandOnce" => """
             require(ElixirLS.Test.MacroA)
             ElixirLS.Test.MacroA.__using__([])
             """,
             "expandPartial" => """
             require(ElixirLS.Test.MacroA)

             (
               import(ElixirLS.Test.MacroA)

               def(macro_a_func) do
                 :ok
               end
             )
             """
           }
  end
end
