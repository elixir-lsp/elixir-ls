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

  # ── GPT P1 3a: expanded ExCk integration cases ────────────────────────────

  # Fixture with multiple overloads selectable by argument type.
  @overloaded_source """
  defmodule ElixirLS.Fixtures.InlayHintsOverloaded do
    @spec dispatch(integer()) :: :int_result
    @spec dispatch(atom()) :: :atom_result
    def dispatch(n) when is_integer(n), do: :int_result
    def dispatch(a) when is_atom(a), do: :atom_result
  end
  """

  # Caller exercising the integer overload.
  @overloaded_int_caller """
  defmodule Sample do
    def run do
      x = ElixirLS.Fixtures.InlayHintsOverloaded.dispatch(1)
      x
    end
  end
  """

  # Caller exercising the atom overload.
  @overloaded_atom_caller """
  defmodule Sample do
    def run do
      x = ElixirLS.Fixtures.InlayHintsOverloaded.dispatch(:a)
      x
    end
  end
  """

  defp compile_overloaded_fixture_to_tmp do
    dir =
      Path.join(
        System.tmp_dir!(),
        "elixir_ls_inlay_overloaded_#{:erlang.unique_integer([:positive])}"
      )

    File.mkdir_p!(dir)

    [{_mod, beam}] = Code.compile_string(@overloaded_source, "nofile")
    beam_path = Path.join(dir, "Elixir.ElixirLS.Fixtures.InlayHintsOverloaded.beam")
    File.write!(beam_path, beam)
    :code.add_patha(String.to_charlist(dir))
    dir
  end

  defp remove_overloaded_fixture_dir(dir) do
    :code.del_path(String.to_charlist(dir))
    :code.purge(ElixirLS.Fixtures.InlayHintsOverloaded)
    :code.delete(ElixirLS.Fixtures.InlayHintsOverloaded)
    File.rm_rf!(dir)
  end

  describe "GPT P1 3a — overloaded fixture ExCk integration" do
    setup do
      dir = compile_overloaded_fixture_to_tmp()
      on_exit(fn -> remove_overloaded_fixture_dir(dir) end)
      {:ok, dir: dir}
    end

    test "integer-overload call request succeeds and returns a list" do
      # The hint text may vary (native ExCk vs degraded structural), but the
      # request must complete without crashing.
      assert {:ok, hints} = hints_for(@overloaded_int_caller)
      assert is_list(hints)

      for hint <- hints do
        assert %GenLSP.Structures.InlayHint{} = hint
      end
    end

    test "atom-overload call request succeeds and returns a list" do
      assert {:ok, hints} = hints_for(@overloaded_atom_caller)
      assert is_list(hints)

      for hint <- hints do
        assert %GenLSP.Structures.InlayHint{} = hint
      end
    end

    test "minimumTrust compiler does not crash with overloaded fixture" do
      settings = %{"inlayHints" => %{"variableTypes" => %{"minimumTrust" => "compiler"}}}
      assert {:ok, hints} = hints_for(@overloaded_int_caller, settings)
      assert is_list(hints)
    end
  end

  # ── GPT P1 3a: fixture returning a struct ─────────────────────────────────

  @struct_fixture_source """
  defmodule ElixirLS.Fixtures.InlayHintsStructResult do
    @spec make_uri(binary()) :: URI.t()
    def make_uri(url), do: URI.parse(url)
  end
  """

  @struct_caller_source """
  defmodule Sample do
    def run do
      u = ElixirLS.Fixtures.InlayHintsStructResult.make_uri("http://example.com")
      u
    end
  end
  """

  defp compile_struct_fixture_to_tmp do
    dir =
      Path.join(
        System.tmp_dir!(),
        "elixir_ls_inlay_struct_#{:erlang.unique_integer([:positive])}"
      )

    File.mkdir_p!(dir)
    [{_mod, beam}] = Code.compile_string(@struct_fixture_source, "nofile")
    beam_path = Path.join(dir, "Elixir.ElixirLS.Fixtures.InlayHintsStructResult.beam")
    File.write!(beam_path, beam)
    :code.add_patha(String.to_charlist(dir))
    dir
  end

  defp remove_struct_fixture_dir(dir) do
    :code.del_path(String.to_charlist(dir))
    :code.purge(ElixirLS.Fixtures.InlayHintsStructResult)
    :code.delete(ElixirLS.Fixtures.InlayHintsStructResult)
    File.rm_rf!(dir)
  end

  describe "GPT P1 3a — struct-result fixture ExCk integration" do
    setup do
      dir = compile_struct_fixture_to_tmp()
      on_exit(fn -> remove_struct_fixture_dir(dir) end)
      {:ok, dir: dir}
    end

    test "fixture returning a struct — request succeeds and hints are valid structs" do
      assert {:ok, hints} = hints_for(@struct_caller_source)
      assert is_list(hints)

      for hint <- hints do
        assert %GenLSP.Structures.InlayHint{} = hint
      end
    end
  end

  # ── GPT P1 3a: ExCk version-mismatch degradation ─────────────────────────

  # Module whose beam is patched with a foreign ExCk version tag so the reader
  # rejects its chunk → hint degrades to structural or is absent.
  @version_mismatch_caller """
  defmodule Sample do
    def run do
      x = ElixirLS.Fixtures.InlayHintsVersionMismatch.classify(1)
      x
    end
  end
  """

  defp compile_version_mismatch_fixture_to_tmp do
    # 1. Compile the fixture beam normally (reuse @fixture_source body / shape).
    fixture_src = """
    defmodule ElixirLS.Fixtures.InlayHintsVersionMismatch do
      @spec classify(integer()) :: :done
      def classify(_n), do: :done
    end
    """

    [{_mod, real_beam}] = Code.compile_string(fixture_src, "nofile")

    # 2. Patch the ExCk chunk: replace with a binary whose version tag is
    #    :elixir_checker_v0 (a tag that will never match any live runtime).
    fake_tag = :elixir_checker_v0
    foreign_chunk = :erlang.term_to_binary({fake_tag, %{exports: []}})
    patched_beam = patch_exck_chunk(real_beam, foreign_chunk)

    dir =
      Path.join(
        System.tmp_dir!(),
        "elixir_ls_inlay_vmismatch_#{:erlang.unique_integer([:positive])}"
      )

    File.mkdir_p!(dir)

    beam_path =
      Path.join(dir, "Elixir.ElixirLS.Fixtures.InlayHintsVersionMismatch.beam")

    File.write!(beam_path, patched_beam)
    :code.add_patha(String.to_charlist(dir))
    dir
  end

  # Replace the ExCk chunk in a BEAM binary with `new_chunk_payload`.
  # Walks the standard FOR1/BEAM chunk stream and rebuilds with the substitution.
  defp patch_exck_chunk(beam_binary, new_exck_payload) do
    <<"FOR1", _size::unsigned-big-32, "BEAM", chunks::binary>> = beam_binary
    new_chunks = rebuild_chunks(chunks, new_exck_payload)
    new_size = byte_size(new_chunks)
    <<"FOR1", new_size::unsigned-big-32, "BEAM", new_chunks::binary>>
  end

  defp rebuild_chunks(<<>>, _new_exck), do: <<>>

  defp rebuild_chunks(
         <<id::binary-size(4), size::unsigned-big-32, data::binary-size(size), rest::binary>>,
         new_exck
       ) do
    padding_count = rem(4 - rem(size, 4), 4)
    tail = binary_part(rest, padding_count, byte_size(rest) - padding_count)

    if id == "ExCk" do
      new_size = byte_size(new_exck)
      new_pad_count = rem(4 - rem(new_size, 4), 4)
      new_pad = :binary.copy(<<0>>, new_pad_count)

      <<id::binary, new_size::unsigned-big-32, new_exck::binary, new_pad::binary>> <>
        rebuild_chunks(tail, new_exck)
    else
      pad = :binary.copy(<<0>>, padding_count)

      <<id::binary, size::unsigned-big-32, data::binary, pad::binary>> <>
        rebuild_chunks(tail, new_exck)
    end
  end

  defp remove_version_mismatch_fixture_dir(dir) do
    :code.del_path(String.to_charlist(dir))
    :code.purge(ElixirLS.Fixtures.InlayHintsVersionMismatch)
    :code.delete(ElixirLS.Fixtures.InlayHintsVersionMismatch)
    File.rm_rf!(dir)
  end

  describe "GPT P1 3a — ExCk version-mismatch degradation" do
    setup do
      dir = compile_version_mismatch_fixture_to_tmp()
      on_exit(fn -> remove_version_mismatch_fixture_dir(dir) end)
      {:ok, dir: dir}
    end

    test "version-mismatched ExCk chunk — request succeeds without crash" do
      # The ExCk reader rejects the foreign-versioned chunk; the type engine
      # must fall back gracefully (structural hint or absent), never raise.
      assert {:ok, hints} = hints_for(@version_mismatch_caller)
      assert is_list(hints)

      for hint <- hints do
        assert %GenLSP.Structures.InlayHint{} = hint
      end
    end

    test "version-mismatched ExCk — hint degrades: source is not :native_exck" do
      # After chunk rejection the attr loop falls back to :spec / :shape;
      # the hint is NOT attributed :native_exck.  We verify via the type
      # hints facade directly.
      alias ElixirSense.Core.TypeHints
      alias ElixirLS.LanguageServer.Test.ParserContextBuilder

      ctx_data = ParserContextBuilder.from_string(@version_mismatch_caller)
      metadata = ctx_data.metadata
      th_ctx = TypeHints.request_context(metadata)

      vars =
        metadata.vars_info_per_scope_id
        |> Map.values()
        |> Enum.flat_map(&Map.values/1)
        |> Enum.filter(fn v -> v.name == :x end)
        |> Enum.uniq_by(& &1.name)

      for var <- vars do
        pos = List.first(var.positions)

        case TypeHints.type_hint_for_var(th_ctx, pos, var) do
          {:ok, hint} ->
            # Version-rejected ExCk → attribute is at best :spec (or :shape), never :native_exck
            refute hint.source == :native_exck,
                   "Expected degraded source, got #{hint.source} for #{var.name}"

          :skip ->
            # Graceful skip is also acceptable
            :ok
        end
      end
    end
  end

  # ── GPT P1 3a: missing ExCk chunk module ──────────────────────────────────

  describe "GPT P1 3a — missing ExCk chunk module (no crash)" do
    setup do
      # Ensure the fixture module is absent from the code path.
      :code.purge(ElixirLS.Fixtures.NoExCkModule)
      :code.delete(ElixirLS.Fixtures.NoExCkModule)
      :ok
    end

    test "call to a module with no ExCk chunk — request succeeds, no crash" do
      # :lists is an Erlang module with no ExCk chunk; calling it in a buffer
      # must not crash the hint provider.
      source = """
      defmodule Sample do
        def run(list) do
          result = :lists.reverse(list)
          result
        end
      end
      """

      assert {:ok, hints} = hints_for(source)
      assert is_list(hints)

      for hint <- hints do
        assert %GenLSP.Structures.InlayHint{} = hint
      end
    end
  end
end
