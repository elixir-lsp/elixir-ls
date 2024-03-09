defmodule Ecto.Migration do
  @moduledoc ~S"""
  Fake Migration module.
  """

  @doc """
  Defines a field on the schema with given name and type.
  """
  def add(column, type, opts \\ []) when is_atom(column) and is_list(opts) do
    {column, type, opts}
  end
end
