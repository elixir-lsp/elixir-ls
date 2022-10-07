defmodule ElixirLS.LanguageServer.Experimental.SourceFile.DocumentTest do
  alias ElixirLS.LanguageServer.Experimental.SourceFile.Document
  alias ElixirLS.LanguageServer.Experimental.SourceFile.Line

  use ExUnit.Case, async: true
  use ExUnitProperties

  import Line

  describe "Document Enumerable" do
    test "it should be able to be fetched by line number" do
      d = Document.new("hello\nthere\npeople")
      assert line(text: "hello") = Enum.at(d, 0)
      assert line(text: "there") = Enum.at(d, 1)
      assert line(text: "people") = Enum.at(d, 2)
      assert nil == Enum.at(d, 3)
    end
  end

  property "always creates valid binaries" do
    check all(
            elements <-
              list_of(
                one_of([
                  string(:printable),
                  one_of([constant("\r\n"), constant("\n"), constant("\r")])
                ])
              )
          ) do
      document =
        elements
        |> IO.iodata_to_binary()
        |> Document.new()

      for line(text: text, ending: ending) <- document do
        assert String.valid?(text)
        assert ending in ["\r\n", "\n", "\r", ""]
      end
    end
  end

  property "to_string recreates the original" do
    check all(
            elements <-
              list_of(
                one_of([
                  string(:printable),
                  one_of([constant("\r\n"), constant("\n"), constant("\r")])
                ])
              )
          ) do
      original_binary = List.to_string(elements)
      document = Document.new(original_binary)
      assert Document.to_string(document) == original_binary
    end
  end

  property "size reflects the original line count" do
    check all(elements <- list_of(string(:alphanumeric, min_length: 2))) do
      line_count = Enum.count(elements)
      original_binary = elements |> Enum.join("\n") |> IO.iodata_to_binary()

      document = Document.new(original_binary)
      assert Document.size(document) == line_count
    end
  end
end
