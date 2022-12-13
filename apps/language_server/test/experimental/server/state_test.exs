defmodule ElixirLS.LanguageServer.Experimental.Server.StateTest do
  alias ElixirLS.LanguageServer.Experimental.Protocol.Notifications
  alias ElixirLS.LanguageServer.Experimental.SourceFile
  alias ElixirLS.LanguageServer.Experimental.Server.State

  import ElixirLS.LanguageServer.Fixtures.LspProtocol

  use ExUnit.Case

  setup do
    {:ok, _} = start_supervised(SourceFile.Store)
    :ok
  end

  def uri do
    "file:///file.ex"
  end

  def with_an_open_document(_) do
    {:ok, did_open} =
      build(Notifications.DidOpen,
        id: 1,
        text_document: [uri: uri(), version: 1, text: "hello"]
      )

    {:ok, state} = State.apply(State.new(), did_open)
    {:ok, state: state}
  end

  def change_notification(opts \\ []) do
    {:ok, did_change} =
      build(Notifications.DidChange,
        id: 2,
        text_document: [
          uri: Keyword.get(opts, :uri, uri()),
          version: Keyword.get(opts, :version, 2)
        ],
        content_changes: [
          [text: "goodbye"],
          [range: [start: [line: 0, character: 0], end: [line: 0, character: 4]], text: "dog"]
        ]
      )

    did_change
  end

  def with_a_changed_document(ctx) do
    {:ok, state} = State.apply(ctx.state, change_notification())
    {:ok, state: state, change: change_notification()}
  end

  test "closing a document that isn't open fails" do
    {:ok, did_close} = build(Notifications.DidClose, text_document: [uri: uri()])
    assert {:error, :not_open} = State.apply(State.new(), did_close)
  end

  test "saving a document that isn't open fails" do
    {:ok, save} = build(Notifications.DidSave, text_document: [uri: uri()])
    assert {:error, :not_open} = State.apply(State.new(), save)
  end

  test "applying a didOpen notification" do
    assert {:error, :not_open} = SourceFile.Store.fetch(uri())

    {:ok, did_open} =
      build(Notifications.DidOpen,
        id: 1,
        text_document: [uri: uri(), version: 1, text: "hello"]
      )

    {:ok, _state} = State.apply(State.new(), did_open)
    assert {:ok, file} = SourceFile.Store.fetch(uri())
    assert SourceFile.to_string(file) == "hello"
    assert file.version == 1
  end

  describe "a document is open" do
    setup [:with_an_open_document]

    test "can be changed", %{state: state} do
      assert {:ok, _state} = State.apply(state, change_notification())

      assert {:ok, file} = SourceFile.Store.fetch(uri())
      assert file.dirty?
      assert SourceFile.to_string(file) == "dogbye"
    end

    test "a change is rejected if the version is less than the current version", ctx do
      change = change_notification(version: 1)

      assert {:error, :invalid_version} = State.apply(ctx.state, change)
    end
  end

  describe "an open, changed document" do
    setup [:with_an_open_document, :with_a_changed_document]

    test "should clear the dirty field when saved", ctx do
      assert {:ok, save} = build(Notifications.DidSave, text_document: [uri: uri()])
      assert {:ok, %{dirty?: true}} = SourceFile.Store.fetch(uri())
      assert {:ok, _state} = State.apply(ctx.state, save)

      assert {:ok, %{dirty?: false}} = SourceFile.Store.fetch(uri())
    end
  end
end
