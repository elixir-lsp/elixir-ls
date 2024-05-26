defmodule ElixirLS.LanguageServer.Plugins.Ecto.Schema do
  @moduledoc false

  alias ElixirSense.Core.Introspection
  alias ElixirLS.LanguageServer.Plugins.Option
  alias ElixirLS.LanguageServer.Plugins.Util
  alias ElixirLS.Utils.Matcher

  # We'll keep these values hard-coded until Ecto provides the same information
  # using docs' metadata.

  @on_replace_values [
    raise: """
    (default) - do not allow removing association or embedded
    data via parent changesets
    """,
    mark_as_invalid: """
    If attempting to remove the association or
    embedded data via parent changeset - an error will be added to the parent
    changeset, and it will be marked as invalid
    """,
    nilify: """
    Sets owner reference column to `nil` (available only for
    associations). Use this on a `belongs_to` column to allow the association
    to be cleared out so that it can be set to a new value. Will set `action`
    on associated changesets to `:replace`
    """,
    update: """
    Updates the association, available only for `has_one` and `belongs_to`.
    This option will update all the fields given to the changeset including the id
    for the association
    """,
    delete: """
    Removes the association or related data from the database.
    This option has to be used carefully (see below). Will set `action` on associated
    changesets to `:replace`
    """
  ]

  @on_delete_values [
    nothing: "(default) - do nothing to the associated records when the parent record is deleted",
    nilify_all: "Sets the key in the associated table to `nil`",
    delete_all: "Deletes the associated records when the parent record is deleted"
  ]

  @options %{
    field: [
      %{
        name: :default,
        doc: """
        Sets the default value on the schema and the struct.
        The default value is calculated at compilation time, so don't use
        expressions like `DateTime.utc_now` or `Ecto.UUID.generate` as
        they would then be the same for all records.
        """
      },
      %{
        name: :source,
        doc: """
        Defines the name that is to be used in database for this field.
        This is useful when attaching to an existing database. The value should be
        an atom.
        """
      },
      %{
        name: :autogenerate,
        doc: """
        a `{module, function, args}` tuple for a function
        to call to generate the field value before insertion if value is not set.
        A shorthand value of `true` is equivalent to `{type, :autogenerate, []}`.
        """
      },
      %{
        name: :read_after_writes,
        doc: """
        When true, the field is always read back
        from the database after insert and updates.
        For relational databases, this means the RETURNING option of those
        statements is used. For this reason, MySQL does not support this
        option and will raise an error if a schema is inserted/updated with
        read after writes fields.
        """
      },
      %{
        name: :virtual,
        doc: """
        When true, the field is not persisted to the database.
        Notice virtual fields do not support `:autogenerate` nor
        `:read_after_writes`.
        """
      },
      %{
        name: :primary_key,
        doc: """
        When true, the field is used as part of the
        composite primary key.
        """
      },
      %{
        name: :load_in_query,
        doc: """
        When false, the field will not be loaded when
        selecting the whole struct in a query, such as `from p in Post, select: p`.
        Defaults to `true`.
        """
      }
    ],
    belongs_to: [
      %{
        name: :foreign_key,
        doc: """
        Sets the foreign key field name, defaults to the name
        of the association suffixed by `_id`. For example, `belongs_to :company`
        will define foreign key of `:company_id`. The associated `has_one` or `has_many`
        field in the other schema should also have its `:foreign_key` option set
        with the same value.
        """
      },
      %{
        name: :references,
        doc: """
        Sets the key on the other schema to be used for the
        association, defaults to: `:id`
        """
      },
      %{
        name: :define_field,
        doc: """
        When false, does not automatically define a `:foreign_key`
        field, implying the user is defining the field manually elsewhere
        """
      },
      %{
        name: :type,
        doc: """
        Sets the type of automatically defined `:foreign_key`.
        Defaults to: `:integer` and can be set per schema via `@foreign_key_type`
        """
      },
      %{
        name: :on_replace,
        doc: """
        The action taken on associations when the record is
        replaced when casting or manipulating parent changeset. May be
        `:raise` (default), `:mark_as_invalid`, `:nilify`, `:update`, or `:delete`.
        See `Ecto.Changeset`'s section on related data for more info.
        """,
        values: @on_replace_values
      },
      %{
        name: :defaults,
        doc: """
        Default values to use when building the association.
        It may be a keyword list of options that override the association schema
        or a `{module, function, args}` that receive the struct and the owner as
        arguments. For example, if you set `Post.has_many :comments, defaults: [public: true]`,
        then when using `Ecto.build_assoc(post, :comments)` that comment will have
        `comment.public == true`. Alternatively, you can set it to
        `Post.has_many :comments, defaults: {__MODULE__, :update_comment, []}`
        and `Post.update_comment(comment, post)` will be invoked.
        """
      },
      %{
        name: :primary_key,
        doc: """
        If the underlying belongs_to field is a primary key
        """
      },
      %{
        name: :source,
        doc: """
        Defines the name that is to be used in database for this field
        """
      },
      %{
        name: :where,
        doc: """
        A filter for the association. See "Filtering associations"
        in `has_many/3`.
        """
      }
    ],
    has_one: [
      %{
        name: :foreign_key,
        doc: """
        Sets the foreign key, this should map to a field on the
        other schema, defaults to the underscored name of the current module
        suffixed by `_id`
        """
      },
      %{
        name: :references,
        doc: """
        Sets the key on the current schema to be used for the
        association, defaults to the primary key on the schema
        """
      },
      %{
        name: :through,
        doc: """
        If this association must be defined in terms of existing
        associations. Read the section in `has_many/3` for more information
        """
      },
      %{
        name: :on_delete,
        doc: """
        The action taken on associations when parent record
        is deleted. May be `:nothing` (default), `:nilify_all` and `:delete_all`.
        Using this option is DISCOURAGED for most relational databases. Instead,
        in your migration, set `references(:parent_id, on_delete: :delete_all)`.
        Opposite to the migration option, this option cannot guarantee integrity
        and it is only triggered for `c:Ecto.Repo.delete/2` (and not on
        `c:Ecto.Repo.delete_all/2`) and it never cascades. If posts has many comments,
        which has many tags, and you delete a post, only comments will be deleted.
        If your database does not support references, cascading can be manually
        implemented by using `Ecto.Multi` or `Ecto.Changeset.prepare_changes/2`
        """,
        values: @on_delete_values
      },
      %{
        name: :on_replace,
        doc: """
        The action taken on associations when the record is
        replaced when casting or manipulating parent changeset. May be
        `:raise` (default), `:mark_as_invalid`, `:nilify`, `:update`, or
        `:delete`. See `Ecto.Changeset`'s section on related data for more info.
        """,
        values: @on_replace_values
      },
      %{
        name: :defaults,
        doc: """
        Default values to use when building the association.
        It may be a keyword list of options that override the association schema
        or a `{module, function, args}` that receive the struct and the owner as
        arguments. For example, if you set `Post.has_many :comments, defaults: [public: true]`,
        then when using `Ecto.build_assoc(post, :comments)` that comment will have
        `comment.public == true`. Alternatively, you can set it to
        `Post.has_many :comments, defaults: {__MODULE__, :update_comment, []}`
        and `Post.update_comment(comment, post)` will be invoked.
        """
      },
      %{
        name: :where,
        doc: """
        A filter for the association. See "Filtering associations"
        in `has_many/3`. It does not apply to `:through` associations.
        """
      }
    ],
    has_many: [
      %{
        name: :foreign_key,
        doc: """
        Sets the foreign key, this should map to a field on the
        other schema, defaults to the underscored name of the current module
        suffixed by `_id`.
        """
      },
      %{
        name: :references,
        doc: """
        Sets the key on the current schema to be used for the
        association, defaults to the primary key on the schema.
        """
      },
      %{
        name: :through,
        doc: """
        If this association must be defined in terms of existing
        associations. Read the section in `has_many/3` for more information.
        """
      },
      %{
        name: :on_delete,
        doc: """
        The action taken on associations when parent record
        is deleted. May be `:nothing` (default), `:nilify_all` and `:delete_all`.
        Using this option is DISCOURAGED for most relational databases. Instead,
        in your migration, set `references(:parent_id, on_delete: :delete_all)`.
        Opposite to the migration option, this option cannot guarantee integrity
        and it is only triggered for `c:Ecto.Repo.delete/2` (and not on
        `c:Ecto.Repo.delete_all/2`) and it never cascades. If posts has many comments,
        which has many tags, and you delete a post, only comments will be deleted.
        If your database does not support references, cascading can be manually
        implemented by using `Ecto.Multi` or `Ecto.Changeset.prepare_changes/2`.
        """,
        values: @on_delete_values
      },
      %{
        name: :on_replace,
        doc: """
        The action taken on associations when the record is
        replaced when casting or manipulating parent changeset. May be
        `:raise` (default), `:mark_as_invalid`, `:nilify`, `:update`, or
        `:delete`. See `Ecto.Changeset`'s section on related data for more info.
        """,
        values: @on_replace_values
      },
      %{
        name: :defaults,
        doc: """
        Default values to use when building the association.
        It may be a keyword list of options that override the association schema
        or a `{module, function, args}` that receive the struct and the owner as
        arguments. For example, if you set `Post.has_many :comments, defaults: [public: true]`,
        then when using `Ecto.build_assoc(post, :comments)` that comment will have
        `comment.public == true`. Alternatively, you can set it to
        `Post.has_many :comments, defaults: {__MODULE__, :update_comment, []}`
        and `Post.update_comment(comment, post)` will be invoked.
        """
      },
      %{
        name: :where,
        doc: """
        A filter for the association. See "Filtering associations"
        in `has_many/3`. It does not apply to `:through` associations.
        """
      }
    ],
    many_to_many: [
      %{
        name: :join_through,
        doc: """
        Specifies the source of the associated data.
        It may be a string, like "posts_tags", representing the
        underlying storage table or an atom, like `MyApp.PostTag`,
        representing a schema. This option is required.
        """
      },
      %{
        name: :join_keys,
        doc: """
        Specifies how the schemas are associated. It
        expects a keyword list with two entries, the first being how
        the join table should reach the current schema and the second
        how the join table should reach the associated schema. In the
        example above, it defaults to: `[post_id: :id, tag_id: :id]`.
        The keys are inflected from the schema names.
        """
      },
      %{
        name: :on_delete,
        doc: """
        The action taken on associations when the parent record
        is deleted. May be `:nothing` (default) or `:delete_all`.
        Using this option is DISCOURAGED for most relational databases. Instead,
        in your migration, set `references(:parent_id, on_delete: :delete_all)`.
        Opposite to the migration option, this option cannot guarantee integrity
        and it is only triggered for `c:Ecto.Repo.delete/2` (and not on
        `c:Ecto.Repo.delete_all/2`). This option can only remove data from the
        join source, never the associated records, and it never cascades.
        """,
        values: Keyword.take(@on_delete_values, [:nothing, :delete_all])
      },
      %{
        name: :on_replace,
        doc: """
        The action taken on associations when the record is
        replaced when casting or manipulating parent changeset. May be
        `:raise` (default), `:mark_as_invalid`, or `:delete`.
        `:delete` will only remove data from the join source, never the
        associated records. See `Ecto.Changeset`'s section on related data
        for more info.
        """,
        values: Keyword.take(@on_replace_values, [:raise, :mark_as_invalid, :delete])
      },
      %{
        name: :defaults,
        doc: """
        Default values to use when building the association.
        It may be a keyword list of options that override the association schema
        or a `{module, function, args}` that receive the struct and the owner as
        arguments. For example, if you set `Post.has_many :comments, defaults: [public: true]`,
        then when using `Ecto.build_assoc(post, :comments)` that comment will have
        `comment.public == true`. Alternatively, you can set it to
        `Post.has_many :comments, defaults: {__MODULE__, :update_comment, []}`
        and `Post.update_comment(comment, post)` will be invoked.
        """
      },
      %{
        name: :join_defaults,
        doc: """
        The same as `:defaults` but it applies to the join schema
        instead. This option will raise if it is given and the `:join_through` value
        is not a schema.
        """
      },
      %{
        name: :unique,
        doc: """
        When true, checks if the associated entries are unique
        whenever the association is cast or changed via the parent record.
        For instance, it would verify that a given tag cannot be attached to
        the same post more than once. This exists mostly as a quick check
        for user feedback, as it does not guarantee uniqueness at the database
        level. Therefore, you should also set a unique index in the database
        join table, such as: `create unique_index(:posts_tags, [:post_id, :tag_id])`
        """
      },
      %{
        name: :where,
        doc: """
        A filter for the association. See "Filtering associations"
        in `has_many/3`
        """
      },
      %{
        name: :join_where,
        doc: """
        A filter for the join table. See "Filtering associations"
        in `has_many/3`
        """
      }
    ]
  }

  def find_options(hint, fun) do
    @options[fun] |> Option.find(hint, fun)
  end

  def find_option_values(hint, option, fun) do
    for {value, doc} <- Enum.find(@options[fun], &(&1.name == option))[:values] || [],
        value_str = inspect(value),
        Matcher.match?(value_str, hint) do
      %{
        type: :generic,
        kind: :enum_member,
        label: value_str,
        insert_text: Util.trim_leading_for_insertion(hint, value_str),
        detail: "#{inspect(option)} value",
        documentation: doc
      }
    end
  end

  def find_schemas(hint, module_store) do
    for module <- module_store.list,
        function_exported?(module, :__schema__, 1),
        mod_str = inspect(module),
        Util.match_module?(mod_str, hint) do
      {doc, _} = Introspection.get_module_docs_summary(module)

      %{
        type: :generic,
        kind: :class,
        label: mod_str,
        insert_text: Util.trim_leading_for_insertion(hint, mod_str),
        detail: "Ecto schema",
        documentation: doc
      }
    end
    |> Enum.sort_by(& &1.label)
  end
end
