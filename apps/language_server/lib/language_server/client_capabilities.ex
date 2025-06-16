defmodule ElixirLS.LanguageServer.ClientCapabilities do
  @moduledoc """
  Utilities for checking client capabilities from LSP client capabilities.

  This module provides a centralized way to store and access client capabilities
  using persistent_term for efficient access across the application.
  """

  @capabilities_key :language_server_client_capabilities

  @doc """
  Stores the client capabilities in persistent_term for global access.
  """
  def store(client_capabilities) do
    :persistent_term.put(@capabilities_key, client_capabilities)
  end

  @doc """
  Retrieves the stored client capabilities from persistent_term.
  Returns nil if no capabilities have been stored.
  """
  def get do
    :persistent_term.get(@capabilities_key, nil)
  end

  @doc """
  Checks if the client supports hierarchical document symbols.
  """
  def hierarchical_document_symbol_support? do
    case get() do
      %GenLSP.Structures.ClientCapabilities{
        text_document: %GenLSP.Structures.TextDocumentClientCapabilities{
          document_symbol: %GenLSP.Structures.DocumentSymbolClientCapabilities{
            hierarchical_document_symbol_support: hierarchical_document_symbol_support
          }
        }
      } ->
        hierarchical_document_symbol_support

      _ ->
        false
    end
  end

  @doc """
  Checks if the client supports snippets in completion items.
  """
  def snippets_supported? do
    case get() do
      %GenLSP.Structures.ClientCapabilities{
        text_document: %GenLSP.Structures.TextDocumentClientCapabilities{
          completion: %GenLSP.Structures.CompletionClientCapabilities{
            completion_item: %{snippet_support: snippet_support}
          }
        }
      } ->
        snippet_support

      _ ->
        false
    end
  end

  @doc """
  Checks if the client supports deprecated completion items.

  Note: deprecated as of Language Server Protocol Specification - 3.15
  """
  def deprecated_supported? do
    case get() do
      %GenLSP.Structures.ClientCapabilities{
        text_document: %GenLSP.Structures.TextDocumentClientCapabilities{
          completion: %GenLSP.Structures.CompletionClientCapabilities{
            completion_item: %{deprecated_support: deprecated_support}
          }
        }
      } ->
        deprecated_support

      _ ->
        false
    end
  end

  @doc """
  Returns the list of supported completion item tags, or empty list if not supported.
  """
  def tags_supported do
    case get() do
      %GenLSP.Structures.ClientCapabilities{
        text_document: %GenLSP.Structures.TextDocumentClientCapabilities{
          completion: %GenLSP.Structures.CompletionClientCapabilities{
            completion_item: %{tag_support: %{value_set: value_set}}
          }
        }
      } ->
        value_set

      _ ->
        []
    end
  end

  @doc """
  Checks if the client supports signature help.
  """
  def signature_help_supported? do
    case get() do
      %GenLSP.Structures.ClientCapabilities{
        text_document: %GenLSP.Structures.TextDocumentClientCapabilities{
          signature_help: %GenLSP.Structures.SignatureHelpClientCapabilities{}
        }
      } ->
        true

      _ ->
        false
    end
  end

  @doc """
  Checks if the client supports dynamic registration for workspace/didChangeConfiguration.
  """
  def supports_dynamic_configuration_change_registration? do
    case get() do
      %GenLSP.Structures.ClientCapabilities{
        workspace: %GenLSP.Structures.WorkspaceClientCapabilities{
          did_change_configuration: %GenLSP.Structures.DidChangeConfigurationClientCapabilities{
            dynamic_registration: dynamic_registration
          }
        }
      } ->
        dynamic_registration

      _ ->
        false
    end
  end

  @doc """
  Checks if the client supports dynamic registration for workspace/didChangeWatchedFiles.
  """
  def supports_dynamic_file_watcher_registration? do
    case get() do
      %GenLSP.Structures.ClientCapabilities{
        workspace: %GenLSP.Structures.WorkspaceClientCapabilities{
          did_change_watched_files: %GenLSP.Structures.DidChangeWatchedFilesClientCapabilities{
            dynamic_registration: dynamic_registration
          }
        }
      } ->
        dynamic_registration

      _ ->
        false
    end
  end

  @doc """
  Checks if the client supports workspace/configuration requests.
  """
  def supports_configuration? do
    case get() do
      %GenLSP.Structures.ClientCapabilities{
        workspace: %GenLSP.Structures.WorkspaceClientCapabilities{
          configuration: configuration
        }
      } ->
        configuration

      _ ->
        false
    end
  end

  @doc """
  Checks if the client supports workspace symbol tags.
  """
  def workspace_symbol_tag_support? do
    case get() do
      %GenLSP.Structures.ClientCapabilities{
        workspace: %GenLSP.Structures.WorkspaceClientCapabilities{
          symbol: %{tag_support: tag_support}
        }
      }
      when tag_support != nil ->
        true

      _ ->
        false
    end
  end
end
