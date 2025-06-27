defmodule ElixirLS.LanguageServer.MCP.Tools.FindDefinitionTest do
  use ExUnit.Case, async: false
  
  alias ElixirLS.LanguageServer.MCP.Tools.FindDefinition
  alias Hermes.Server.Response
  
  describe "execute/2" do
    test "finds module definition" do
      # Test with a built-in module
      result = FindDefinition.execute(%{symbol: "Enum"}, %{})
      
      assert {:reply, response, _frame} = result
      assert %Response{} = response
      assert response.type == :tool
      
      # Check that the response contains definition information
      [content] = response.content
      assert content.type == "text"
      assert content.text =~ "Definition found in"
      assert content.text =~ "defmodule Enum"
    end
    
    test "finds function definition with arity" do
      result = FindDefinition.execute(%{symbol: "Enum.map/2"}, %{})
      
      assert {:reply, response, _frame} = result
      assert %Response{} = response
      
      [content] = response.content
      assert content.type == "text"
      assert content.text =~ "Definition found in"
      assert content.text =~ "def map"
    end
    
    test "finds function definition without arity" do
      result = FindDefinition.execute(%{symbol: "Enum.map"}, %{})
      
      assert {:reply, response, _frame} = result
      assert %Response{} = response
      
      [content] = response.content
      assert content.type == "text"
      # Should find one of the map function definitions
      assert content.text =~ "def map"
    end
    
    test "handles erlang module" do
      result = FindDefinition.execute(%{symbol: ":ets"}, %{})
      
      assert {:reply, response, _frame} = result
      assert %Response{} = response
      
      [content] = response.content
      assert content.type == "text"
      # Should either find the module or report an error
      assert content.text =~ "Definition found in" or content.text =~ "Error:"
    end
    
    test "handles non-existent module" do
      result = FindDefinition.execute(%{symbol: "NonExistentModule"}, %{})
      
      assert {:reply, response, _frame} = result
      assert %Response{} = response
      
      [content] = response.content
      assert content.type == "text"
      assert content.text =~ "Error:"
      assert content.text =~ "not found"
    end
    
    test "handles invalid symbol format" do
      result = FindDefinition.execute(%{symbol: "not-a-valid-symbol!"}, %{})
      
      assert {:reply, response, _frame} = result
      assert %Response{} = response
      
      [content] = response.content
      assert content.type == "text"
      assert content.text =~ "Error:"
      assert content.text =~ "Invalid symbol format"
    end
  end
  
  describe "schema validation" do
    test "symbol field is required" do
      # The schema should enforce that symbol is required
      # This would be validated by Hermes when processing the request
      assert :symbol in FindDefinition.__schema__(:required_fields)
    end
    
    test "symbol field is string type" do
      schema = FindDefinition.__schema__(:fields)
      assert {:symbol, :string} in schema
    end
  end
end