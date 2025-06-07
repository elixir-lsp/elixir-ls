# codegen: do not edit
defmodule GenLSP.Structures.CodeActionContext do
  @moduledoc """
  Contains additional diagnostic information about the context in which
  a {@link CodeActionProvider.provideCodeActions code action} is run.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * diagnostics: An array of diagnostics known on the client side overlapping the range provided to the
    `textDocument/codeAction` request. They are provided so that the server knows which
    errors are currently presented to the user for the given range. There is no guarantee
    that these accurately reflect the error state of the resource. The primary parameter
    to compute code actions is the provided range.
  * only: Requested kind of actions to return.

    Actions not of this kind are filtered out by the client before being shown. So servers
    can omit computing them.
  * trigger_kind: The reason why code actions were requested.

    @since 3.17.0
  """
  
  typedstruct do
    field :diagnostics, list(GenLSP.Structures.Diagnostic.t()), enforce: true
    field :only, list(GenLSP.Enumerations.CodeActionKind.t())
    field :trigger_kind, GenLSP.Enumerations.CodeActionTriggerKind.t()
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      {"diagnostics", :diagnostics} => list(GenLSP.Structures.Diagnostic.schematic()),
      optional({"only", :only}) => list(GenLSP.Enumerations.CodeActionKind.schematic()),
      optional({"triggerKind", :trigger_kind}) =>
        GenLSP.Enumerations.CodeActionTriggerKind.schematic()
    })
  end
end
