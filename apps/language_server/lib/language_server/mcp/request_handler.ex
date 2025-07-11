defmodule ElixirLS.LanguageServer.MCP.RequestHandler do
  @moduledoc """
  Handles MCP (Model Context Protocol) requests.
  Extracted from TCPServer for better testability.
  """

  require Logger
  alias JasonV
  
  alias ElixirLS.LanguageServer.Providers.ExecuteCommand.{
    LlmDocsAggregator,
    LlmTypeInfo,
    LlmDefinition
  }

  @doc """
  Handles an MCP request and returns the appropriate response.
  Returns nil for notifications (which don't require a response).
  """
  def handle_request(request) do
    case request do
      %{"method" => "initialize", "id" => id} ->
        handle_initialize(id)
        
      %{"method" => "tools/list", "id" => id} ->
        handle_tools_list(id)
        
      %{"method" => "tools/call", "params" => params, "id" => id} ->
        handle_tool_call(params, id)
        
      %{"method" => "notifications/cancelled", "params" => params} ->
        handle_notification_cancelled(params)
        
      %{"method" => method, "id" => id} ->
        %{
          "jsonrpc" => "2.0",
          "error" => %{
            "code" => -32601,
            "message" => "Method not found: #{method}"
          },
          "id" => id
        }
        
      _ ->
        %{
          "jsonrpc" => "2.0",
          "error" => %{
            "code" => -32600,
            "message" => "Invalid request"
          },
          "id" => nil
        }
    end
  end

  defp handle_initialize(id) do
    %{
      "jsonrpc" => "2.0",
      "result" => %{
        "protocolVersion" => "2024-11-05",
        "capabilities" => %{
          "tools" => %{}
        },
        "serverInfo" => %{
          "name" => "ElixirLS MCP Server",
          "version" => "1.0.0"
        }
      },
      "id" => id
    }
  end

  defp handle_tools_list(id) do
    %{
      "jsonrpc" => "2.0",
      "result" => %{
        "tools" => [
          %{
            "name" => "find_definition",
            "description" => "Find and retrieve source code definitions",
            "inputSchema" => %{
              "type" => "object",
              "properties" => %{
                "symbol" => %{
                  "type" => "string",
                  "description" => "The symbol to find"
                }
              },
              "required" => ["symbol"]
            }
          },
          %{
            "name" => "get_environment",
            "description" => "Get environment information at a specific location",
            "inputSchema" => %{
              "type" => "object",
              "properties" => %{
                "location" => %{
                  "type" => "string",
                  "description" => "Location in format 'file.ex:line:column' or 'file.ex:line'"
                }
              },
              "required" => ["location"]
            }
          },
          %{
            "name" => "get_docs",
            "description" => "Aggregate and return documentation for multiple Elixir modules or functions",
            "inputSchema" => %{
              "type" => "object",
              "properties" => %{
                "modules" => %{
                  "type" => "array",
                  "description" => "List of module or function names to get documentation for",
                  "items" => %{
                    "type" => "string"
                  }
                }
              },
              "required" => ["modules"]
            }
          },
          %{
            "name" => "get_type_info",
            "description" => "Extract type information from Elixir modules including types, specs, callbacks, and Dialyzer contracts",
            "inputSchema" => %{
              "type" => "object",
              "properties" => %{
                "module" => %{
                  "type" => "string",
                  "description" => "The module name to get type information for"
                }
              },
              "required" => ["module"]
            }
          }
        ]
      },
      "id" => id
    }
  end

  defp handle_tool_call(params, id) do
    case params do
      %{"name" => "find_definition", "arguments" => %{"symbol" => symbol}} ->
        handle_find_definition(symbol, id)
        
      %{"name" => "get_environment", "arguments" => %{"location" => location}} ->
        handle_get_environment(location, id)
        
      %{"name" => "get_docs", "arguments" => %{"modules" => modules}} when is_list(modules) ->
        handle_get_docs(modules, id)
        
      %{"name" => "get_type_info", "arguments" => %{"module" => module}} when is_binary(module) ->
        handle_get_type_info(module, id)
        
      _ ->
        %{
          "jsonrpc" => "2.0",
          "error" => %{
            "code" => -32602,
            "message" => "Invalid params"
          },
          "id" => id
        }
    end
  end

  defp handle_find_definition(symbol, id) do
    case LlmDefinition.execute([symbol], %{}) do
      {:ok, %{definition: definition}} ->
        %{
          "jsonrpc" => "2.0",
          "result" => %{
            "content" => [
              %{
                "type" => "text",
                "text" => definition
              }
            ]
          },
          "id" => id
        }
        
      {:ok, %{error: error}} ->
        %{
          "jsonrpc" => "2.0",
          "error" => %{
            "code" => -32603,
            "message" => error
          },
          "id" => id
        }
        
      _ ->
        %{
          "jsonrpc" => "2.0",
          "error" => %{
            "code" => -32603,
            "message" => "Internal error"
          },
          "id" => id
        }
    end
  end

  defp handle_get_environment(location, id) do
    # Placeholder response for now
    text = """
    Environment information for location: #{location}
    
    Note: This is a placeholder response. The MCP server cannot directly access
    the LanguageServer state. Use the VS Code language tool or the 'llmEnvironment'
    command for actual environment information.
    """
    
    %{
      "jsonrpc" => "2.0",
      "result" => %{
        "content" => [
          %{
            "type" => "text",
            "text" => text
          }
        ]
      },
      "id" => id
    }
  end

  defp handle_get_docs(modules, id) do
    case LlmDocsAggregator.execute([modules], %{}) do
      {:ok, result} ->
        text = format_docs_result(result)
        
        %{
          "jsonrpc" => "2.0",
          "result" => %{
            "content" => [
              %{
                "type" => "text",
                "text" => text
              }
            ]
          },
          "id" => id
        }
        
      _ ->
        %{
          "jsonrpc" => "2.0",
          "error" => %{
            "code" => -32603,
            "message" => "Failed to get documentation"
          },
          "id" => id
        }
    end
  end

  defp handle_get_type_info(module, id) do
    case LlmTypeInfo.execute([module], %{}) do
      {:ok, result} ->
        text = format_type_info_result(result)
        
        %{
          "jsonrpc" => "2.0",
          "result" => %{
            "content" => [
              %{
                "type" => "text",
                "text" => text
              }
            ]
          },
          "id" => id
        }
        
      _ ->
        %{
          "jsonrpc" => "2.0",
          "error" => %{
            "code" => -32603,
            "message" => "Failed to get type information"
          },
          "id" => id
        }
    end
  end

  defp handle_notification_cancelled(%{"requestId" => request_id}) do
    # For now, just log that we received a cancellation
    # In a real implementation, we would cancel the ongoing request with the given ID
    Logger.debug("[MCP] Received cancellation for request #{request_id}")
    # No response is sent for notifications
    nil
  end

  # Formatting functions

  defp format_docs_result(%{error: error}) do
    "Error: #{error}"
  end
  
  defp format_docs_result(%{results: results}) do
    results
    |> Enum.map(&format_single_doc_result/1)
    |> Enum.join("\n\n---\n\n")
  end
  
  defp format_docs_result(_), do: "Unknown result format"

  defp format_single_doc_result(result) do
    case result do
      %{module: module, functions: functions} ->
        parts = ["# Module: #{module}"]
        
        parts = if result[:moduledoc] do
          parts ++ ["\n#{result.moduledoc}"]
        else
          parts
        end
        
        parts = if functions && length(functions) > 0 do
          function_parts = Enum.map(functions, &format_function_doc/1)
          parts ++ ["\n## Functions\n"] ++ function_parts
        else
          parts
        end
        
        Enum.join(parts, "\n")
        
      %{error: error} ->
        "Error: #{error}"
        
      _ ->
        "Unknown result format"
    end
  end

  defp format_function_doc(func) when is_binary(func) do
    "- #{func}"
  end
  defp format_function_doc(func) when is_map(func) do
    parts = ["### #{func.function}/#{func.arity}"]
    
    parts = if func[:specs] && length(func.specs) > 0 do
      specs = Enum.join(func.specs, "\n")
      parts ++ ["\n```elixir\n#{specs}\n```"]
    else
      parts
    end
    
    parts = if func[:doc] do
      parts ++ ["\n#{func.doc}"]
    else
      parts
    end
    
    Enum.join(parts, "\n")
  end

  defp format_type_info_result(%{error: error}) do
    "Error: #{error}"
  end

  defp format_type_info_result(result) do
    header = ["# Type Information for #{result.module}"]
    
    # Count available information
    has_types = result[:types] && length(result.types) > 0
    has_specs = result[:specs] && length(result.specs) > 0
    has_callbacks = result[:callbacks] && length(result.callbacks) > 0
    has_dialyzer = result[:dialyzer_contracts] && length(result.dialyzer_contracts) > 0
    
    parts = 
      if !has_types && !has_specs && !has_callbacks && !has_dialyzer do
        header ++ ["\nNo type information available for this module.\n\nThis could be because:\n- The module has no explicit type specifications\n- The module is a built-in Erlang module without exposed type information\n- The module hasn't been compiled yet"]
      else
        header
      end

    parts = 
      if has_types do
        type_parts = Enum.map(result.types, fn type ->
          """
          ### #{type.name}
          Kind: #{type.kind}
          Signature: #{type.signature}
          ```elixir
          #{type.spec}
          ```
          #{if type[:doc], do: type.doc, else: ""}
          """
        end)
        parts ++ ["\n## Types\n"] ++ type_parts
      else
        parts
      end

    parts = 
      if has_specs do
        spec_parts = Enum.map(result.specs, fn spec ->
          """
          ### #{spec.name}
          ```elixir
          #{spec.specs}
          ```
          #{if spec[:doc], do: spec.doc, else: ""}
          """
        end)
        parts ++ ["\n## Function Specs\n"] ++ spec_parts
      else
        parts
      end

    parts = 
      if has_callbacks do
        callback_parts = Enum.map(result.callbacks, fn callback ->
          """
          ### #{callback.name}
          ```elixir
          #{callback.specs}
          ```
          #{if callback[:doc], do: callback.doc, else: ""}
          """
        end)
        parts ++ ["\n## Callbacks\n"] ++ callback_parts
      else
        parts
      end

    parts = 
      if has_dialyzer do
        contract_parts = Enum.map(result.dialyzer_contracts, fn contract ->
          """
          ### #{contract.name} (line #{contract.line})
          ```elixir
          #{contract.contract}
          ```
          """
        end)
        parts ++ ["\n## Dialyzer Contracts\n"] ++ contract_parts
      else
        parts
      end

    Enum.join(parts, "\n")
  end
end
