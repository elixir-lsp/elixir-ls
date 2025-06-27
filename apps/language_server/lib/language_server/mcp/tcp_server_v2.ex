defmodule ElixirLS.LanguageServer.MCP.TCPServerV2 do
  @moduledoc """
  Fixed TCP server for MCP
  """
  
  use GenServer
  require Logger
  
  alias ElixirLS.LanguageServer.MCP.Tools.FindDefinition
  
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
    
    # Send response
    case JasonV.encode(response) do
      {:ok, json} ->
        IO.puts("[MCP] Sending response: #{json}")
        :gen_tcp.send(socket, json <> "\n")
      {:error, _} ->
        :ok
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
          }
        ]
      },
      "id" => id
    }
  end
  
  defp handle_mcp_request(%{"method" => "tools/call", "params" => params, "id" => id}) do
    case params do
      %{"name" => "find_definition", "arguments" => %{"symbol" => symbol}} ->
        case FindDefinition.execute(%{symbol: symbol}, %{}) do
          {:reply, response, _frame} ->
            text = case response.content do
              [%{text: text}] -> text
              _ -> "No content"
            end
            
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
end