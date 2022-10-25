defmodule ElixirLS.LanguageServer.Experimental.SourceFile.StoreTest do
  alias ElixirLS.LanguageServer.Experimental.SourceFile
  alias ElixirLS.LanguageServer.Experimental.Protocol.Types.TextDocument.ContentChangeEvent
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
    :ok = SourceFile.Store.open(uri(), "hello", 1)
    :ok
  end

  describe "a clean store" do
    test "a document can be opened" do
      :ok = SourceFile.Store.open(uri(), "hello", 1)
      assert {:ok, file} = SourceFile.Store.fetch(uri())
      assert SourceFile.to_string(file) == "hello"
      assert file.version == 1
    end

    test "rejects changes to a file that isn't open" do
      {:ok, event} = build(ContentChangeEvent, text: "dog", range: nil)

      assert {:error, :not_open} =
               SourceFile.Store.get_and_update(
                 "file:///another.ex",
                 &SourceFile.apply_content_changes(&1, 3, [event])
               )
    end
  end

  describe "a document that is already open" do
    setup [:with_an_open_document]

    test "can be fetched" do
      assert {:ok, doc} = SourceFile.Store.fetch(uri())
      assert doc.uri == uri()
      assert SourceFile.to_string(doc) == "hello"
    end

    test "can be closed" do
      assert :ok = SourceFile.Store.close(uri())
      assert {:error, :not_open} = SourceFile.Store.fetch(uri())
    end

    test "can have its content changed" do
      {:ok, event} =
        build(ContentChangeEvent,
          text: "dog",
          range: [
            start: [line: 0, character: 0],
            end: [line: 0, character: 3]
          ]
        )

      assert {:ok, doc} =
               SourceFile.Store.get_and_update(uri(), fn source_file ->
                 SourceFile.apply_content_changes(source_file, 2, [
                   event
                 ])
               end)

      assert SourceFile.to_string(doc) == "doglo"
      assert {:ok, file} = SourceFile.Store.fetch(uri())
      assert SourceFile.to_string(file) == "doglo"
    end

    test "rejects a change if the version is less than the current version" do
      {:ok, event} = build(ContentChangeEvent, text: "dog", range: nil)

      assert {:error, :invalid_version} =
               SourceFile.Store.get_and_update(
                 uri(),
                 &SourceFile.apply_content_changes(&1, -1, [event])
               )
    end

    test "a change cannot be applied once a file is closed" do
      {:ok, event} = build(ContentChangeEvent, text: "dog", range: nil)
      assert :ok = SourceFile.Store.close(uri())

      assert {:error, :not_open} =
               SourceFile.Store.get_and_update(
                 uri(),
                 &SourceFile.apply_content_changes(&1, 3, [event])
               )
    end
  end
end
