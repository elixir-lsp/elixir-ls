defmodule Ecto.Schema do
  @moduledoc ~S"""
  Fake Schema module.
  """

  @doc """
  Defines a field on the schema with given name and type.
  """
  defmacro field(name, type \\ :string, opts \\ []) do
    {name, type, opts}
  end

  defmacro schema(source, do: block) do
    {source, block}
  end

  defmacro has_many(name, queryable, opts \\ []) do
    {name, queryable, opts}
  end

  defmacro has_one(name, queryable, opts \\ []) do
    {name, queryable, opts}
  end

  defmacro belongs_to(name, queryable, opts \\ []) do
    {name, queryable, opts}
  end

  defmacro many_to_many(name, queryable, opts \\ []) do
    {name, queryable, opts}
  end
end
