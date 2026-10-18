defmodule ElixirLS.LanguageServer.BuildTest do
  use ElixirLS.Utils.MixTest.Case, async: false
  alias ElixirLS.LanguageServer.{Build, MixProjectCache, Tracer}

  setup do
    {:ok, _} = start_supervised(Tracer)
    {:ok, _} = start_supervised(MixProjectCache)
    :ok
  end

  defp build do
    {_pid, ref} = Build.build(self(), File.cwd!(), compile?: true, fetch_deps?: false)

    assert_receive {:"$gen_cast", {:build_finished, {status, _diagnostics}}}
                   when status in [:ok, :noop],
                   30_000

    assert_receive {:DOWN, ^ref, :process, _pid, _reason}, 30_000
  end

  test "vendored GenLSP modules are not shadowed by project modules with the same name" do
    in_fixture(__DIR__, "gen_lsp_dep", fn ->
      module = GenLSP.Structures.Hover
      beam = :code.which(module)

      build()

      # simulate a new session with the dependency already compiled and our module not loaded yet
      :code.purge(module)
      :code.delete(module)

      build()

      # project beams removed while their code path is still cached
      File.rm_rf!(".elixir_ls")

      # used to fail with
      # (UndefinedFunctionError) function GenLSP.Structures.Hover.schematic/0 is undefined
      # (module GenLSP.Structures.Hover is not available)
      assert %SchematicV{} = GenLSP.Requests.TextDocumentHover.result()
      assert :code.which(module) == beam
    end)
  end
end
