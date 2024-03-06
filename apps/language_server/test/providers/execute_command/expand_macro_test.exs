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

    if Version.match?(System.version(), "< 1.13.0") do
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
    else
      assert res == %{
               "expand" => """
               require ElixirLS.Test.MacroA
               ElixirLS.Test.MacroA.__using__([])
               """,
               "expandAll" => """
               require ElixirLS.Test.MacroA

               (
                 import ElixirLS.Test.MacroA

                 def macro_a_func do
                   :ok
                 end
               )
               """,
               "expandOnce" => """
               require ElixirLS.Test.MacroA
               ElixirLS.Test.MacroA.__using__([])
               """,
               "expandPartial" => """
               require ElixirLS.Test.MacroA

               (
                 import ElixirLS.Test.MacroA

                 def macro_a_func do
                   :ok
                 end
               )
               """
             }
    end
  end

  describe "expand full" do
    test "without errors" do
      buffer = """
      defmodule MyModule do

      end
      """

      code = "use Application"
      result = ExpandMacro.expand_full(buffer, code, 2)

      assert result.expand_once =~
               """
               (
                 require Application
                 Application.__using__([])
               )
               """
               |> String.trim()

      assert result.expand =~
               """
               (
                 require Application
                 Application.__using__([])
               )
               """
               |> String.trim()

      assert result.expand_partial =~
               """
               (
                 require Application

                 (
                   @behaviour Application
                   @doc false
                   def stop(_state) do
                     :ok
                   end

                   defoverridable Application
                 )
               )
               """
               |> String.trim()

      assert result.expand_all =~
               (if Version.match?(System.version(), ">= 1.14.0") do
                  """
                  (
                    require Application

                    (
                      Module.__put_attribute__(MyModule, :behaviour, Application, nil, [])
                      Module.__put_attribute__(MyModule, :doc, {0, false}, nil, [])

                      def stop(_state) do
                        :ok
                      end

                      Module.make_overridable(MyModule, Application)
                  """
                else
                  """
                  (
                    require Application

                    (
                      Module.__put_attribute__(MyModule, :behaviour, Application, nil)
                      Module.__put_attribute__(MyModule, :doc, {0, false}, nil)

                      def stop(_state) do
                        :ok
                      end

                      Module.make_overridable(MyModule, Application)
                  """
                end)
               |> String.trim()
    end

    test "with errors" do
      buffer = """
      defmodule MyModule do

      end
      """

      code = "{"
      result = ExpandMacro.expand_full(buffer, code, 2)

      assert result.expand_once =~
               """
               "missing terminator: }\
               """
               |> String.trim()

      assert result.expand =~
               """
               "missing terminator: }\
               """
               |> String.trim()

      assert result.expand_partial =~
               """
               "missing terminator: }\
               """
               |> String.trim()

      assert result.expand_all =~
               """
               "missing terminator: }\
               """
               |> String.trim()
    end
  end
end
