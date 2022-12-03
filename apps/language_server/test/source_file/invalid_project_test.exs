defmodule ElixirLS.LanguageServer.SourceFile.InvalidProjectTest do
  use ExUnit.Case, async: false

  use Patch
  alias ElixirLS.LanguageServer.SourceFile
  import ExUnit.CaptureLog

  def appropriate_formatter_function_name(_) do
    formatter_function =
      if Version.match?(System.version(), ">= 1.13.0") do
        :formatter_for_file
      else
        :formatter_opts_for_file
      end

    {:ok, formatter_name: formatter_function}
  end

  describe "formatter_for" do
    setup [:appropriate_formatter_function_name]

    test "should handle syntax errors", ctx do
      patch(Mix.Tasks.Format, ctx.formatter_name, fn _ ->
        raise %SyntaxError{file: ".formatter.exs", line: 1}
      end)

      output =
        capture_log(fn ->
          assert :error = SourceFile.formatter_for("file:///root.ex")
        end)

      assert String.contains?(output, "Unable to get formatter options")
    end

    test "should handle compile errors", ctx do
      patch(Mix.Tasks.Format, ctx.formatter_name, fn _ ->
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
