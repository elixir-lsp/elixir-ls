defmodule ElixirLS.LanguageServer.Experimental.ProtoTest do
  alias ElixirLS.LanguageServer.Experimental.Protocol.Proto
  alias ElixirLS.LanguageServer.Experimental.Protocol.Proto.LspTypes
  alias LSP.Types
  alias ElixirLS.LanguageServer.Experimental.SourceFile
  import ElixirLS.LanguageServer.Fixtures.LspProtocol

  require LspTypes.ErrorCodes

  use ExUnit.Case, async: true

  defmodule Child do
    use Proto

    deftype name: string()
  end

  describe "string fields" do
    defmodule StringField do
      use Proto

      deftype string_field: string()
    end

    test "can parse a string field" do
      assert {:ok, val} = StringField.parse(%{"stringField" => "value"})
      assert val.string_field == "value"
    end

    test "rejects nil string fields" do
      assert {:error, {:invalid_value, :string_field, nil}} =
               StringField.parse(%{"stringField" => nil})
    end
  end

  describe "integer fields" do
    defmodule IntegerField do
      use Proto
      deftype int_field: integer()
    end

    test "can parse an integer field" do
      assert {:ok, val} = IntegerField.parse(%{"intField" => 494})
      assert val.int_field == 494
    end

    test "rejects nil int fields" do
      assert {:error, {:invalid_value, :int_field, "string"}} =
               IntegerField.parse(%{"intField" => "string"})
    end
  end

  describe "float fields" do
    defmodule FloatField do
      use Proto
      deftype float_field: float()
    end

    test "can parse a float field" do
      assert {:ok, val} = FloatField.parse(%{"floatField" => 494.02})
      assert val.float_field == 494.02
    end

    test "rejects nil float fields" do
      assert {:error, {:invalid_value, :float_field, "string"}} =
               FloatField.parse(%{"floatField" => "string"})
    end
  end

  describe "list fields" do
    defmodule ListField do
      use Proto
      deftype list_field: list_of(integer())
    end

    test "can parse a list field" do
      assert {:ok, proto} = ListField.parse(%{"listField" => [1, 2, 3]})
      assert proto.list_field == [1, 2, 3]
    end

    test "rejecting invalid list of integers" do
      assert {:error, {:invalid_value, :list_field, 99}} = ListField.parse(%{"listField" => 99})

      assert {:error, {:invalid_value, :list_field, "hi"}} =
               ListField.parse(%{"listField" => ["hi"]})

      assert {:ok, result} = ListField.parse(%{"listField" => [99]})
      assert result.list_field == [99]
    end
  end

  describe "tuple fields" do
    defmodule TupleField do
      use Proto
      deftype tuple_field: tuple_of([integer(), string(), map_of(string())])
    end

    test "can be parsed" do
      assert {:ok, proto} =
               TupleField.parse(%{"tupleField" => [1, "hello", %{"k" => "3", "v" => "9"}]})

      assert proto.tuple_field == {1, "hello", %{"k" => "3", "v" => "9"}}
    end

    test "can be encoded" do
      proto = TupleField.new(tuple_field: {1, "hello", %{"k" => "v"}})

      assert {:ok, encoded} = encode_and_decode(proto)
      assert encoded["tupleField"] == [1, "hello", %{"k" => "v"}]
    end
  end

  describe "proto fields" do
    defmodule SingleParent do
      use Proto

      deftype name: string(), child: Child
    end

    test "can parse another proto" do
      assert {:ok, parent} =
               SingleParent.parse(%{
                 "name" => "stinky",
                 "child" => %{"name" => "Smelly"}
               })

      assert parent.name == "stinky"
      assert parent.child.name == "Smelly"
    end

    test "fails to parse another proto" do
      assert {:error, {:invalid_map, "bad"}} ==
               SingleParent.parse(%{"name" => "stinky", "child" => "bad"})

      assert {:error, {:missing_keys, ["name"], Child}} ==
               SingleParent.parse(%{"name" => "parent", "child" => %{"oof" => "not good"}})
    end
  end

  describe "type aliases" do
    defmodule TypeAlias do
      use Proto
      defalias one_of([string(), list_of(string())])
    end

    defmodule UsesAlias do
      use Proto

      deftype alias: type_alias(TypeAlias), name: string()
    end

    test "parses a single item correctly" do
      assert {:ok, uses} = UsesAlias.parse(%{"name" => "uses", "alias" => "foo"})
      assert uses.name == "uses"
      assert uses.alias == "foo"
    end

    test "parses a list correctly" do
      assert {:ok, uses} = UsesAlias.parse(%{"name" => "uses", "alias" => ["foo", "bar"]})
      assert uses.name == "uses"
      assert uses.alias == ~w(foo bar)
    end

    test "encodes correctly" do
      assert {:ok, encoded} = encode_and_decode(UsesAlias.new(alias: "hi", name: "easy"))
      assert encoded["alias"] == "hi"
      assert encoded["name"] == "easy"
    end

    test "parse fails if the type isn't correct" do
      assert {:error, {:incorrect_type, _, %{}}} =
               UsesAlias.parse(%{"name" => "ua", "alias" => %{}})
    end
  end

  describe "optional fields" do
    defmodule OptionalString do
      use Proto
      deftype required_string: string(), maybe_there: optional(string())
    end

    test "optional fields can be parsed" do
      assert {:ok, proto} =
               OptionalString.parse(%{"requiredString" => "req", "maybeThere" => "is_there"})

      assert proto.required_string == "req"
      assert proto.maybe_there == "is_there"
    end

    test "optional fields can be omitted" do
      assert {:ok, proto} = OptionalString.parse(%{"requiredString" => "req"})

      assert proto.required_string == "req"
      assert proto.maybe_there == nil
    end
  end

  describe "literal string fields" do
    defmodule LiteralString do
      use Proto

      deftype name: literal("name"), value: string()
    end

    test "it should parse correctly" do
      assert {:ok, proto} = LiteralString.parse(%{"name" => "name", "value" => "val"})
      assert proto.name == "name"
      assert proto.value == "val"
    end

    test "parse should fail if the value isn't the expected value" do
      assert {:error, {:invalid_value, :name, "not_name"}} =
               LiteralString.parse(%{"name" => "not_name", "value" => "val"})
    end
  end

  describe "literal list fields" do
    defmodule LiteralList do
      use Proto

      deftype name: string(), keys: literal([1, 2, 9, 10])
    end

    test "it should parse correctly" do
      assert {:ok, _} = LiteralList.parse(%{"name" => "ll", "keys" => [1, 2, 9, 10]})
    end

    test "parse should fail if the list isn't correct" do
      assert {:error, {:invalid_value, :keys, _}} =
               LiteralList.parse(%{"name" => "name", "keys" => [9, 2, 1, 10]})
    end
  end

  describe "any field" do
    defmodule AnyTest do
      use Proto
      deftype any_list: list_of(any()), any_toplevel: any(), any_optional: optional(any())
    end

    test "it should parse correctly" do
      assert {:ok, proto} =
               AnyTest.parse(%{
                 "anyList" => [1, 3, "a", "b", [43]],
                 "anyToplevel" => 999,
                 "anyOptional" => ["any"]
               })

      assert proto.any_list == [1, 3, "a", "b", [43]]
      assert proto.any_toplevel == 999
      assert proto.any_optional == ["any"]
    end

    test "it should let an optional field be omitted" do
      assert {:ok, proto} =
               AnyTest.parse(%{
                 "anyList" => [1, 3, "a", "b", [43]],
                 "anyToplevel" => 999
               })

      assert proto.any_optional == nil
    end
  end

  describe "constants" do
    defmodule ConstantTest do
      use Proto

      defenum(good: 1, bad: 2, ugly: 3)
    end

    defmodule UsesConstants do
      use Proto
      deftype name: string(), state: ConstantTest
    end

    test "it should define a constant module" do
      require ConstantTest
      assert ConstantTest.good() == 1
      assert ConstantTest.bad() == 2
      assert ConstantTest.ugly() == 3
    end

    test "constants should parse" do
      assert {:ok, :good} == ConstantTest.parse(1)
      assert {:ok, :bad} == ConstantTest.parse(2)
      assert {:ok, :ugly} == ConstantTest.parse(3)
      assert {:error, {:invalid_constant, 4}} = ConstantTest.parse(4)
    end

    test "constants should parse when used as values" do
      assert {:ok, proto} = UsesConstants.parse(%{"name" => "Clint", "state" => 1})
      assert proto.name == "Clint"
      assert proto.state == :good
    end

    test "constants should render as their values" do
      assert {:ok, proto} = UsesConstants.parse(%{"name" => "Clint", "state" => 2})
      assert {:ok, encoded} = JasonVendored.encode(proto)
      assert {:ok, decoded} = JasonVendored.decode(encoded)
      assert 2 == decoded["state"]
    end
  end

  describe "constructors" do
    defmodule RequiredFields do
      use Proto

      deftype name: string(), value: optional(string()), age: integer()
    end

    test "required fields are required" do
      assert_raise ArgumentError, fn ->
        RequiredFields.new()
      end

      assert_raise ArgumentError, fn ->
        RequiredFields.new(name: "hi", value: "good")
      end

      assert RequiredFields.new(name: "hi", value: "good", age: 29)
    end
  end

  def with_source_file_store(_) do
    source_file = """
    defmodule MyTest do
      def add(a, b), do: a + b
    end
    """

    file_uri = "file:///file.ex"
    {:ok, _} = start_supervised(SourceFile.Store)
    SourceFile.Store.open(file_uri, source_file, 1)

    {:ok, uri: file_uri}
  end

  describe "notifications" do
    setup [:with_source_file_store]

    defmodule Notif do
      use Proto

      defnotification "textDocument/somethingHappened",
                      :exlusive,
                      line: integer(),
                      notice_message: string(),
                      column: integer()
    end

    test "parse fills out the notification" do
      assert {:ok, params} =
               params_for(Notif, line: 3, column: 5, notice_message: "This went wrong")

      assert {:ok, notif} = Notif.parse(params)

      assert notif.method == "textDocument/somethingHappened"
      assert notif.jsonrpc == "2.0"
      assert notif.lsp.line == 3
      assert notif.lsp.column == 5
      assert notif.lsp.notice_message == "This went wrong"
    end

    test "the base request is not filled out when parse is called" do
      assert {:ok, params} =
               params_for(Notif, line: 3, column: 5, notice_message: "This went wrong")

      assert {:ok, notif} = Notif.parse(params)

      refute notif.line
      refute notif.column
      refute notif.notice_message
    end

    test "to_elixir fills out the elixir fields" do
      assert {:ok, params} =
               params_for(Notif, line: 3, column: 5, notice_message: "This went wrong")

      assert {:ok, notif} = Notif.parse(params)
      assert {:ok, notif} = Notif.to_elixir(notif)

      assert notif.line == 3
      assert notif.column == 5
      assert notif.notice_message == "This went wrong"
    end

    defmodule Notif.WithTextDoc do
      use Proto

      defnotification "notif/withTextDoc",
                      :exclusive,
                      text_document: Types.TextDocument.Identifier
    end

    test "to_elixir fills out the source file", ctx do
      assert {:ok, params} = params_for(Notif.WithTextDoc.LSP, text_document: [uri: ctx.uri])
      assert {:ok, notif} = Notif.WithTextDoc.parse(params)
      assert {:ok, notif} = Notif.WithTextDoc.to_elixir(notif)
      assert %SourceFile{} = notif.source_file
    end

    defmodule Notif.WithPos do
      use Proto

      defnotification "notif/WithPos",
                      :exclusive,
                      text_document: Types.TextDocument.Identifier,
                      position: Types.Position
    end

    test "to_elixir fills out a position", ctx do
      assert {:ok, params} =
               params_for(Notif.WithPos.LSP,
                 text_document: [uri: ctx.uri],
                 position: [line: 0, character: 0]
               )

      assert {:ok, notif} = Notif.WithPos.parse(params)
      assert {:ok, notif} = Notif.WithPos.to_elixir(notif)

      assert %SourceFile{} = notif.source_file
      assert %SourceFile.Position{} = notif.position
      assert notif.position.line == 1
      assert notif.position.character == 0
    end

    defmodule Notif.WithRange do
      use Proto

      defnotification "notif/WithPos",
                      :exclusive,
                      text_document: Types.TextDocument.Identifier,
                      range: Types.Range
    end

    test "to_elixir fills out a range", ctx do
      assert {:ok, params} =
               params_for(Notif.WithRange.LSP,
                 text_document: [uri: ctx.uri],
                 range: [
                   start: [line: 0, character: 0],
                   end: [line: 0, character: 3]
                 ]
               )

      assert {:ok, notif} = Notif.WithRange.parse(params)
      assert {:ok, notif} = Notif.WithRange.to_elixir(notif)

      assert %SourceFile{} = notif.source_file
      assert %SourceFile.Range{} = notif.range
      assert notif.range.start.line == 1
      assert notif.range.start.character == 0
      assert notif.range.end.line == 1
      assert notif.range.end.character == 3
    end
  end

  describe "requests" do
    setup [:with_source_file_store]

    defmodule Req do
      use Proto

      defrequest "something", :exclusive, line: integer(), error_message: string()
    end

    defmodule TextDocReq do
      use Proto

      defrequest "textDoc", :exclusive, text_document: Types.TextDocument.Identifier
    end

    test "parse fills out the request" do
      assert {:ok, params} = params_for(Req, id: 3, line: 9, error_message: "borked")
      assert {:ok, req} = Req.parse(params)
      assert req.id == "3"
      assert req.method == "something"
      assert req.jsonrpc == "2.0"
      assert req.lsp.line == 9
      assert req.lsp.error_message == "borked"
    end

    test "the base request is not filled out via parsing" do
      assert {:ok, params} = params_for(Req, id: 3, line: 9, error_message: "borked")
      assert {:ok, req} = Req.parse(params)

      refute req.line
      refute req.error_message
    end

    test "parse fills out the raw lsp request" do
      assert {:ok, params} = params_for(Req, id: 3, line: 9, error_message: "borked")
      assert {:ok, req} = Req.parse(params)
      assert req.lsp.line == 9
      assert req.lsp.error_message == "borked"
    end

    test "to_elixir fills out the base request" do
      assert {:ok, params} = params_for(Req, id: 3, line: 9, error_message: "borked")
      assert {:ok, req} = Req.parse(params)
      assert {:ok, req} = Req.to_elixir(req)

      assert req.line == 9
      assert req.error_message == "borked"
    end

    test "to_elixir fills out a source file", ctx do
      assert {:ok, params} = params_for(TextDocReq.LSP, text_document: [uri: ctx.uri])
      assert {:ok, req} = TextDocReq.parse(params)
      assert {:ok, ex_req} = TextDocReq.to_elixir(req)

      assert %TextDocReq{} = ex_req
      assert %SourceFile{} = ex_req.source_file
    end

    defmodule PositionReq do
      use Proto

      defrequest "posReq", :exclusive,
        text_document: Types.TextDocument.Identifier,
        position: Types.Position
    end

    test "to_elixir fills out a position", ctx do
      assert {:ok, params} =
               params_for(PositionReq.LSP,
                 text_document: [uri: ctx.uri],
                 position: [line: 1, character: 6]
               )

      assert {:ok, req} = PositionReq.parse(params)

      refute req.position
      refute req.source_file

      assert {:ok, ex_req} = PositionReq.to_elixir(req)

      assert %SourceFile.Position{} = ex_req.position
      assert %SourceFile{} = ex_req.source_file
    end

    defmodule RangeReq do
      use Proto

      defrequest "rangeReq", :exclusive,
        text_document: Types.TextDocument.Identifier,
        range: Types.Range
    end

    test "to_elixir fills out a range", ctx do
      assert {:ok, params} =
               params_for(RangeReq.LSP,
                 text_document: [uri: ctx.uri],
                 range: [start: [line: 0, character: 0], end: [line: 0, character: 5]]
               )

      assert {:ok, req} = RangeReq.parse(params)
      assert {:ok, req} = RangeReq.to_elixir(req)

      assert req.range ==
               SourceFile.Range.new(
                 SourceFile.Position.new(1, 0),
                 SourceFile.Position.new(1, 5)
               )
    end
  end

  describe "responses" do
    defmodule Resp do
      use Proto

      defresponse list_of(integer())
    end

    test "you can create a response" do
      response = Resp.new(123, [8, 6, 7, 5])
      assert response.result == [8, 6, 7, 5]
      refute response.error
    end

    test "you can create an error with a code" do
      response = Resp.error(123, 33816, "this is bad")
      assert response.id == 123
      assert response.error.code == 33816
    end

    test "you can create an error with a message" do
      response = Resp.error(123, 33816, "this is bad")
      assert response.id == 123
      assert response.error.code == 33816
      assert response.error.message == "this is bad"
    end

    test "a response can be encoded and decoded" do
      response = Resp.new(123, [8, 6, 7, 5])

      assert {:ok, decoded} = encode_and_decode(response)

      assert decoded["id"] == 123
      assert decoded["result"] == [8, 6, 7, 5]
    end

    test "an error can be encoded and decoded" do
      error = Resp.error(123, :parse_error, "super bad")
      assert {:ok, decoded} = encode_and_decode(error)

      assert decoded["id"] == 123
      assert decoded["error"]["message"] == "super bad"
      assert decoded["error"]["code"] == LspTypes.ErrorCodes.parse_error()
    end
  end

  describe "encoding" do
    defmodule Mood do
      use Proto
      defenum happy: 1, sad: 2, miserable: 3
    end

    defmodule EncodingTest do
      use Proto

      deftype s: string(),
              a: any(),
              l: list_of(string()),
              i: integer(),
              lit: literal("foo"),
              enum: Mood,
              c: optional(Child),
              snake_case_name: string()
    end

    def fixture(:encoding, include_child \\ false) do
      base = %{
        "s" => "hello",
        "a" => ["a", "there"],
        "l" => ~w(these are strings),
        "i" => 42,
        "enum" => 1,
        "lit" => "foo",
        "snakeCaseName" => "foo"
      }

      if include_child do
        Map.put(base, "c", Child.new(name: "eric"))
      else
        base
      end
    end

    def encode_and_decode(%_struct{} = proto) do
      with {:ok, encoded} <- JasonVendored.encode(proto) do
        JasonVendored.decode(encoded)
      end
    end

    test "it should be able to encode" do
      expected = fixture(:encoding)
      assert {:ok, proto} = EncodingTest.parse(expected)
      assert {:ok, decoded} = encode_and_decode(proto)
      assert decoded == expected
    end

    test "it camelizes encoded field names" do
      expected = fixture(:encoding)
      assert {:ok, proto} = EncodingTest.parse(expected)
      assert proto.snake_case_name == "foo"
      assert {:ok, decoded} = encode_and_decode(proto)
      assert decoded["snakeCaseName"] == "foo"
    end
  end

  describe "spread" do
    defmodule SpreadTest do
      use Proto

      deftype name: string(), ..: map_of(string(), as: :opts)
    end

    test "it should accept any string keys" do
      assert {:ok, proto} = SpreadTest.parse(%{"name" => "spread", "key" => "value"})
      assert proto.name == "spread"
      assert proto.opts == %{"key" => "value"}
    end

    test "it should encode the spread" do
      spread = SpreadTest.new(name: "spread", opts: %{"key" => "value"})

      assert {:ok, decoded} = encode_and_decode(spread)

      assert decoded["key"] == "value"
      assert decoded["name"] == "spread"
    end
  end

  describe "access behavior" do
    defmodule Recursive do
      use Proto
      deftype name: string(), age: integer(), child: optional(__MODULE__)
    end

    def family do
      grandkid = Recursive.new(name: "grandkid", age: 8)
      child = Recursive.new(name: "child", age: 53, child: grandkid)
      Recursive.new(name: "parent", age: 65, child: child)
    end

    test "access should work" do
      parent = family()
      assert get_in(parent, [:child, :child, :age]) == parent.child.child.age
      assert get_in(parent, [:child, :age]) == parent.child.age
    end

    test "put_in should work" do
      parent = put_in(family(), [:child, :child, :age], 28)
      assert parent.child.child.age == 28
    end

    test "get and update in should work" do
      {"grandkid", parent} =
        get_and_update_in(family(), [:child, :child, :name], fn old_name ->
          {old_name, "erica"}
        end)

      assert parent.child.child.name == "erica"
    end
  end
end
