# codegen: do not edit
defmodule GenDAP.Structures.Checksum do
  @moduledoc """
  The checksum of an item calculated by the specified algorithm.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields
  
  * algorithm: The algorithm used to calculate this checksum.
  * checksum: Value of the checksum, encoded as a hexadecimal value.
  """
  @derive JasonV.Encoder
  typedstruct do
    @typedoc "A type defining DAP structure Checksum"
    field :algorithm, GenDAP.Enumerations.ChecksumAlgorithm.t(), enforce: true
    field :checksum, String.t(), enforce: true
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      {"algorithm", :algorithm} => GenDAP.Enumerations.ChecksumAlgorithm.schematic(),
      {"checksum", :checksum} => str(),
    })
  end
end
