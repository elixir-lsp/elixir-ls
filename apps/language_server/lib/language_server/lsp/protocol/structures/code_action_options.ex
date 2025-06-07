# codegen: do not edit
defmodule GenLSP.Structures.CodeActionOptions do
  @moduledoc """
  Provider options for a {@link CodeActionRequest}.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * code_action_kinds: CodeActionKinds that this server may return.

    The list of kinds may be generic, such as `CodeActionKind.Refactor`, or the server
    may list out every specific kind they provide.
  * resolve_provider: The server provides support to resolve additional
    information for a code action.

    @since 3.16.0
  * work_done_progress
  """
  
  typedstruct do
    field :code_action_kinds, list(GenLSP.Enumerations.CodeActionKind.t())
    field :resolve_provider, boolean()
    field :work_done_progress, boolean()
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      optional({"codeActionKinds", :code_action_kinds}) =>
        list(GenLSP.Enumerations.CodeActionKind.schematic()),
      optional({"resolveProvider", :resolve_provider}) => bool(),
      optional({"workDoneProgress", :work_done_progress}) => bool()
    })
  end
end
