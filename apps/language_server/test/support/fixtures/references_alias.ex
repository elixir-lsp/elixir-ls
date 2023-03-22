defmodule ElixirLS.Test.ReferencesAlias do
  require ElixirLS.Test.ReferencesReferenced, as: ReferencesReferenced
  alias ElixirLS.Test.ReferencesReferenced, as: Some
  alias Some, as: Other

  def uses_alias_1 do
    ReferencesReferenced
  end

  def uses_alias_2 do
    Some
  end

  def uses_alias_3 do
    ElixirLS.Test.ReferencesReferenced
  end

  def uses_alias_4 do
    Other
  end
end
