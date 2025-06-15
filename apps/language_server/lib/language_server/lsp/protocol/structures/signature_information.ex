# codegen: do not edit
defmodule GenLSP.Structures.SignatureInformation do
  @moduledoc """
  Represents the signature of something callable. A signature
  can have a label, like a function-name, a doc-comment, and
  a set of parameters.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * label: The label of this signature. Will be shown in
    the UI.
  * documentation: The human-readable doc-comment of this signature. Will be shown
    in the UI but can be omitted.
  * parameters: The parameters of this signature.
  * active_parameter: The index of the active parameter.

    If provided, this is used in place of `SignatureHelp.activeParameter`.

    @since 3.16.0
  """

  typedstruct do
    field(:label, String.t(), enforce: true)
    field(:documentation, String.t() | GenLSP.Structures.MarkupContent.t())
    field(:parameters, list(GenLSP.Structures.ParameterInformation.t()))
    field(:active_parameter, GenLSP.BaseTypes.uinteger())
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      {"label", :label} => str(),
      optional({"documentation", :documentation}) =>
        oneof([str(), GenLSP.Structures.MarkupContent.schematic()]),
      optional({"parameters", :parameters}) =>
        list(GenLSP.Structures.ParameterInformation.schematic()),
      optional({"activeParameter", :active_parameter}) => int()
    })
  end
end
