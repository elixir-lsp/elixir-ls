defmodule ElixirLS.LanguageServer.Experimental.Protocol.Proto.TypeFunctions do
  def integer do
    :integer
  end

  def float do
    :float
  end

  def string do
    :string
  end

  def boolean do
    :boolean
  end

  def uri do
    :string
  end

  def type_alias(alias_module) do
    {:type_alias, alias_module}
  end

  def literal(what) do
    {:literal, what}
  end

  def list_of(type) do
    {:list, type}
  end

  def map_of(type, opts \\ []) do
    field_name = Keyword.get(opts, :as)
    {:map, type, field_name}
  end

  def one_of(options) when is_list(options) do
    {:one_of, options}
  end

  def optional(type) do
    {:optional, type}
  end

  def params(opts) do
    {:params, opts}
  end

  def any do
    :any
  end
end
