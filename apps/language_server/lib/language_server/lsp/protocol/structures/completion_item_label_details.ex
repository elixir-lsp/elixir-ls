# codegen: do not edit
defmodule GenLSP.Structures.CompletionItemLabelDetails do
  @moduledoc """
  Additional details for a completion item label.

  @since 3.17.0
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * detail: An optional string which is rendered less prominently directly after {@link CompletionItem.label label},
    without any spacing. Should be used for function signatures and type annotations.
  * description: An optional string which is rendered less prominently after {@link CompletionItem.detail}. Should be used
    for fully qualified names and file paths.
  """

  typedstruct do
    field(:detail, String.t())
    field(:description, String.t())
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      optional({"detail", :detail}) => str(),
      optional({"description", :description}) => str()
    })
  end
end
