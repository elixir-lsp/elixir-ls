defmodule Ecto.Query do
  @moduledoc ~S"""
  Fake Query module.
  """

  @doc """
  Creates a query.
  """
  defmacro from(expr, kw \\ []) do
    quote do
      {unquote(expr), unquote(kw)}
    end
  end

  @doc """
  A select query expression.

  Selects which fields will be selected from the schema and any transformations
  that should be performed on the fields. Any expression that is accepted in a
  query can be a select field.

  ## Keywords examples

      from(c in City, select: c) # returns the schema as a struct
      from(c in City, select: {c.name, c.population})
      from(c in City, select: [c.name, c.county])

  It is also possible to select a struct and limit the returned
  fields at the same time:

      from(City, select: [:name])

  The syntax above is equivalent to:

      from(city in City, select: struct(city, [:name]))

  ## Expressions examples

      City |> select([c], c)
      City |> select([c], {c.name, c.country})
      City |> select([c], %{"name" => c.name})

  """
  defmacro select(query, binding \\ [], expr) do
    quote do
      {unquote(query), unquote(binding), unquote(expr)}
    end
  end

  @doc """
  Mergeable select query expression.

  This macro is similar to `select/3` except it may be specified
  multiple times as long as every entry is a map. This is useful
  for merging and composing selects. For example:

      query = from p in Post, select: %{}

      query =
        if include_title? do
          from p in query, select_merge: %{title: p.title}
        else
          query
        end

      query =
        if include_visits? do
          from p in query, select_merge: %{visits: p.visits}
        else
          query
        end

  In the example above, the query is built little by little by merging
  into a final map. If both conditions above are true, the final query
  would be equivalent to:

      from p in Post, select: %{title: p.title, visits: p.visits}

  If `:select_merge` is called and there is no value selected previously,
  it will default to the source, `p` in the example above.
  """
  defmacro select_merge(query, binding \\ [], expr) do
    quote do
      {unquote(query), unquote(binding), unquote(expr)}
    end
  end

  @doc """
  A distinct query expression.

  When true, only keeps distinct values from the resulting
  select expression.

  ## Keywords examples

      # Returns the list of different categories in the Post schema
      from(p in Post, distinct: true, select: p.category)

      # If your database supports DISTINCT ON(),
      # you can pass expressions to distinct too
      from(p in Post,
         distinct: p.category,
         order_by: [p.date])

      # The DISTINCT ON() also supports ordering similar to ORDER BY.
      from(p in Post,
         distinct: [desc: p.category],
         order_by: [p.date])

      # Using atoms
      from(p in Post, distinct: :category, order_by: :date)

  ## Expressions example

      Post
      |> distinct(true)
      |> order_by([p], [p.category, p.author])

  """
  defmacro distinct(query, binding \\ [], expr) do
    quote do
      {unquote(query), unquote(binding), unquote(expr)}
    end
  end
end
