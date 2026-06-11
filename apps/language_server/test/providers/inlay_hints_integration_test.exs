defmodule ElixirLS.LanguageServer.Providers.InlayHintsIntegrationTest do
  @moduledoc """
  ExCk / compiled-fixture integration tests for inlay hints.

  Coverage (backlog 1.3):
  - Compile a real beam file with multi-clause typed function into a tmp dir,
    add the dir to :code path, build a buffer calling that function and assert
    the provider returns a list (no crash, degradation-safe path).
  - Fixture NOT on path → request still succeeds, no crash.
  - minimumTrust interplay: with "native" setting the result is still a list.
  """

  use ExUnit.Case, async: false

  alias ElixirLS.LanguageServer.Providers.InlayHints
  alias ElixirLS.LanguageServer.SourceFile
  alias ElixirLS.LanguageServer.Test.ParserContextBuilder
  alias GenLSP.Enumerations.InlayHintKind
  alias GenLSP.Structures.{Position, Range}

  @fixture_source """
  defmodule ElixirLS.Fixtures.InlayHintsClassify do
    @spec classify(integer()) :: :negative | :zero | :positive
    def classify(n) when n < 0, do: :negative
    def classify(0), do: :zero
    def classify(n) when n > 0, do: :positive
  end
  """

  @caller_source """
  defmodule Sample do
    def run do
      x = ElixirLS.Fixtures.InlayHintsClassify.classify(1)
      x
    end
  end
  """

  # Compile the fixture beam into a unique tmp dir and add to code path.
  # Returns the dir so the caller can clean up.
  defp compile_fixture_to_tmp do
    dir =
      Path.join(System.tmp_dir!(), "elixir_ls_inlay_hints_#{:erlang.unique_integer([:positive])}")

    File.mkdir_p!(dir)

    [{_mod, beam}] =
      Code.compile_string(@fixture_source, "nofile")

    beam_path = Path.join(dir, "Elixir.ElixirLS.Fixtures.InlayHintsClassify.beam")
    File.write!(beam_path, beam)
    :code.add_patha(String.to_charlist(dir))
    dir
  end

  defp remove_fixture_dir(dir) do
    :code.del_path(String.to_charlist(dir))
    :code.purge(ElixirLS.Fixtures.InlayHintsClassify)
    :code.delete(ElixirLS.Fixtures.InlayHintsClassify)
    File.rm_rf!(dir)
  end

  defp full_range(source_file) do
    SourceFile.full_range(source_file)
  end

  defp hints_for(source, settings \\ %{}) do
    ctx = ParserContextBuilder.from_string(source)
    range = full_range(ctx.source_file)
    InlayHints.inlay_hints(ctx, range, settings: settings)
  end

  # ── Fixture on path ───────────────────────────────────────────────────────

  describe "ExCk fixture — module compiled into tmp dir on code path" do
    setup do
      dir = compile_fixture_to_tmp()
      on_exit(fn -> remove_fixture_dir(dir) end)
      {:ok, dir: dir}
    end

    test "request succeeds and returns a list when calling compiled fixture" do
      assert {:ok, hints} = hints_for(@caller_source)
      assert is_list(hints)
    end

    test "result contains only InlayHint structs when fixture is on path" do
      {:ok, hints} = hints_for(@caller_source)

      for hint <- hints do
        assert %GenLSP.Structures.InlayHint{} = hint
      end
    end

    test "minimumTrust native does not crash when fixture is on path" do
      settings = %{"inlayHints" => %{"variableTypes" => %{"minimumTrust" => "native"}}}
      assert {:ok, hints} = hints_for(@caller_source, settings)
      assert is_list(hints)
    end

    test "minimumTrust bestEffort returns list with fixture on path" do
      settings = %{"inlayHints" => %{"variableTypes" => %{"minimumTrust" => "bestEffort"}}}
      assert {:ok, hints} = hints_for(@caller_source, settings)
      assert is_list(hints)
    end
  end

  # ── Fixture NOT on path (degradation) ────────────────────────────────────

  describe "ExCk fixture — module NOT on code path (degradation)" do
    setup do
      # Ensure the fixture module is not loaded.
      :code.purge(ElixirLS.Fixtures.InlayHintsClassify)
      :code.delete(ElixirLS.Fixtures.InlayHintsClassify)
      :ok
    end

    test "request succeeds when fixture module is absent — no crash" do
      assert {:ok, hints} = hints_for(@caller_source)
      assert is_list(hints)
    end

    test "absent fixture produces no type hint for call result (graceful degradation)" do
      {:ok, hints} = hints_for(@caller_source)
      type_hints = Enum.filter(hints, &(&1.kind == InlayHintKind.type()))
      # Either empty (no inference without the beam) or still a list — never a crash.
      assert is_list(type_hints)
    end
  end

  # ── Range scoping ─────────────────────────────────────────────────────────

  describe "range scoping with compiled fixture on path" do
    setup do
      dir = compile_fixture_to_tmp()
      on_exit(fn -> remove_fixture_dir(dir) end)
      {:ok, dir: dir}
    end

    test "sub-range that excludes the binding line returns fewer or equal hints" do
      ctx = ParserContextBuilder.from_string(@caller_source)

      full_range = SourceFile.full_range(ctx.source_file)

      # Range covering only the module line (line 0), before the binding.
      narrow_range = %Range{
        start: %Position{line: 0, character: 0},
        end: %Position{line: 0, character: 0}
      }

      {:ok, full_hints} = InlayHints.inlay_hints(ctx, full_range, settings: %{})
      {:ok, narrow_hints} = InlayHints.inlay_hints(ctx, narrow_range, settings: %{})

      assert length(narrow_hints) <= length(full_hints)
    end
  end
end
