defmodule Ecto.Type do
  @moduledoc """
  Fake Ecto.Type
  """

  @callback fake :: true
end

defmodule Ecto.UUID do
  @moduledoc """
  Fake Ecto.UUID
  """

  @behaviour Ecto.Type

  def fake() do
    true
  end
end
