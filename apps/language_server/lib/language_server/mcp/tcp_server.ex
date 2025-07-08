defmodule ElixirLS.LanguageServer.MCP.TCPServer do
  @moduledoc """
  Fixed TCP server for MCP
  """
  
  use GenServer
  require Logger
  
  alias ElixirLS.LanguageServer.Providers.ExecuteCommand.{
    LlmDocsAggregator,
    LlmTypeInfo,
    LlmDefinition,
    GetEnvironment
  }
  
  def start_link(opts) do
    port = Keyword.get(opts, :port, 3798)
    GenServer.start_link(__MODULE__, port, name: __MODULE__)
  end
  
  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      type: :worker,
      restart: :permanent
    }
  end
  
  @impl true
  def init(port) do
    IO.puts("[MCP] Starting TCP Server on port #{port}")
    
    case :gen_tcp.listen(port, [:binary, packet: :line, active: false, reuseaddr: true]) do
      {:ok, listen_socket} ->
        IO.puts("[MCP] Server listening on port #{port}")
        send(self(), :accept)
        {:ok, %{listen: listen_socket, clients: %{}}}
        
      {:error, reason} ->
        IO.puts("[MCP] Failed to listen on port #{port}: #{inspect(reason)}")
        {:stop, reason}
    end
  end
  
  @impl true
  def handle_info(:accept, state) do
    IO.puts("[MCP] Starting accept process")
    
    # Accept in a separate process
    me = self()
    spawn(fn ->
      accept_connection(me, state.listen)
    end)
    
    {:noreply, state}
  end
  
  @impl true
  def handle_info({:accepted, socket}, state) do
    IO.puts("[MCP] Client socket accepted: #{inspect(socket)}")
    
    # Configure socket
    case :inet.setopts(socket, [{:active, true}]) do
      :ok -> IO.puts("[MCP] Socket set to active mode")
      {:error, reason} -> IO.puts("[MCP] Failed to set active: #{inspect(reason)}")
    end
    
    # Store client
    {:noreply, %{state | clients: Map.put(state.clients, socket, %{})}}
  end
  
  @impl true
  def handle_info({:tcp, socket, data} = msg, state) do
    IO.puts("[MCP] TCP message received!")
    IO.puts("[MCP] Full message: #{inspect(msg)}")
    IO.puts("[MCP] Data: #{inspect(data)}")
    
    # Process the request
    trimmed = String.trim(data)
    
    response = case JasonV.decode(trimmed) do
      {:ok, request} ->
        IO.puts("[MCP] Decoded request: #{inspect(request)}")
        handle_mcp_request(request)
        
      {:error, _reason} ->
        %{
          "jsonrpc" => "2.0",
          "error" => %{
            "code" => -32700,
            "message" => "Parse error"
          },
          "id" => nil
        }
    end
    
    # Send response (only if not nil - notifications don't get responses)
    if response do
      case JasonV.encode(response) do
        {:ok, json} ->
          IO.puts("[MCP] Sending response: #{json}")
          :gen_tcp.send(socket, json <> "\n")
        {:error, _} ->
          :ok
      end
    end
    
    {:noreply, state}
  end
  
  @impl true
  def handle_info({:tcp_closed, socket}, state) do
    IO.puts("[MCP] Client disconnected")
    {:noreply, %{state | clients: Map.delete(state.clients, socket)}}
  end
  
  @impl true
  def handle_info({:tcp_error, socket, reason}, state) do
    IO.puts("[MCP] TCP error: #{inspect(reason)}")
    :gen_tcp.close(socket)
    {:noreply, %{state | clients: Map.delete(state.clients, socket)}}
  end
  
  @impl true
  def handle_info(msg, state) do
    IO.puts("[MCP] Unhandled message: #{inspect(msg)}")
    {:noreply, state}
  end
  
  # Private functions
  
  defp accept_connection(parent, listen_socket) do
    IO.puts("[MCP] Waiting for connection...")
    
    case :gen_tcp.accept(listen_socket) do
      {:ok, socket} ->
        IO.puts("[MCP] Connection accepted!")
        # IMPORTANT: Set the controlling process to the GenServer
        :gen_tcp.controlling_process(socket, parent)
        send(parent, {:accepted, socket})
        
        # Continue accepting
        accept_connection(parent, listen_socket)
        
      {:error, reason} ->
        IO.puts("[MCP] Accept error: #{inspect(reason)}")
        Process.sleep(1000)
        accept_connection(parent, listen_socket)
    end
  end
  
  defp handle_mcp_request(%{"method" => "initialize", "id" => id}) do
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
  
  defp handle_mcp_request(%{"method" => "tools/list", "id" => id}) do
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
  
  defp handle_mcp_request(%{"method" => "tools/call", "params" => params, "id" => id}) do
    case params do
      %{"name" => "find_definition", "arguments" => %{"symbol" => symbol}} ->
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
        
      %{"name" => "get_environment", "arguments" => %{"location" => location}} ->
        # Placeholder response for now
        text = """
        Environment information for location: #{location}
        
        Note: This is a placeholder response. The MCP server cannot directly access
        the LanguageServer state. Use the VS Code language tool or the 'getEnvironment'
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
        
      %{"name" => "get_docs", "arguments" => %{"modules" => modules}} when is_list(modules) ->
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
        
      %{"name" => "get_type_info", "arguments" => %{"module" => module}} when is_binary(module) ->
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
  
  defp handle_mcp_request(%{"method" => "notifications/cancelled", "params" => %{"requestId" => request_id}}) do
    # For now, just log that we received a cancellation
    # In a real implementation, we would cancel the ongoing request with the given ID
    Logger.debug("[MCP] Received cancellation for request #{request_id}")
    # No response is sent for notifications
    nil
  end
  
  defp handle_mcp_request(%{"method" => method, "id" => id}) do
    %{
      "jsonrpc" => "2.0",
      "error" => %{
        "code" => -32601,
        "message" => "Method not found: #{method}"
      },
      "id" => id
    }
  end
  
  defp handle_mcp_request(_) do
    %{
      "jsonrpc" => "2.0",
      "error" => %{
        "code" => -32600,
        "message" => "Invalid request"
      },
      "id" => nil
    }
  end

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
        
        if result[:moduledoc] do
          parts = parts ++ ["\n#{result.moduledoc}"]
        end
        
        if functions && length(functions) > 0 do
          function_parts = Enum.map(functions, &format_function_doc/1)
          parts = parts ++ ["\n## Functions\n"] ++ function_parts
        end
        
        Enum.join(parts, "\n")
      
      %{error: error, name: name} ->
        "## #{name}\nError: #{error}"
    end
  end

  defp format_function_doc(func) do
    parts = ["### #{func.name}/#{func.arity}"]
    
    if func[:specs] && length(func.specs) > 0 do
      specs = Enum.join(func.specs, "\n")
      parts = parts ++ ["\n```elixir\n#{specs}\n```"]
    end
    
    if func[:doc] do
      parts = parts ++ ["\n#{func.doc}"]
    end
    
    Enum.join(parts, "\n")
  end

  defp format_type_info_result(%{error: error}) do
    "Error: #{error}"
  end

  defp format_type_info_result(result) do
    parts = ["# Type Information for #{result.module}"]
    
    # Count available information
    has_types = result[:types] && length(result.types) > 0
    has_specs = result[:specs] && length(result.specs) > 0
    has_callbacks = result[:callbacks] && length(result.callbacks) > 0
    has_dialyzer = result[:dialyzer_contracts] && length(result.dialyzer_contracts) > 0
    
    if !has_types && !has_specs && !has_callbacks && !has_dialyzer do
      parts = parts ++ ["\nNo type information available for this module.\n\nThis could be because:\n- The module has no explicit type specifications\n- The module is a built-in Erlang module without exposed type information\n- The module hasn't been compiled yet"]
    end

    if has_types do
      parts = parts ++ ["\n## Types\n"]
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
      parts = parts ++ type_parts
    end

    if has_specs do
      parts = parts ++ ["\n## Function Specs\n"]
      spec_parts = Enum.map(result.specs, fn spec ->
        """
        ### #{spec.name}
        ```elixir
        #{spec.specs}
        ```
        #{if spec[:doc], do: spec.doc, else: ""}
        """
      end)
      parts = parts ++ spec_parts
    end

    if has_callbacks do
      parts = parts ++ ["\n## Callbacks\n"]
      callback_parts = Enum.map(result.callbacks, fn callback ->
        """
        ### #{callback.name}
        ```elixir
        #{callback.specs}
        ```
        #{if callback[:doc], do: callback.doc, else: ""}
        """
      end)
      parts = parts ++ callback_parts
    end

    if has_dialyzer do
      parts = parts ++ ["\n## Dialyzer Contracts\n"]
      contract_parts = Enum.map(result.dialyzer_contracts, fn contract ->
        """
        ### #{contract.name} (line #{contract.line})
        ```elixir
        #{contract.contract}
        ```
        """
      end)
      parts = parts ++ contract_parts
    end

    Enum.join(parts, "\n")
  end
end
