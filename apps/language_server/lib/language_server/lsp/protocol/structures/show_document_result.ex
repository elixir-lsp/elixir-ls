# codegen: do not edit
defmodule GenLSP.Structures.ShowDocumentResult do
  @moduledoc """
  The result of a showDocument request.

  @since 3.16.0
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * success: A boolean indicating if the show was successful.
  """

  typedstruct do
    field(:success, boolean(), enforce: true)
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      {"success", :success} => bool()
    })
  end
end
