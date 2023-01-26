defmodule ElixirLS.LanguageServer.Experimental.Server.State do
  alias ElixirLS.Utils.WireProtocol

  alias ElixirLS.LanguageServer.Experimental.Protocol.Notifications.{
    DidChange,
    DidChangeConfiguration,
    DidClose,
    DidOpen,
    DidSave
  }

  alias ElixirLS.LanguageServer.Experimental.Protocol.Requests.Initialize
  alias ElixirLS.LanguageServer.Experimental.Protocol.Types.TextDocument
  alias ElixirLS.LanguageServer.Experimental.Server.Configuration
  alias ElixirLS.LanguageServer.Experimental.SourceFile

  import Logger

  defstruct configuration: nil, initialized?: false

  @type t :: %__MODULE__{}

  def new do
    %__MODULE__{}
  end

  def initialize(%__MODULE__{initialized?: false} = state, %Initialize{
        lsp: %Initialize.LSP{} = event
      }) do
    config = Configuration.new(event.root_uri, event.capabilities)
    new_state = %__MODULE__{state | configuration: config, initialized?: true}
    {:ok, new_state}
  end

  def initialize(%__MODULE__{initialized?: true}, %Initialize{}) do
    {:error, :already_initialized}
  end

  def default_configuration(%__MODULE__{configuration: config} = state) do
    with {:ok, config} <- Configuration.default(config) do
      {:ok, %__MODULE__{state | configuration: config}}
    end
  end

  def apply(%__MODULE__{initialized?: false}, request) do
    Logger.error("Received #{request.method} before server was initialized")
    {:error, :not_initialized}
  end

  def apply(%__MODULE__{} = state, %DidChangeConfiguration{} = event) do
    case Configuration.on_change(state.configuration, event) do
      {:ok, config} ->
        {:ok, %__MODULE__{state | configuration: config}}

      {:ok, config, response} ->
        WireProtocol.send(response)
        {:ok, %__MODULE__{state | configuration: config}}

      error ->
        error
    end
  end

  def apply(%__MODULE__{} = state, %DidChange{lsp: event}) do
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

  def apply(%__MODULE__{} = state, %DidOpen{lsp: event}) do
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

  def apply(%__MODULE__{} = state, %DidClose{lsp: event}) do
    uri = event.text_document.uri

    case SourceFile.Store.close(uri) do
      :ok ->
        {:ok, state}

      error ->
        warn("Received textDocument/didClose for a file that wasn't open. URI was #{uri}")
        error
    end
  end

  def apply(%__MODULE__{} = state, %DidSave{lsp: event}) do
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
