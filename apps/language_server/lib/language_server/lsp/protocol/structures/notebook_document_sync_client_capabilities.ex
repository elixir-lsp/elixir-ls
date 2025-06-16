# codegen: do not edit
defmodule GenLSP.Structures.NotebookDocumentSyncClientCapabilities do
  @moduledoc """
  Notebook specific client capabilities.

  @since 3.17.0
  """

  import SchematicV, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * dynamic_registration: Whether implementation supports dynamic registration. If this is
    set to `true` the client supports the new
    `(TextDocumentRegistrationOptions & StaticRegistrationOptions)`
    return value for the corresponding server capability as well.
  * execution_summary_support: The client supports sending execution summary data per cell.
  """

  typedstruct do
    field(:dynamic_registration, boolean())
    field(:execution_summary_support, boolean())
  end

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    schema(__MODULE__, %{
      optional({"dynamicRegistration", :dynamic_registration}) => bool(),
      optional({"executionSummarySupport", :execution_summary_support}) => bool()
    })
  end
end
