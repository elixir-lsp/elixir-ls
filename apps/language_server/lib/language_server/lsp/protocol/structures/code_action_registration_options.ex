# codegen: do not edit
defmodule GenLSP.Structures.CodeActionRegistrationOptions do
  @moduledoc """
  Registration options for a {@link CodeActionRequest}.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * document_selector: A document selector to identify the scope of the registration. If set to null
    the document selector provided on the client side will be used.
  * code_action_kinds: CodeActionKinds that this server may return.

    The list of kinds may be generic, such as `CodeActionKind.Refactor`, or the server
    may list out every specific kind they provide.
  * resolve_provider: The server provides support to resolve additional
    information for a code action.

    @since 3.16.0
  """

  typedstruct do
    field(:document_selector, GenLSP.TypeAlias.DocumentSelector.t() | nil, enforce: true)
    field(:code_action_kinds, list(GenLSP.Enumerations.CodeActionKind.t()))
    field(:resolve_provider, boolean())
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      {"documentSelector", :document_selector} =>
        oneof([GenLSP.TypeAlias.DocumentSelector.schematic(), nil]),
      optional({"codeActionKinds", :code_action_kinds}) =>
        list(GenLSP.Enumerations.CodeActionKind.schematic()),
      optional({"resolveProvider", :resolve_provider}) => bool()
    })
  end
end
