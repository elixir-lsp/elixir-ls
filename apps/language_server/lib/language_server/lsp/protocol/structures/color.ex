# codegen: do not edit
defmodule GenLSP.Structures.Color do
  @moduledoc """
  Represents a color in RGBA space.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * red: The red component of this color in the range [0-1].
  * green: The green component of this color in the range [0-1].
  * blue: The blue component of this color in the range [0-1].
  * alpha: The alpha component of this color in the range [0-1].
  """

  typedstruct do
    field(:red, float(), enforce: true)
    field(:green, float(), enforce: true)
    field(:blue, float(), enforce: true)
    field(:alpha, float(), enforce: true)
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      {"red", :red} => str(),
      {"green", :green} => str(),
      {"blue", :blue} => str(),
      {"alpha", :alpha} => str()
    })
  end
end
