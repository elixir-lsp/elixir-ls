# codegen: do not edit
defmodule GenLSP.Structures.RenameClientCapabilities do
  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * dynamic_registration: Whether rename supports dynamic registration.
  * prepare_support: Client supports testing for validity of rename operations
    before execution.

    @since 3.12.0
  * prepare_support_default_behavior: Client supports the default behavior result.

    The value indicates the default behavior used by the
    client.

    @since 3.16.0
  * honors_change_annotations: Whether the client honors the change annotations in
    text edits and resource operations returned via the
    rename request's workspace edit by for example presenting
    the workspace edit in the user interface and asking
    for confirmation.

    @since 3.16.0
  """

  typedstruct do
    field(:dynamic_registration, boolean())
    field(:prepare_support, boolean())

    field(
      :prepare_support_default_behavior,
      GenLSP.Enumerations.PrepareSupportDefaultBehavior.t()
    )

    field(:honors_change_annotations, boolean())
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      optional({"dynamicRegistration", :dynamic_registration}) => bool(),
      optional({"prepareSupport", :prepare_support}) => bool(),
      optional({"prepareSupportDefaultBehavior", :prepare_support_default_behavior}) =>
        GenLSP.Enumerations.PrepareSupportDefaultBehavior.schematic(),
      optional({"honorsChangeAnnotations", :honors_change_annotations}) => bool()
    })
  end
end
