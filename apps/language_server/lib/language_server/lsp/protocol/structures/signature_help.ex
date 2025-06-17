# codegen: do not edit
defmodule GenLSP.Structures.SignatureHelp do
  @moduledoc """
  Signature help represents the signature of something
  callable. There can be multiple signature but only one
  active and only one active parameter.
  """

  import SchematicV, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * signatures: One or more signatures.
  * active_signature: The active signature. If omitted or the value lies outside the
    range of `signatures` the value defaults to zero or is ignored if
    the `SignatureHelp` has no signatures.

    Whenever possible implementors should make an active decision about
    the active signature and shouldn't rely on a default value.

    In future version of the protocol this property might become
    mandatory to better express this.
  * active_parameter: The active parameter of the active signature. If omitted or the value
    lies outside the range of `signatures[activeSignature].parameters`
    defaults to 0 if the active signature has parameters. If
    the active signature has no parameters it is ignored.
    In future version of the protocol this property might become
    mandatory to better express the active parameter if the
    active signature does have any.
  """

  typedstruct do
    field(:signatures, list(GenLSP.Structures.SignatureInformation.t()), enforce: true)
    field(:active_signature, GenLSP.BaseTypes.uinteger())
    field(:active_parameter, GenLSP.BaseTypes.uinteger())
  end

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    schema(__MODULE__, %{
      {"signatures", :signatures} => list(GenLSP.Structures.SignatureInformation.schematic()),
      optional({"activeSignature", :active_signature}) => int(),
      optional({"activeParameter", :active_parameter}) => int()
    })
  end
end
