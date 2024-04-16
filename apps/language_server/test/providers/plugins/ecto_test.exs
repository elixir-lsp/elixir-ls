defmodule ElixirLS.LanguageServer.Plugins.EctoTest do
  use ExUnit.Case
  import ExUnit.CaptureIO

  def cursors(text) do
    {_, cursors} =
      ElixirSense.Core.Source.walk_text(text, {false, []}, fn
        "#", rest, _, _, {_comment?, cursors} ->
          {rest, {true, cursors}}

        "\n", rest, _, _, {_comment?, cursors} ->
          {rest, {false, cursors}}

        "^", rest, line, col, {true, cursors} ->
          {rest, {true, [%{line: line - 1, col: col} | cursors]}}

        _, rest, _, _, acc ->
          {rest, acc}
      end)

    Enum.reverse(cursors)
  end

  def suggestions(buffer, cursor) do
    ElixirLS.LanguageServer.Providers.Completion.Suggestion.suggestions(
      buffer,
      cursor.line,
      cursor.col
    )
  end

  describe "decorate" do
    test "update snippet for Ecto.Schema.schema/2" do
      buffer = """
      import Ecto.Schema
      sche
      #   ^
      """

      [cursor] = cursors(buffer)

      result = suggestions(buffer, cursor)

      assert [%{name: "schema", arity: 2, snippet: snippet}] = result

      assert snippet == """
             schema "$1" do
               $0
             end
             """
    end
  end

  describe "suggesting ecto types" do
    # test "suggestion info for bult-in types" do
    #   buffer = """
    #   import Ecto.Schema
    #   field name, {:
    #   #             ^
    #   """

    #   [cursor] = cursors(buffer)

    #   result = suggestions(buffer, cursor)

    #   assert [
    #            %{
    #              detail: "Ecto type",
    #              label: "{:array, inner_type}",
    #              insert_text: "array, inner_type}",
    #              kind: :type_parameter,
    #              documentation: doc,
    #              type: :generic
    #            },
    #            %{detail: "Ecto type", label: "{:map, inner_type}"}
    #          ] = result

    #   assert doc == """
    #          Built-in Ecto type.

    #          * **Elixir type:** `list`
    #          * **Literal syntax:** `[value, value, ...]`\
    #          """
    # end

    test "suggestion info for custom types" do
      buffer = """
      import Ecto.Schema
      field name, Ecto.U
      #                 ^
      """

      [cursor] = cursors(buffer)

      result = suggestions(buffer, cursor)

      assert [
               %{
                 detail: "Ecto custom type",
                 label: "Ecto.UUID",
                 kind: :type_parameter,
                 insert_text: "UUID",
                 documentation: doc,
                 type: :generic
               }
             ] = result

      assert doc == """
             Fake Ecto.UUID
             """
    end

    test "insert_text includes leading `:` if it's not present" do
      buffer = """
      import Ecto.Schema
      field name,
      #          ^
      """

      [cursor] = cursors(buffer)

      result = suggestions(buffer, cursor)

      assert [%{insert_text: ":string"} | _] = result
    end

    test "insert_text does not include leading `:` if it's already present" do
      buffer = """
      import Ecto.Schema
      field name, :f
      #             ^
      """

      [cursor] = cursors(buffer)

      result = suggestions(buffer, cursor)

      assert [%{insert_text: "float"}] = result
    end

    # TODO
    # test "insert_text/snippet include trailing `}` if it's not present" do
    #   buffer = """
    #   import Ecto.Schema
    #   field name, {:arr
    #   #                ^
    #   """

    #   [cursor] = cursors(buffer)

    #   result = suggestions(buffer, cursor)

    #   assert [%{insert_text: "array, inner_type}", snippet: "array, ${1:inner_type}}"}] = result
    # end

    # test "insert_text/snippet do not include trailing `}` if it's already present" do
    #   buffer = """
    #   import Ecto.Schema
    #   field name, {:arr}
    #   #                ^
    #   """

    #   [cursor] = cursors(buffer)

    #   result = suggestions(buffer, cursor)

    #   assert [%{insert_text: "array, inner_type", snippet: "array, ${1:inner_type}"}] = result
    # end
  end

  describe "suggesting ecto schemas" do
    setup do
      Code.ensure_loaded(ElixirLS.LanguageServer.Plugins.Ecto.FakeSchemas.Comment)
      Code.ensure_loaded(ElixirLS.LanguageServer.Plugins.Ecto.FakeSchemas.Post)
      Code.ensure_loaded(ElixirLS.LanguageServer.Plugins.Ecto.FakeSchemas.User)
      Code.ensure_loaded(ElixirLS.LanguageServer.Plugins.Ecto.FakeSchemas.Tag)
      :ok
    end

    test "suggest all available schemas" do
      buffer = """
      import Ecto.Schema
      has_many :posts,
      #                ^
      """

      [cursor] = cursors(buffer)

      [
        %{label: "ElixirLS.LanguageServer.Plugins.Ecto.FakeSchemas.Comment"},
        %{label: "ElixirLS.LanguageServer.Plugins.Ecto.FakeSchemas.Post"},
        %{label: "ElixirLS.LanguageServer.Plugins.Ecto.FakeSchemas.Tag"},
        %{label: "ElixirLS.LanguageServer.Plugins.Ecto.FakeSchemas.User"}
      ] = suggestions(buffer, cursor)
    end

    test "match the hint ignoring the case against the full module name or just the last part" do
      buffer = """
      import Ecto.Schema
      has_many :posts, po
      #                  ^
      """

      [cursor] = cursors(buffer)

      [%{label: "ElixirLS.LanguageServer.Plugins.Ecto.FakeSchemas.Post"}] =
        suggestions(buffer, cursor)

      buffer = """
      import Ecto.Schema
      has_many :posts, ElixirLS.LanguageServer.Plugins.Ecto.FakeSchemas.Po
      #                                                                   ^
      """

      [cursor] = cursors(buffer)

      [%{label: "ElixirLS.LanguageServer.Plugins.Ecto.FakeSchemas.Post"}] =
        suggestions(buffer, cursor)
    end

    test "suggestion info" do
      buffer = """
      import Ecto.Schema
      has_many :posts, Po
      #                  ^
      """

      [cursor] = cursors(buffer)
      [suggestion] = suggestions(buffer, cursor)

      assert suggestion == %{
               detail: "Ecto schema",
               documentation: "Fake Post schema.\n",
               kind: :class,
               label: "ElixirLS.LanguageServer.Plugins.Ecto.FakeSchemas.Post",
               insert_text: "ElixirLS.LanguageServer.Plugins.Ecto.FakeSchemas.Post",
               type: :generic
             }
    end
  end

  describe "suggestions for Ecto.Query.from/2" do
    test "list clauses (any Ecto.Query macro that has `query` as first argument" do
      buffer = """
      import Ecto.Query

      from(
        u in User,
        where: is_nil(u.id),
        s
      #  ^
      )
      """

      [cursor] = cursors(buffer)

      capture_io(:stderr, fn ->
        result = suggestions(buffer, cursor)
        send(self(), {:result, result})
      end)

      assert_received {:result, result}

      detail = "(from clause) Ecto.Query"

      assert [
               %{
                 documentation: doc1,
                 label: "select",
                 detail: ^detail,
                 kind: :property,
                 insert_text: "select: "
               },
               %{documentation: doc2, label: "select_merge", detail: ^detail}
             ] = result

      assert doc1 == """
             A select query expression.

             ### Example

                 from(c in City, select: c) # returns the schema as a struct
                 from(c in City, select: {c.name, c.population})
                 from(c in City, select: [c.name, c.county])\
             """

      assert doc2 =~ "Mergeable select query expression."
    end

    test "list different available join types" do
      buffer = """
      import Ecto.Query

      from(
        u in User,
        where: is_nil(u.id),
        l
      #  ^
      )
      """

      [cursor] = cursors(buffer)

      capture_io(:stderr, fn ->
        result = suggestions(buffer, cursor)
        send(self(), {:result, result})
      end)

      assert_received {:result, result}

      detail = "(from clause) Ecto.Query"

      assert [
               %{documentation: doc1, label: "left_join", detail: ^detail, kind: :property},
               %{documentation: doc2, label: "left_lateral_join", detail: ^detail}
             ] = result

      assert doc1 == "A left join query expression."
      assert doc2 =~ "A left lateral join query expression."
    end

    test "join options" do
      buffer = """
      import Ecto.Query

      from(
        u in User,
        where: is_nil(u.id),
        prefix: "pre",
      #  ^
        o
      #  ^
      )
      """

      [cursor_1, cursor_2] = cursors(buffer)

      capture_io(:stderr, fn ->
        results = {suggestions(buffer, cursor_1), suggestions(buffer, cursor_2)}
        send(self(), {:results, results})
      end)

      assert_received {:results, {result_1, result_2}}

      assert [%{documentation: doc, label: "prefix", detail: detail, kind: kind}] = result_1
      assert kind == :property
      assert detail == "(from/join option) Ecto.Query"
      assert doc == "The prefix to be used for the from/join when issuing a database query."

      assert [%{documentation: doc, label: "on", detail: detail, kind: kind}] = result_2
      assert kind == :property
      assert detail == "(join option) Ecto.Query"
      assert doc == "A query expression or keyword list to filter the join."
    end

    # TODO
    # test "list available bindings" do
    #   buffer = """
    #   import Ecto.Query
    #   alias ElixirLS.LanguageServer.Plugins.Ecto.FakeSchemas.User, as: User

    #   def query() do
    #     from(
    #       u in User,
    #       join: m1 in Mod1,
    #       join: m2 in Mod2,
    #       left_join: a1 in assoc(u, :assoc1),
    #       inner_join: a2 in assoc(u, :assoc2),
    #       where: a2 in subquery(from(s in Sub, limit: 1)),
    #       where: u.id == m
    #     #        ^        ^
    #   end
    #   """

    #   [cursor_1, cursor_2] = cursors(buffer)

    #   assert [
    #            %{label: "a1"},
    #            %{label: "a2"},
    #            %{label: "m1"},
    #            %{label: "m2"},
    #            %{label: "u", kind: :variable, detail: detail, documentation: doc}
    #          ] = suggestions(buffer, cursor_1, :generic)

    #   assert detail == "(query binding) ElixirLS.LanguageServer.Plugins.Ecto.FakeSchemas.User"
    #   assert doc == "Fake User schema."

    #   assert [%{label: "m1"}, %{label: "m2"}] = suggestions(buffer, cursor_2, :generic)
    # end

    # test "list binding's fields" do
    #   buffer = """
    #   import Ecto.Query
    #   alias ElixirLS.LanguageServer.Plugins.Ecto.FakeSchemas.Post
    #   alias ElixirLS.LanguageServer.Plugins.Ecto.FakeSchemas.Comment

    #   def query() do
    #     from(
    #       p in Post,
    #       join: u in assoc(p, :user),
    #       left_join: c in Comment,
    #       select: {u.id, c.id, p.t, p.u}
    #       #          ^     ^      ^    ^
    #     )
    #   end
    #   """

    #   [cursor_1, cursor_2, cursor_3, cursor_4] = cursors(buffer)

    #   assert [
    #            %{label: "email", detail: "Ecto field", kind: :field},
    #            %{label: "id"},
    #            %{label: "name"}
    #          ] = suggestions(buffer, cursor_1)

    #   assert [%{label: "content"}, %{label: "date"}] = suggestions(buffer, cursor_2)

    #   assert [%{label: "text"}, %{label: "title"}] = suggestions(buffer, cursor_3)

    #   assert [%{label: "user_id", documentation: doc}] = suggestions(buffer, cursor_4)

    #   assert doc == """
    #          The `:user_id` field of `ElixirLS.LanguageServer.Plugins.Ecto.FakeSchemas.Post`.

    #          * **Type:** `:id`
    #          * **Related:** `ElixirLS.LanguageServer.Plugins.Ecto.FakeSchemas.User (:id)`
    #          """
    # end

    # test "list binding's fields even without any hint after `.`" do
    #   buffer = """
    #   import Ecto.Query
    #   alias ElixirLS.LanguageServer.Plugins.Ecto.FakeSchemas.Post

    #   def query() do
    #     from(
    #       p in Post,
    #       join: c in assoc(p, :comments),
    #       select: {p., c.id}
    #       #          ^
    #     )
    #   end
    #   """

    #   [cursor] = cursors(buffer)

    #   assert [
    #            %{label: "date"},
    #            %{label: "id"},
    #            %{label: "text"},
    #            %{label: "title"},
    #            %{label: "user_id"}
    #          ] = suggestions(buffer, cursor)
    # end

    test "list associations from assoc/2" do
      buffer = """
      import Ecto.Query
      alias ElixirLS.LanguageServer.Plugins.Ecto.FakeSchemas.Post

      def query() do
        from(
          p in Post,
          join: c in assoc(p,
          #                  ^
        )
      end
      """

      [cursor] = cursors(buffer)

      assert [
               %{
                 label: ":user",
                 detail: detail,
                 documentation: doc,
                 kind: :field,
                 type: :generic
               },
               %{label: ":comments"},
               %{label: ":tags"}
             ] = suggestions(buffer, cursor)

      assert doc == "Fake User schema."
      assert detail == "(Ecto association) ElixirLS.LanguageServer.Plugins.Ecto.FakeSchemas.User"
    end

    # test "list available schemas after `in`" do
    #   Code.ensure_loaded(ElixirLS.LanguageServer.Plugins.Ecto.FakeSchemas.Comment)
    #   Code.ensure_loaded(ElixirLS.LanguageServer.Plugins.Ecto.FakeSchemas.Post)
    #   Code.ensure_loaded(ElixirLS.LanguageServer.Plugins.Ecto.FakeSchemas.User)
    #   Code.ensure_loaded(ElixirLS.LanguageServer.Plugins.Ecto.FakeSchemas.Tag)

    #   buffer = """
    #   import Ecto.Query
    #   alias ElixirLS.LanguageServer.Plugins.Ecto.FakeSchemas.Post
    #   alias ElixirLS.LanguageServer.Plugins.Ecto.FakeSchemas.Comment

    #   def query() do
    #     from p in Post, join: c in Comment
    #       #       ^                ^
    #   end
    #   """

    #   [cursor_1, cursor_2] = cursors(buffer)

    #   assert [
    #            %{label: "ElixirLS.LanguageServer.Plugins.Ecto.FakeSchemas.Comment"},
    #            %{label: "ElixirLS.LanguageServer.Plugins.Ecto.FakeSchemas.Post"},
    #            %{label: "ElixirLS.LanguageServer.Plugins.Ecto.FakeSchemas.Tag"},
    #            %{label: "ElixirLS.LanguageServer.Plugins.Ecto.FakeSchemas.User"}
    #            | _
    #          ] = suggestions(buffer, cursor_1)

    #   assert [
    #            %{label: "ElixirLS.LanguageServer.Plugins.Ecto.FakeSchemas.Comment"},
    #            %{label: "ElixirLS.LanguageServer.Plugins.Ecto.FakeSchemas.Post"},
    #            %{label: "ElixirLS.LanguageServer.Plugins.Ecto.FakeSchemas.Tag"},
    #            %{label: "ElixirLS.LanguageServer.Plugins.Ecto.FakeSchemas.User"}
    #            | _
    #          ] = suggestions(buffer, cursor_2)
    # end

    test "list bindings and binding fields inside nested functions" do
      buffer = """
      import Ecto.Query
      alias ElixirLS.LanguageServer.Plugins.Ecto.FakeSchemas.Post

      def query() do
        from(
          p in Post,
          where: is_nil(p.t
          #             ^  ^
        )
      end
      """

      [cursor_1, cursor_2] = cursors(buffer)

      assert [%{label: "p"} | _] = suggestions(buffer, cursor_1)
      assert [%{label: "text"}, %{label: "title"}] = suggestions(buffer, cursor_2)
    end

    test "list bindings and binding fields using full module name" do
      buffer = """
      import Ecto.Query

      def query() do
        from p in ElixirLS.LanguageServer.Plugins.Ecto.FakeSchemas.Post,
          where: p.t
        #        ^  ^
      end
      """

      [cursor_1, cursor_2] = cursors(buffer)

      assert [%{label: "p"} | _] = suggestions(buffer, cursor_1)
      assert [%{label: "text"}, %{label: "title"}] = suggestions(buffer, cursor_2)
    end

    test "from/2 without parens" do
      buffer = """
      import Ecto.Query
      alias ElixirLS.LanguageServer.Plugins.Ecto.FakeSchemas.Post

      def query() do
        from p in Post, se
          #               ^
      end
      """

      [cursor] = cursors(buffer)

      assert [%{label: "select"}, %{label: "select_merge"}] = suggestions(buffer, cursor)

      buffer = """
      import Ecto.Query
      alias ElixirLS.LanguageServer.Plugins.Ecto.FakeSchemas.Post

      def query() do
        from p in Post, where: p.id
          #                       ^
      end
      """

      [cursor] = cursors(buffer)

      assert [%{label: "id"}] = suggestions(buffer, cursor)

      buffer = """
      import Ecto.Query
      alias ElixirLS.LanguageServer.Plugins.Ecto.FakeSchemas.Post

      def query() do
        from p in Post,
          join: u in User,
          se
          # ^
      end
      """

      [cursor] = cursors(buffer)

      assert [%{label: "select"}, %{label: "select_merge"}] = suggestions(buffer, cursor)

      buffer = """
      import Ecto.Query
      alias ElixirLS.LanguageServer.Plugins.Ecto.FakeSchemas.Post

      def query() do
        from p in Post,
          join: u in User,

        # ^
      end
      """

      [cursor] = cursors(buffer)

      assert [%{detail: "(from clause) Ecto.Query"} | _] = suggestions(buffer, cursor)
    end

    test "succeeds when using schema with many_to_many assoc" do
      buffer = """
      import Ecto.Query
      alias ElixirLS.LanguageServer.Plugins.Ecto.FakeSchemas.Post

      def query() do
        from p in Post, se
          #               ^
      end
      """

      [cursor] = cursors(buffer)

      assert [%{label: "select"}, %{label: "select_merge"}] = suggestions(buffer, cursor)
    end
  end

  describe "suggestions for Ecto.Schema.field/3" do
    test "at arg 1, suggest built-in and custom ecto types" do
      buffer = """
      import Ecto.Schema
      field name,
      #          ^
      """

      [cursor] = cursors(buffer)
      result = suggestions(buffer, cursor)

      assert Enum.any?(result, &(&1.detail in ["Ecto type", "Ecto custom type"]))
    end

    test "at arg 2, suggest field options" do
      buffer = """
      import Ecto.Schema
      field :name, :string,
      #                     ^
      """

      [cursor] = cursors(buffer)
      result = suggestions(buffer, cursor)

      assert Enum.map(result, & &1.label) == [
               "autogenerate",
               "default",
               "load_in_query",
               "primary_key",
               "read_after_writes",
               "source",
               "virtual"
             ]
    end

    test "at arg 2, suggest fuzzy field options" do
      buffer = """
      import Ecto.Schema
      field :name, :string, deau
      #                         ^
      """

      [cursor] = cursors(buffer)
      result = suggestions(buffer, cursor)
      assert Enum.map(result, & &1.label) == ["default"]

      buffer = """
      import Ecto.Schema
      field :name, :string, pri_ke
      #                           ^
      """

      [cursor] = cursors(buffer)
      result = suggestions(buffer, cursor)
      assert Enum.map(result, & &1.label) == ["primary_key"]
    end
  end

  describe "suggestions for Ecto.Migration.add/3" do
    test "at arg 1, suggest built-in ecto types" do
      buffer = """
      import Ecto.Migration
      add :name,
      #         ^
      """

      [cursor] = cursors(buffer)
      result = suggestions(buffer, cursor)

      assert Enum.all?(result, &(&1.detail == "Ecto type"))
    end
  end

  describe "suggestions for Ecto.Schema.has_many/3" do
    test "at arg 1, suggest only ecto schemas" do
      buffer = """
      import Ecto.Schema
      has_many :posts,
      #               ^
      """

      [cursor] = cursors(buffer)
      result = suggestions(buffer, cursor)

      assert Enum.all?(result, &(&1.detail == "Ecto schema"))
    end

    test "at arg 2, suggest has_many options" do
      buffer = """
      import Ecto.Schema
      has_many :posts, Post,
      #                     ^
      """

      [cursor] = cursors(buffer)
      [first_suggestion | _] = result = suggestions(buffer, cursor)

      assert Enum.map(result, & &1.label) == [
               "defaults",
               "foreign_key",
               "on_delete",
               "on_replace",
               "references",
               "through",
               "where"
             ]

      assert first_suggestion == %{
               detail: "has_many option",
               documentation: """
               Default values to use when building the association.
               It may be a keyword list of options that override the association schema
               or a `{module, function, args}` that receive the struct and the owner as
               arguments. For example, if you set `Post.has_many :comments, defaults: [public: true]`,
               then when using `Ecto.build_assoc(post, :comments)` that comment will have
               `comment.public == true`. Alternatively, you can set it to
               `Post.has_many :comments, defaults: {__MODULE__, :update_comment, []}`
               and `Post.update_comment(comment, post)` will be invoked.
               """,
               insert_text: "defaults: ",
               kind: :property,
               label: "defaults",
               snippet: nil,
               command: nil,
               type: :generic
             }
    end

    test "at arg 2, on option :on_replace, suggest possible values" do
      buffer = """
      import Ecto.Schema

      has_many :posts, Post, on_replace: #
      #                                  ^
      """

      [cursor] = cursors(buffer)
      [_first_suggestion | _] = result = suggestions(buffer, cursor)

      assert Enum.map(result, & &1.label) == [
               ":raise",
               ":mark_as_invalid",
               ":nilify",
               ":update",
               ":delete"
             ]

      buffer = """
      import Ecto.Schema

      has_many :posts, Post, on_replace: :rais #
      #                                       ^
      """

      [cursor] = cursors(buffer)

      assert [
               %{
                 detail: ":on_replace value",
                 insert_text: "raise",
                 kind: :enum_member,
                 label: ":raise",
                 type: :generic,
                 documentation: """
                 (default) - do not allow removing association or embedded
                 data via parent changesets
                 """
               }
             ] == suggestions(buffer, cursor)
    end
  end

  describe "suggestions for Ecto.Schema.has_one/3" do
    test "at arg 1, suggest only ecto schemas" do
      buffer = """
      import Ecto.Schema
      has_one :post,
      #              ^
      """

      [cursor] = cursors(buffer)
      result = suggestions(buffer, cursor)

      assert Enum.all?(result, &(&1.detail == "Ecto schema"))
    end

    test "at arg 2, suggest has_one options" do
      buffer = """
      import Ecto.Schema
      has_one :post, Post,
      #                    ^
      """

      [cursor] = cursors(buffer)
      result = suggestions(buffer, cursor)

      assert Enum.map(result, & &1.label) == [
               "defaults",
               "foreign_key",
               "on_delete",
               "on_replace",
               "references",
               "through",
               "where"
             ]
    end
  end

  describe "suggestions for Ecto.Schema.belongs_to/3" do
    test "at arg 1, suggest only ecto schemas" do
      buffer = """
      import Ecto.Schema
      belongs_to :post,
      #                 ^
      """

      [cursor] = cursors(buffer)
      result = suggestions(buffer, cursor)

      assert Enum.all?(result, &(&1.detail == "Ecto schema"))
    end

    test "at arg 2, suggest belongs_to options" do
      buffer = """
      import Ecto.Schema
      belongs_to :post, Post,
      #                       ^
      """

      [cursor] = cursors(buffer)
      result = suggestions(buffer, cursor)

      assert Enum.map(result, & &1.label) == [
               "defaults",
               "define_field",
               "foreign_key",
               "on_replace",
               "primary_key",
               "references",
               "source",
               "type",
               "where"
             ]
    end
  end

  describe "suggestions for Ecto.Schema.many_to_many/3" do
    test "at arg 1, suggest only ecto schemas" do
      buffer = """
      import Ecto.Schema
      many_to_many :post,
      #                   ^
      """

      [cursor] = cursors(buffer)
      result = suggestions(buffer, cursor)

      assert Enum.all?(result, &(&1.detail == "Ecto schema"))
    end

    test "at arg 2, suggest many_to_many options" do
      buffer = """
      import Ecto.Schema
      many_to_many :post, Post,
      #                         ^
      """

      [cursor] = cursors(buffer)
      result = suggestions(buffer, cursor)

      assert Enum.map(result, & &1.label) == [
               "defaults",
               "join_defaults",
               "join_keys",
               "join_through",
               "join_where",
               "on_delete",
               "on_replace",
               "unique",
               "where"
             ]
    end
  end
end
