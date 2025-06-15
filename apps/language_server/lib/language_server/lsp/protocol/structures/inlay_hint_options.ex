# codegen: do not edit
defmodule GenLSP.Structures.InlayHintOptions do
  @moduledoc """
  Inlay hint options used during static registration.

  @since 3.17.0
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * resolve_provider: The server provides support to resolve additional
    information for an inlay hint item.
  * work_done_progress
  """

  typedstruct do
    field(:resolve_provider, boolean())
    field(:work_done_progress, boolean())
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      optional({"resolveProvider", :resolve_provider}) => bool(),
      optional({"workDoneProgress", :work_done_progress}) => bool()
    })
  end
end
