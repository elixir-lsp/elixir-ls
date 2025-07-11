defmodule ElixirLS.LanguageServer.Providers.ExecuteCommand.LLM.SymbolParserV2Test do
  use ExUnit.Case, async: true

  alias ElixirLS.LanguageServer.Providers.ExecuteCommand.LLM.SymbolParserV2

  describe "parse/1 - aliases (modules)" do
    test "parses simple module" do
      assert {:ok, :module, String} = SymbolParserV2.parse("String")
      assert {:ok, :module, Enum} = SymbolParserV2.parse("Enum")
      assert {:ok, :module, GenServer} = SymbolParserV2.parse("GenServer")
    end

    test "parses nested module" do
      assert {:ok, :module, String.Chars} = SymbolParserV2.parse("String.Chars")
      assert {:ok, :module, Mix.Project} = SymbolParserV2.parse("Mix.Project")
      assert {:ok, :module, Some.Deeply.Nested.Module} = 
        SymbolParserV2.parse("Some.Deeply.Nested.Module")
    end

    test "parses module with numbers" do
      assert {:ok, :module, Base64} = SymbolParserV2.parse("Base64")
    end

    test "parses single letter module names" do
      assert {:ok, :module, A} = SymbolParserV2.parse("A")
      assert {:ok, :module, A.B.C} = SymbolParserV2.parse("A.B.C")
    end
  end

  describe "parse/1 - remote calls (dot notation)" do
    test "parses remote call without arity" do
      assert {:ok, :remote_call, {String, :split, nil}} = SymbolParserV2.parse("String.split")
      assert {:ok, :remote_call, {Enum, :map, nil}} = SymbolParserV2.parse("Enum.map")
    end

    test "parses remote call with arity" do
      assert {:ok, :remote_call, {String, :split, 2}} = SymbolParserV2.parse("String.split/2")
      assert {:ok, :remote_call, {Enum, :map, 2}} = SymbolParserV2.parse("Enum.map/2")
    end

    test "parses nested module remote call" do
      assert {:ok, :remote_call, {String.Chars, :to_string, 1}} = SymbolParserV2.parse("String.Chars.to_string/1")
    end

    test "parses erlang remote call" do
      assert {:ok, :remote_call, {:lists, :map, 2}} = SymbolParserV2.parse(":lists.map/2")
      assert {:ok, :remote_call, {:lists, :map, nil}} = SymbolParserV2.parse(":lists.map")
    end
  end

  describe "parse/1 - local calls" do
    test "parses local call without arity" do
      assert {:ok, :local_call, {:foo, nil}} = SymbolParserV2.parse("foo")
      assert {:ok, :local_call, {:map, nil}} = SymbolParserV2.parse("map")
      assert {:ok, :local_call, {:send_message, nil}} = SymbolParserV2.parse("send_message")
    end

    test "parses local call with arity" do
      assert {:ok, :local_call, {:foo, 1}} = SymbolParserV2.parse("foo/1")
      assert {:ok, :local_call, {:map, 2}} = SymbolParserV2.parse("map/2")
      assert {:ok, :local_call, {:send_message, 0}} = SymbolParserV2.parse("send_message/0")
    end
  end

  describe "parse/1 - operators" do
    test "parses operator without arity" do
      assert {:ok, :local_call, {:+, nil}} = SymbolParserV2.parse("+")
      assert {:ok, :local_call, {:-, nil}} = SymbolParserV2.parse("-")
      assert {:ok, :local_call, {:*, nil}} = SymbolParserV2.parse("*")
      assert {:ok, :local_call, {:/, nil}} = SymbolParserV2.parse("/")
      assert {:ok, :local_call, {:==, nil}} = SymbolParserV2.parse("==")
      assert {:ok, :local_call, {:!=, nil}} = SymbolParserV2.parse("!=")
    end

    test "parses operator with arity" do
      assert {:ok, :local_call, {:+, 2}} = SymbolParserV2.parse("+/2")
      assert {:ok, :local_call, {:-, 1}} = SymbolParserV2.parse("-/1")
      assert {:ok, :local_call, {:*, 2}} = SymbolParserV2.parse("*/2")
      assert {:ok, :local_call, {:div, 2}} = SymbolParserV2.parse("div/2")
      assert {:ok, :local_call, {:==, 2}} = SymbolParserV2.parse("==/2")
      assert {:ok, :local_call, {:!=, 2}} = SymbolParserV2.parse("!=/2")
    end
  end

  describe "parse/1 - erlang modules (unquoted_atom)" do
    test "parses erlang modules" do
      assert {:ok, :module, :lists} = SymbolParserV2.parse(":lists")
      assert {:ok, :module, :erlang} = SymbolParserV2.parse(":erlang")
      assert {:ok, :module, :ets} = SymbolParserV2.parse(":ets")
      assert {:ok, :module, :crypto} = SymbolParserV2.parse(":crypto")
      assert {:ok, :module, :os} = SymbolParserV2.parse(":os")
    end
  end

  describe "parse/1 - module attributes" do
    test "parses module attributes" do
      assert {:ok, :attribute, :doc} = SymbolParserV2.parse("@doc")
      assert {:ok, :attribute, :moduledoc} = SymbolParserV2.parse("@moduledoc")
      assert {:ok, :attribute, :spec} = SymbolParserV2.parse("@spec")
      assert {:ok, :attribute, :type} = SymbolParserV2.parse("@type")
      assert {:ok, :attribute, :callback} = SymbolParserV2.parse("@callback")
      assert {:ok, :attribute, :behaviour} = SymbolParserV2.parse("@behaviour")
      assert {:ok, :attribute, :impl} = SymbolParserV2.parse("@impl")
    end
  end
end
