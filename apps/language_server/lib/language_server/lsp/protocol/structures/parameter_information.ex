# codegen: do not edit
defmodule GenLSP.Structures.ParameterInformation do
  @moduledoc """
  Represents a parameter of a callable-signature. A parameter can
  have a label and a doc-comment.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * label: The label of this parameter information.

    Either a string or an inclusive start and exclusive end offsets within its containing
    signature label. (see SignatureInformation.label). The offsets are based on a UTF-16
    string representation as `Position` and `Range` does.

    *Note*: a label of type string should be a substring of its containing signature label.
    Its intended use case is to highlight the parameter label part in the `SignatureInformation.label`.
  * documentation: The human-readable doc-comment of this parameter. Will be shown
    in the UI but can be omitted.
  """

  typedstruct do
    field(:label, String.t() | {GenLSP.BaseTypes.uinteger(), GenLSP.BaseTypes.uinteger()},
      enforce: true
    )

    field(:documentation, String.t() | GenLSP.Structures.MarkupContent.t())
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      {"label", :label} => oneof([str(), tuple([int(), int()], from: :list)]),
      optional({"documentation", :documentation}) =>
        oneof([str(), GenLSP.Structures.MarkupContent.schematic()])
    })
  end
end
