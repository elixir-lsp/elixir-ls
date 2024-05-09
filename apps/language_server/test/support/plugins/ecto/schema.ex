defmodule Ecto.Schema do
  @moduledoc ~S"""
  Fake Schema module.
  """

  @doc """
  Defines a field on the schema with given name and type.
  """
  defmacro field(name, type \\ :string, opts \\ []) do
    quote do
      {unquote(name), unquote(type), unquote(opts)}
    end
  end

  defmacro schema(source, do: block) do
    quote do
      {unquote(source), unquote(block)}
    end
  end

  defmacro has_many(name, queryable, opts \\ []) do
    quote do
      {unquote(name), unquote(queryable), unquote(opts)}
    end
  end

  defmacro has_one(name, queryable, opts \\ []) do
    quote do
      {unquote(name), unquote(queryable), unquote(opts)}
    end
  end

  defmacro belongs_to(name, queryable, opts \\ []) do
    quote do
      {unquote(name), unquote(queryable), unquote(opts)}
    end
  end

  defmacro many_to_many(name, queryable, opts \\ []) do
    quote do
      {unquote(name), unquote(queryable), unquote(opts)}
    end
  end
end
