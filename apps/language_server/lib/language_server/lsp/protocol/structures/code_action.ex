# codegen: do not edit
defmodule GenLSP.Structures.CodeAction do
  @moduledoc """
  A code action represents a change that can be performed in code, e.g. to fix a problem or
  to refactor code.

  A CodeAction must set either `edit` and/or a `command`. If both are supplied, the `edit` is applied first, then the `command` is executed.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * title: A short, human-readable, title for this code action.
  * kind: The kind of the code action.

    Used to filter code actions.
  * diagnostics: The diagnostics that this code action resolves.
  * is_preferred: Marks this as a preferred action. Preferred actions are used by the `auto fix` command and can be targeted
    by keybindings.

    A quick fix should be marked preferred if it properly addresses the underlying error.
    A refactoring should be marked preferred if it is the most reasonable choice of actions to take.

    @since 3.15.0
  * disabled: Marks that the code action cannot currently be applied.

    Clients should follow the following guidelines regarding disabled code actions:

      - Disabled code actions are not shown in automatic [lightbulbs](https://code.visualstudio.com/docs/editor/editingevolved#_code-action)
        code action menus.

      - Disabled actions are shown as faded out in the code action menu when the user requests a more specific type
        of code action, such as refactorings.

      - If the user has a [keybinding](https://code.visualstudio.com/docs/editor/refactoring#_keybindings-for-code-actions)
        that auto applies a code action and only disabled code actions are returned, the client should show the user an
        error message with `reason` in the editor.

    @since 3.16.0
  * edit: The workspace edit this code action performs.
  * command: A command this code action executes. If a code action
    provides an edit and a command, first the edit is
    executed and then the command.
  * data: A data entry field that is preserved on a code action between
    a `textDocument/codeAction` and a `codeAction/resolve` request.

    @since 3.16.0
  """
  
  typedstruct do
    field :title, String.t(), enforce: true
    field :kind, GenLSP.Enumerations.CodeActionKind.t()
    field :diagnostics, list(GenLSP.Structures.Diagnostic.t())
    field :is_preferred, boolean()
    field :disabled, map()
    field :edit, GenLSP.Structures.WorkspaceEdit.t()
    field :command, GenLSP.Structures.Command.t()
    field :data, GenLSP.TypeAlias.LSPAny.t()
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      {"title", :title} => str(),
      optional({"kind", :kind}) => GenLSP.Enumerations.CodeActionKind.schematic(),
      optional({"diagnostics", :diagnostics}) => list(GenLSP.Structures.Diagnostic.schematic()),
      optional({"isPreferred", :is_preferred}) => bool(),
      optional({"disabled", :disabled}) =>
        map(%{
          {"reason", :reason} => str()
        }),
      optional({"edit", :edit}) => GenLSP.Structures.WorkspaceEdit.schematic(),
      optional({"command", :command}) => GenLSP.Structures.Command.schematic(),
      optional({"data", :data}) => GenLSP.TypeAlias.LSPAny.schematic()
    })
  end
end
