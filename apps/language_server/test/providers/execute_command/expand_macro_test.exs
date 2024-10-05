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
             "expandOnce" => "\n"
           }

    assert {:ok, res} =
             ExpandMacro.execute([uri, "abc", 1], %Server{
               source_files: %{
                 uri => %SourceFile{
                   text: text
                 }
               }
             })

    if Version.match?(System.version(), ">= 1.15.0") do
      assert res == %{
               "expand" => "abc\n",
               "expandAll" => "abc\n",
               "expandOnce" => "abc\n"
             }
    else
      assert res == %{
               "expand" => "abc\n",
               "expandAll" => "abc()\n",
               "expandOnce" => "abc\n"
             }
    end
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
             require ElixirLS.Test.MacroA
             ElixirLS.Test.MacroA.__using__([])
             """,
             "expandAll" => """
             ElixirLS.Test.MacroA

             (
               ElixirLS.Test.MacroA
               {:macro_a_func, 0}
             )
             """,
             "expandOnce" => """
             require ElixirLS.Test.MacroA
             ElixirLS.Test.MacroA.__using__([])
             """
           }
  end

  describe "expand full" do
    test "without errors" do
      buffer = """
      defmodule MyModule do

      end
      """

      code = "use Application"
      result = ExpandMacro.expand_full(buffer, code, "nofile", 2)

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

      assert result.expand_all =~
               (if Version.match?(System.version(), ">= 1.14.0") do
                  """
                  Application

                  (
                    Application
                    @doc false
                    {:stop, 1}
                    nil
                  )
                  """
                else
                  if Version.match?(System.version(), "< 1.14.0") do
                    "Application\n\n(\n  Application\n  @doc false\n  {:stop, 1}\n  nil\n)"
                  else
                    """
                    (
                      require Application

                      (
                        Module.__put_attribute__(MyModule, :behaviour, Application, nil)
                        Module.__put_attribute__(MyModule, :doc, {2, false}, nil)

                        def stop(_state) do
                          :ok
                        end

                        Module.make_overridable(MyModule, Application)
                    """
                  end
                end)
               |> String.trim()
    end

    test "with errors" do
      buffer = """
      defmodule MyModule do

      end
      """

      code = "{"
      result = ExpandMacro.expand_full(buffer, code, "nofile", 2)

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

      assert result.expand_all =~
               """
               "missing terminator: }\
               """
               |> String.trim()
    end
  end
end
