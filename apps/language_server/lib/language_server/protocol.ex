defmodule ElixirLS.LanguageServer.Protocol do
  @moduledoc """
  Macros for requests and notifications in the Language Server Protocol
  """

  import ElixirLS.LanguageServer.JsonRpc

  defmacro __using__(_) do
    quote do
      import ElixirLS.LanguageServer.JsonRpc
      import unquote(__MODULE__)
    end
  end

  defmacro cancel_request(id) do
    quote do
      notification("$/cancelRequest", %{"id" => unquote(id)})
    end
  end

  defmacro did_open(uri, language_id, version, text) do
    quote do
      notification("textDocument/didOpen", %{
        "textDocument" => %{
          "uri" => unquote(uri),
          "languageId" => unquote(language_id),
          "version" => unquote(version),
          "text" => unquote(text)
        }
      })
    end
  end

  defmacro did_close(uri) do
    quote do
      notification("textDocument/didClose", %{"textDocument" => %{"uri" => unquote(uri)}})
    end
  end

  defmacro did_change(uri, version, content_changes) do
    quote do
      notification("textDocument/didChange", %{
        "textDocument" => %{"uri" => unquote(uri), "version" => unquote(version)},
        "contentChanges" => unquote(content_changes)
      })
    end
  end

  defmacro did_change_configuration(settings) do
    quote do
      notification("workspace/didChangeConfiguration", %{"settings" => unquote(settings)})
    end
  end

  defmacro did_change_watched_files(changes) do
    quote do
      notification("workspace/didChangeWatchedFiles", %{"changes" => unquote(changes)})
    end
  end

  defmacro did_save(uri) do
    quote do
      notification("textDocument/didSave", %{"textDocument" => %{"uri" => unquote(uri)}})
    end
  end

  defmacro references_req(id, uri, line, character, include_declaration) do
    quote do
      request(unquote(id), "textDocument/references", %{
        "textDocument" => %{"uri" => unquote(uri)},
        "position" => %{"line" => unquote(line), "character" => unquote(character)},
        "context" => %{"includeDeclaration" => unquote(include_declaration)}
      })
    end
  end

  defmacro initialize_req(id, root_uri, client_capabilities) do
    quote do
      request(unquote(id), "initialize", %{
        "capabilities" => unquote(client_capabilities),
        "rootUri" => unquote(root_uri)
      })
    end
  end

  defmacro hover_req(id, uri, line, character) do
    quote do
      request(unquote(id), "textDocument/hover", %{
        "textDocument" => %{"uri" => unquote(uri)},
        "position" => %{"line" => unquote(line), "character" => unquote(character)}
      })
    end
  end

  defmacro definition_req(id, uri, line, character) do
    quote do
      request(unquote(id), "textDocument/definition", %{
        "textDocument" => %{"uri" => unquote(uri)},
        "position" => %{"line" => unquote(line), "character" => unquote(character)}
      })
    end
  end

  defmacro implementation_req(id, uri, line, character) do
    quote do
      request(unquote(id), "textDocument/implementation", %{
        "textDocument" => %{"uri" => unquote(uri)},
        "position" => %{"line" => unquote(line), "character" => unquote(character)}
      })
    end
  end

  defmacro completion_req(id, uri, line, character) do
    quote do
      request(unquote(id), "textDocument/completion", %{
        "textDocument" => %{"uri" => unquote(uri)},
        "position" => %{"line" => unquote(line), "character" => unquote(character)}
      })
    end
  end

  defmacro formatting_req(id, uri, options) do
    quote do
      request(unquote(id), "textDocument/formatting", %{
        "textDocument" => %{"uri" => unquote(uri)},
        "options" => unquote(options)
      })
    end
  end

  defmacro document_symbol_req(id, uri) do
    quote do
      request(unquote(id), "textDocument/documentSymbol", %{
        "textDocument" => %{"uri" => unquote(uri)}
      })
    end
  end

  defmacro workspace_symbol_req(id, query) do
    quote do
      request(unquote(id), "workspace/symbol", %{
        "query" => unquote(query)
      })
    end
  end

  defmacro signature_help_req(id, uri, line, character) do
    quote do
      request(unquote(id), "textDocument/signatureHelp", %{
        "textDocument" => %{"uri" => unquote(uri)},
        "position" => %{"line" => unquote(line), "character" => unquote(character)}
      })
    end
  end

  defmacro publish_diagnostics_notif(uri, diagnostics) do
    quote do
      notification("textDocument/publishDiagnostics", %{
        "uri" => unquote(uri),
        "diagnostics" => unquote(diagnostics)
      })
    end
  end

  defmacro on_type_formatting_req(id, uri, line, character, ch, options) do
    quote do
      request(unquote(id), "textDocument/onTypeFormatting", %{
        "textDocument" => %{"uri" => unquote(uri)},
        "position" => %{"line" => unquote(line), "character" => unquote(character)},
        "ch" => unquote(ch),
        "options" => unquote(options)
      })
    end
  end

  defmacro code_lens_req(id, uri) do
    quote do
      request(unquote(id), "textDocument/codeLens", %{
        "textDocument" => %{"uri" => unquote(uri)}
      })
    end
  end

  defmacro execute_command_req(id, command, arguments) do
    quote do
      request(unquote(id), "workspace/executeCommand", %{
        "command" => unquote(command),
        "arguments" => unquote(arguments)
      })
    end
  end

  defmacro macro_expansion(id, whole_buffer, selected_macro, macro_line) do
    quote do
      request(unquote(id), "elixirDocument/macroExpansion", %{
        "context" => %{"selection" => unquote(selected_macro)},
        "textDocument" => %{"text" => unquote(whole_buffer)},
        "position" => %{"line" => unquote(macro_line)}
      })
    end
  end

  # Other utilities

  defmacro range(start_line, start_character, end_line, end_character) do
    quote do
      %{
        "start" => %{"line" => unquote(start_line), "character" => unquote(start_character)},
        "end" => %{"line" => unquote(end_line), "character" => unquote(end_character)}
      }
    end
  end
end
