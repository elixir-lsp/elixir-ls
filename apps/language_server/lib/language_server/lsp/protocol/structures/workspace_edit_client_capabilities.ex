# codegen: do not edit
defmodule GenLSP.Structures.WorkspaceEditClientCapabilities do
  import SchematicV, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * document_changes: The client supports versioned document changes in `WorkspaceEdit`s
  * resource_operations: The resource operations the client supports. Clients should at least
    support 'create', 'rename' and 'delete' files and folders.

    @since 3.13.0
  * failure_handling: The failure handling strategy of a client if applying the workspace edit
    fails.

    @since 3.13.0
  * normalizes_line_endings: Whether the client normalizes line endings to the client specific
    setting.
    If set to `true` the client will normalize line ending characters
    in a workspace edit to the client-specified new line
    character.

    @since 3.16.0
  * change_annotation_support: Whether the client in general supports change annotations on text edits,
    create file, rename file and delete file changes.

    @since 3.16.0
  """

  typedstruct do
    field(:document_changes, boolean())
    field(:resource_operations, list(GenLSP.Enumerations.ResourceOperationKind.t()))
    field(:failure_handling, GenLSP.Enumerations.FailureHandlingKind.t())
    field(:normalizes_line_endings, boolean())
    field(:change_annotation_support, map())
  end

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    schema(__MODULE__, %{
      optional({"documentChanges", :document_changes}) => bool(),
      optional({"resourceOperations", :resource_operations}) =>
        list(GenLSP.Enumerations.ResourceOperationKind.schematic()),
      optional({"failureHandling", :failure_handling}) =>
        GenLSP.Enumerations.FailureHandlingKind.schematic(),
      optional({"normalizesLineEndings", :normalizes_line_endings}) => bool(),
      optional({"changeAnnotationSupport", :change_annotation_support}) =>
        map(%{
          optional({"groupsOnLabel", :groups_on_label}) => bool()
        })
    })
  end
end
