# codegen: do not edit
defmodule GenLSP.Structures.InitializeError do
  @moduledoc """
  The data type of the ResponseError if the
  initialize request fails.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * retry: Indicates whether the client execute the following retry logic:
    (1) show the message provided by the ResponseError to the user
    (2) user selects retry or cancel
    (3) if user selected retry the initialize method is sent again.
  """

  typedstruct do
    field(:retry, boolean(), enforce: true)
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      {"retry", :retry} => bool()
    })
  end
end
