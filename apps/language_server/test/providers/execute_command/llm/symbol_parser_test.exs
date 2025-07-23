defmodule ElixirLS.LanguageServer.Providers.ExecuteCommand.LLM.SymbolParserTest do
  use ExUnit.Case, async: true

  alias ElixirLS.LanguageServer.Providers.ExecuteCommand.LLM.SymbolParser

  describe "parse/1 - aliases (modules)" do
    test "parses simple module" do
      assert {:ok, :module, String} = SymbolParser.parse("String")
      assert {:ok, :module, Enum} = SymbolParser.parse("Enum")
      assert {:ok, :module, GenServer} = SymbolParser.parse("GenServer")
    end

    test "parses nested module" do
      assert {:ok, :module, String.Chars} = SymbolParser.parse("String.Chars")
      assert {:ok, :module, Mix.Project} = SymbolParser.parse("Mix.Project")

      assert {:ok, :module, Some.Deeply.Nested.Module} =
               SymbolParser.parse("Some.Deeply.Nested.Module")
    end

    test "parses module with numbers" do
      assert {:ok, :module, Base64} = SymbolParser.parse("Base64")
    end

    test "parses single letter module names" do
      assert {:ok, :module, A} = SymbolParser.parse("A")
      assert {:ok, :module, A.B.C} = SymbolParser.parse("A.B.C")
    end
  end

  describe "parse/1 - remote calls (dot notation)" do
    test "parses remote call without arity" do
      assert {:ok, :remote_call, {String, :split, nil}} = SymbolParser.parse("String.split")
      assert {:ok, :remote_call, {Enum, :map, nil}} = SymbolParser.parse("Enum.map")
    end

    test "parses remote call with arity" do
      assert {:ok, :remote_call, {String, :split, 2}} = SymbolParser.parse("String.split/2")
      assert {:ok, :remote_call, {Enum, :map, 2}} = SymbolParser.parse("Enum.map/2")
    end

    test "parses nested module remote call" do
      assert {:ok, :remote_call, {String.Chars, :to_string, 1}} =
               SymbolParser.parse("String.Chars.to_string/1")
    end

    test "parses erlang remote call" do
      assert {:ok, :remote_call, {:lists, :map, 2}} = SymbolParser.parse(":lists.map/2")
      assert {:ok, :remote_call, {:lists, :map, nil}} = SymbolParser.parse(":lists.map")
    end
  end

  describe "parse/1 - local calls" do
    test "parses local call without arity" do
      assert {:ok, :local_call, {:foo, nil}} = SymbolParser.parse("foo")
      assert {:ok, :local_call, {:map, nil}} = SymbolParser.parse("map")
      assert {:ok, :local_call, {:send_message, nil}} = SymbolParser.parse("send_message")
    end

    test "parses local call with arity" do
      assert {:ok, :local_call, {:foo, 1}} = SymbolParser.parse("foo/1")
      assert {:ok, :local_call, {:map, 2}} = SymbolParser.parse("map/2")
      assert {:ok, :local_call, {:send_message, 0}} = SymbolParser.parse("send_message/0")
    end
  end

  describe "parse/1 - operators" do
    test "parses operator without arity" do
      assert {:ok, :local_call, {:+, nil}} = SymbolParser.parse("+")
      assert {:ok, :local_call, {:-, nil}} = SymbolParser.parse("-")
      assert {:ok, :local_call, {:*, nil}} = SymbolParser.parse("*")
      assert {:ok, :local_call, {:/, nil}} = SymbolParser.parse("/")
      assert {:ok, :local_call, {:==, nil}} = SymbolParser.parse("==")
      assert {:ok, :local_call, {:!=, nil}} = SymbolParser.parse("!=")
    end

    test "parses operator with arity" do
      assert {:ok, :local_call, {:+, 2}} = SymbolParser.parse("+/2")
      assert {:ok, :local_call, {:-, 1}} = SymbolParser.parse("-/1")
      assert {:ok, :local_call, {:*, 2}} = SymbolParser.parse("*/2")
      assert {:ok, :local_call, {:div, 2}} = SymbolParser.parse("div/2")
      assert {:ok, :local_call, {:==, 2}} = SymbolParser.parse("==/2")
      assert {:ok, :local_call, {:!=, 2}} = SymbolParser.parse("!=/2")
    end
  end

  describe "parse/1 - erlang modules (unquoted_atom)" do
    test "parses erlang modules" do
      assert {:ok, :module, :lists} = SymbolParser.parse(":lists")
      assert {:ok, :module, :erlang} = SymbolParser.parse(":erlang")
      assert {:ok, :module, :ets} = SymbolParser.parse(":ets")
      assert {:ok, :module, :crypto} = SymbolParser.parse(":crypto")
      assert {:ok, :module, :os} = SymbolParser.parse(":os")
    end
  end

  describe "parse/1 - module attributes" do
    test "parses module attributes" do
      assert {:ok, :attribute, :doc} = SymbolParser.parse("@doc")
      assert {:ok, :attribute, :moduledoc} = SymbolParser.parse("@moduledoc")
      assert {:ok, :attribute, :spec} = SymbolParser.parse("@spec")
      assert {:ok, :attribute, :type} = SymbolParser.parse("@type")
      assert {:ok, :attribute, :callback} = SymbolParser.parse("@callback")
      assert {:ok, :attribute, :behaviour} = SymbolParser.parse("@behaviour")
      assert {:ok, :attribute, :impl} = SymbolParser.parse("@impl")
    end
  end
end
