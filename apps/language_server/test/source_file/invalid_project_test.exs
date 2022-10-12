defmodule ElixirLS.LanguageServer.SourceFile.InvalidProjectTest do
  use ExUnit.Case, async: false

  use Patch
  alias ElixirLS.LanguageServer.SourceFile
  import ExUnit.CaptureLog

  describe "formatter_for " do
    test "should handle syntax errors" do
      patch(Mix.Tasks.Format, :formatter_for_file, fn _ ->
        raise %SyntaxError{file: ".formatter.exs", line: 1}
      end)

      output =
        capture_log(fn ->
          assert :error = SourceFile.formatter_for("file:///root.ex")
        end)

      assert String.contains?(output, "Unable to get formatter options")
    end

    test "should handle compile errors" do
      patch(Mix.Tasks.Format, :formatter_for_file, fn _ ->
        raise %SyntaxError{file: ".formatter.exs", line: 1}
      end)

      output =
        capture_log(fn ->
          assert :error = SourceFile.formatter_for("file:///root.ex")
        end)

      assert String.contains?(output, "Unable to get formatter options")
    end
  end
end
