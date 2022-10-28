defmodule ElixirLS.Experimental.FormatterTest do
  alias ElixirLS.LanguageServer.Experimental.Format
  alias ElixirLS.LanguageServer.Experimental.SourceFile

  use ExUnit.Case

  def source_file(text) do
    SourceFile.new("file://#{__ENV__.file}", text, 1)
  end

  def apply_format(text) do
    source = source_file(text)
    Format.format(source, File.cwd!())
  end

  def elixir_format(text) do
    iodata = Code.format_string!(text, [])

    IO.iodata_to_binary([iodata, ?\n])
  end

  def unformatted do
    """
    defmodule Unformatted do
    def something()do
    end
    end
    """
  end

  describe "format/2" do
    test "it should be able to forma a file in the project" do
      assert {:ok, formatted} = apply_format(unformatted())
      assert formatted == elixir_format(unformatted())
    end

    test "it should be able to format a file when the project isn't specified" do
      assert {:ok, formatted} = unformatted() |> source_file() |> Format.format(nil)
      assert formatted == elixir_format(unformatted())
    end

    test "it should provide an error for a syntax error" do
      missing_comma = """
      def foo(a, ) do
        true
      end
      """

      assert {:error, %SyntaxError{}} = apply_format(missing_comma)
    end

    test "it should provide an error for a missing token" do
      missing_token = """
      defmodule TokenMissing do
       :bad
      """

      assert {:error, %TokenMissingError{}} = apply_format(missing_token)
    end

    test "it correctly handles unicode" do
      orig = """
      {"🎸",    "o"}
      """

      expected = """
      {"🎸", "o"}
      """

      assert {:ok, formatted} = apply_format(orig)
      assert expected == formatted
    end
  end
end
