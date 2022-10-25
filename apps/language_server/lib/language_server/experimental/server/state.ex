defmodule ElixirLS.LanguageServer.Experimental.Server.State do
  alias ElixirLS.LanguageServer.Experimental.Protocol.Notifications.{
    DidChange,
    DidClose,
    DidSave,
    DidOpen
  }

  alias ElixirLS.LanguageServer.Experimental.Protocol.Types.TextDocument
  alias ElixirLS.LanguageServer.Experimental.SourceFile

  import Logger

  defstruct []

  def new do
    %__MODULE__{}
  end

  def apply(%__MODULE__{} = state, %DidChange{} = event) do
    uri = event.text_document.uri
    version = event.text_document.version

    case SourceFile.Store.update(
           uri,
           &SourceFile.apply_content_changes(&1, version, event.content_changes)
         ) do
      :ok -> {:ok, state}
      error -> error
    end
  end

  def apply(%__MODULE__{} = state, %DidOpen{} = event) do
    %TextDocument{text: text, uri: uri, version: version} = text_document = event.text_document

    case SourceFile.Store.open(uri, text, version) do
      :ok ->
        info("opened #{uri}")
        {:ok, state}

      error ->
        error("Could not open #{text_document.uri} #{inspect(error)}")
        error
    end
  end

  def apply(%__MODULE__{} = state, %DidClose{} = event) do
    uri = event.text_document.uri

    case SourceFile.Store.close(uri) do
      :ok ->
        {:ok, state}

      error ->
        warn("Received textDocument/didClose for a file that wasn't open. URI was #{uri}")
        error
    end
  end

  def apply(%__MODULE__{} = state, %DidSave{} = event) do
    uri = event.text_document.uri

    case SourceFile.Store.save(uri) do
      :ok ->
        {:ok, state}

      error ->
        warn("Save failed for uri #{uri} error was #{inspect(error)}")
        error
    end
  end

  def apply(%__MODULE__{} = state, _) do
    {:ok, state}
  end
end
