defmodule ElixirLS.LanguageServer.SourceFileTest do
  use ExUnit.Case, async: true

  alias ElixirLS.LanguageServer.SourceFile

  test "format_spec/2 with nil" do
    assert SourceFile.format_spec(nil, []) == ""
  end

  test "format_spec/2 with empty string" do
    assert SourceFile.format_spec("", []) == ""
  end

  test "format_spec/2 with a plain string" do
    spec = "@spec format_spec(String.t(), keyword()) :: String.t()"

    assert SourceFile.format_spec(spec, line_length: 80) == """

           ```
           @spec format_spec(String.t(), keyword()) :: String.t()
           ```
           """
  end

  test "format_spec/2 with a spec that needs to be broken over lines" do
    spec = "@spec format_spec(String.t(), keyword()) :: String.t()"

    assert SourceFile.format_spec(spec, line_length: 30) == """

           ```
           @spec format_spec(
             String.t(),
             keyword()
           ) :: String.t()
           ```
           """
  end
end
