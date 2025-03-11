# codegen: do not edit
defmodule GenDAP.Structures.Checksum do
  @moduledoc """
  The checksum of an item calculated by the specified algorithm.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields
  
  * checksum: Value of the checksum, encoded as a hexadecimal value.
  * algorithm: The algorithm used to calculate this checksum.
  """
  @derive JasonV.Encoder
  typedstruct do
    field :checksum, String.t(), enforce: true
    field :algorithm, GenDAP.Enumerations.ChecksumAlgorithm.t(), enforce: true
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      {"checksum", :checksum} => str(),
      {"algorithm", :algorithm} => GenDAP.Enumerations.ChecksumAlgorithm.schematic(),
    })
  end
end
