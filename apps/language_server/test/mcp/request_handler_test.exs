defmodule ElixirLS.LanguageServer.MCP.RequestHandlerTest do
  use ExUnit.Case, async: true
  
  alias ElixirLS.LanguageServer.MCP.RequestHandler
  
  describe "handle_request/1" do
    test "handles initialize request" do
      request = %{
        "method" => "initialize",
        "id" => 1
      }
      
      response = RequestHandler.handle_request(request)
      
      assert response["jsonrpc"] == "2.0"
      assert response["id"] == 1
      assert response["result"]["protocolVersion"] == "2024-11-05"
      assert response["result"]["capabilities"] == %{"tools" => %{}}
      assert response["result"]["serverInfo"]["name"] == "ElixirLS MCP Server"
      assert response["result"]["serverInfo"]["version"] == "1.0.0"
    end
    
    test "handles tools/list request" do
      request = %{
        "method" => "tools/list",
        "id" => 2
      }
      
      response = RequestHandler.handle_request(request)
      
      assert response["jsonrpc"] == "2.0"
      assert response["id"] == 2
      assert is_list(response["result"]["tools"])
      
      tool_names = Enum.map(response["result"]["tools"], & &1["name"])
      assert "find_definition" in tool_names
      assert "get_environment" in tool_names
      assert "get_docs" in tool_names
      assert "get_type_info" in tool_names
      
      # Check tool schemas
      for tool <- response["result"]["tools"] do
        assert tool["description"]
        assert tool["inputSchema"]["type"] == "object"
        assert tool["inputSchema"]["properties"]
        assert tool["inputSchema"]["required"]
      end
    end
    
    test "handles tools/call for find_definition" do
      request = %{
        "method" => "tools/call",
        "params" => %{
          "name" => "find_definition",
          "arguments" => %{"symbol" => "String"}
        },
        "id" => 3
      }
      
      response = RequestHandler.handle_request(request)
      
      assert response["jsonrpc"] == "2.0"
      assert response["id"] == 3
      
      # Should either return result or error
      assert response["result"] || response["error"]
      
      if response["result"] do
        assert is_list(response["result"]["content"])
        assert length(response["result"]["content"]) > 0
        first_content = hd(response["result"]["content"])
        assert first_content["type"] == "text"
        assert first_content["text"]
      end
    end
    
    test "handles tools/call for get_environment" do
      request = %{
        "method" => "tools/call",
        "params" => %{
          "name" => "get_environment",
          "arguments" => %{"location" => "test.ex:10:5"}
        },
        "id" => 4
      }
      
      response = RequestHandler.handle_request(request)
      
      assert response["jsonrpc"] == "2.0"
      assert response["id"] == 4
      assert response["result"]
      assert is_list(response["result"]["content"])
      
      content = hd(response["result"]["content"])
      assert content["type"] == "text"
      assert content["text"] =~ "Environment information for location: test.ex:10:5"
      assert content["text"] =~ "placeholder response"
    end
    
    test "handles tools/call for get_docs" do
      request = %{
        "method" => "tools/call",
        "params" => %{
          "name" => "get_docs",
          "arguments" => %{"modules" => ["String", "Enum"]}
        },
        "id" => 5
      }
      
      response = RequestHandler.handle_request(request) |> dbg
      
      assert response["jsonrpc"] == "2.0"
      assert response["id"] == 5
      
      # Should either return result or error
      assert response["result"] || response["error"]
      
      if response["result"] do
        assert is_list(response["result"]["content"])
        content = hd(response["result"]["content"])
        assert content["type"] == "text"
        assert content["text"]
      end
    end
    
    test "handles tools/call for get_type_info" do
      request = %{
        "method" => "tools/call",
        "params" => %{
          "name" => "get_type_info",
          "arguments" => %{"module" => "GenServer"}
        },
        "id" => 6
      }
      
      response = RequestHandler.handle_request(request)
      
      assert response["jsonrpc"] == "2.0"
      assert response["id"] == 6
      assert response["result"]
      
      assert is_list(response["result"]["content"])
      content = hd(response["result"]["content"])
      assert content["type"] == "text"
      text = content["text"]
      
      # GenServer should have actual type information
      assert text =~ "Type Information for GenServer"
      
      # GenServer is a behaviour, so it should have callbacks
      assert text =~ "## Callbacks" || text =~ "## Function Specs" || text =~ "## Types"
      
      # Should not show the "no type information" message for GenServer
      refute text =~ "No type information available"
    end
    
    test "handles tools/call with invalid tool name" do
      request = %{
        "method" => "tools/call",
        "params" => %{
          "name" => "invalid_tool",
          "arguments" => %{}
        },
        "id" => 7
      }
      
      response = RequestHandler.handle_request(request)
      
      assert response["jsonrpc"] == "2.0"
      assert response["id"] == 7
      assert response["error"]
      assert response["error"]["code"] == -32602
      assert response["error"]["message"] == "Invalid params"
    end
    
    test "handles tools/call with missing arguments" do
      request = %{
        "method" => "tools/call",
        "params" => %{
          "name" => "find_definition"
          # Missing arguments
        },
        "id" => 8
      }
      
      response = RequestHandler.handle_request(request)
      
      assert response["jsonrpc"] == "2.0"
      assert response["id"] == 8
      assert response["error"]
      assert response["error"]["code"] == -32602
    end
    
    test "handles notifications/cancelled request (returns nil)" do
      request = %{
        "method" => "notifications/cancelled",
        "params" => %{"requestId" => 123, "reason" => "User cancelled"}
      }
      
      response = RequestHandler.handle_request(request)
      
      assert response == nil
    end
    
    test "handles unknown method with id" do
      request = %{
        "method" => "unknown/method",
        "id" => 9
      }
      
      response = RequestHandler.handle_request(request)
      
      assert response["jsonrpc"] == "2.0"
      assert response["id"] == 9
      assert response["error"]
      assert response["error"]["code"] == -32601
      assert response["error"]["message"] =~ "Method not found: unknown/method"
    end
    
    test "handles invalid request (no method)" do
      request = %{
        "id" => 10
      }
      
      response = RequestHandler.handle_request(request)
      
      assert response["jsonrpc"] == "2.0"
      assert response["id"] == nil
      assert response["error"]
      assert response["error"]["code"] == -32600
      assert response["error"]["message"] == "Invalid request"
    end
    
    test "handles empty request" do
      request = %{}
      
      response = RequestHandler.handle_request(request)
      
      assert response["jsonrpc"] == "2.0"
      assert response["id"] == nil
      assert response["error"]
      assert response["error"]["code"] == -32600
      assert response["error"]["message"] == "Invalid request"
    end
  end
  
  describe "edge cases" do
    test "handles get_docs with non-list modules parameter" do
      request = %{
        "method" => "tools/call",
        "params" => %{
          "name" => "get_docs",
          "arguments" => %{"modules" => "String"}  # Should be a list
        },
        "id" => 11
      }
      
      response = RequestHandler.handle_request(request)
      
      assert response["jsonrpc"] == "2.0"
      assert response["id"] == 11
      assert response["error"]
      assert response["error"]["code"] == -32602
    end
    
    test "handles get_type_info with non-string module parameter" do
      request = %{
        "method" => "tools/call",
        "params" => %{
          "name" => "get_type_info",
          "arguments" => %{"module" => ["String"]}  # Should be a string
        },
        "id" => 12
      }
      
      response = RequestHandler.handle_request(request)
      
      assert response["jsonrpc"] == "2.0"
      assert response["id"] == 12
      assert response["error"]
      assert response["error"]["code"] == -32602
    end
    
    test "notification without id does not get response" do
      request = %{
        "method" => "notifications/cancelled",
        "params" => %{"requestId" => 456}
        # No id field - this is a notification
      }
      
      response = RequestHandler.handle_request(request)
      
      assert response == nil
    end
  end
  
  describe "integration with actual modules" do
    test "get_type_info returns meaningful data for known module" do
      request = %{
        "method" => "tools/call",
        "params" => %{
          "name" => "get_type_info",
          "arguments" => %{"module" => "Enum"}
        },
        "id" => 13
      }
      
      response = RequestHandler.handle_request(request)
      
      assert response["result"]
      content = hd(response["result"]["content"])
      text = content["text"]
      
      # Enum should have type information header
      assert text =~ "Type Information for Enum"
      # Should be a non-empty response
      assert String.length(text) > 20
    end
    
    test "get_docs returns documentation for known modules" do
      request = %{
        "method" => "tools/call",
        "params" => %{
          "name" => "get_docs",
          "arguments" => %{"modules" => ["String"]}
        },
        "id" => 14
      }
      
      response = RequestHandler.handle_request(request)
      
      assert response["result"]
      content = hd(response["result"]["content"])
      text = content["text"]
      
      assert text =~ "Module: String"
    end
    
    test "get_type_info shows no type info message for modules without types" do
      # First, let's create a module without any type specs
      defmodule TestModuleWithoutTypes do
        def hello, do: :world
      end
      
      request = %{
        "method" => "tools/call",
        "params" => %{
          "name" => "get_type_info",
          "arguments" => %{"module" => "ElixirLS.LanguageServer.MCP.RequestHandlerTest.TestModuleWithoutTypes"}
        },
        "id" => 15
      }
      
      response = RequestHandler.handle_request(request)
      
      assert response["result"]
      content = hd(response["result"]["content"])
      text = content["text"]
      
      # Should show the header
      assert text =~ "Type Information for"
      
      # Should show the "no type information" message
      assert text =~ "No type information available"
      assert text =~ "The module has no explicit type specifications"
    end
  end
end
