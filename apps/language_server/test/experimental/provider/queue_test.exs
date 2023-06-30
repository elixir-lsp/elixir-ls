defmodule ElixirLS.LanguageServer.Experimental.Provider.QueueTest do
  alias LSP.Requests
  alias LSP.Responses
  alias ElixirLS.LanguageServer.Experimental.Provider
  alias ElixirLS.LanguageServer.Experimental.Provider.Env
  alias ElixirLS.LanguageServer.Experimental.SourceFile
  alias ElixirLS.LanguageServer.Tracer
  alias ElixirLS.Utils.WireProtocol

  import ElixirLS.LanguageServer.Fixtures.LspProtocol
  use ExUnit.Case
  use Patch

  setup do
    {:ok, _} = start_supervised(Provider.Queue.Supervisor.child_spec())
    {:ok, _} = start_supervised(Provider.Queue)
    {:ok, _} = start_supervised(Tracer)

    {:ok, env: %Env{}}
  end

  def with_patched_store(_) do
    patch(SourceFile.Store, :fetch, fn uri ->
      source = """
      defmodule MyModule do
      end
      """

      source_file = SourceFile.new(uri, source, 1)
      {:ok, source_file}
    end)

    :ok
  end

  def with_redirected_replies(_) do
    me = self()

    patch(WireProtocol, :send, fn message ->
      send(me, {:wire_protocol, message})
    end)

    :ok
  end

  describe "the request queue" do
    setup [:with_patched_store, :with_redirected_replies]

    test "handles a find references request", ctx do
      {:ok, request} =
        build(Requests.FindReferences,
          id: 1,
          text_document: [uri: "file:///file.ex", position: [line: 0, character: 5]]
        )

      assert :ok = Provider.Queue.add(request, ctx.env)
      assert_receive {:wire_protocol, %Responses.FindReferences{id: "1"}}
    end

    test "can cancel requests", ctx do
      patch(Provider.Handlers.FindReferences, :handle, fn ->
        Process.sleep(250)
        {:reply, Responses.FindReferences.new(1, [])}
      end)

      {:ok, request} =
        build(Requests.FindReferences,
          id: 1,
          text_document: [uri: "file:///file.ex", position: [line: 0, character: 0]]
        )

      assert :ok = Provider.Queue.add(request, ctx.env)
      assert :ok = Provider.Queue.cancel(request.id)

      refute_receive {:wire_protocol, _}
    end

    test "knows if a request is running", ctx do
      patch(Provider.Handlers.FindReferences, :handle, fn ->
        Process.sleep(250)
        {:reply, Responses.FindReferences.new(1, [])}
      end)

      {:ok, request} =
        build(Requests.FindReferences,
          id: 1,
          text_document: [uri: "file:///file.ex", position: [line: 0, character: 0]]
        )

      assert :ok = Provider.Queue.add(request, ctx.env)
      assert Provider.Queue.running?(request)
      assert Provider.Queue.running?(request.id)

      assert_receive {:wire_protocol, _}
      Process.sleep(100)

      refute Provider.Queue.running?(request)
      refute Provider.Queue.running?(request.id)
    end
  end
end
