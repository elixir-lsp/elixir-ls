# codegen: do not edit
defmodule GenLSP.Structures.Command do
  @moduledoc """
  Represents a reference to a command. Provides a title which
  will be used to represent a command in the UI and, optionally,
  an array of arguments which will be passed to the command handler
  function when invoked.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * title: Title of the command, like `save`.
  * command: The identifier of the actual command handler.
  * arguments: Arguments that the command handler should be
    invoked with.
  """

  typedstruct do
    field(:title, String.t(), enforce: true)
    field(:command, String.t(), enforce: true)
    field(:arguments, list(GenLSP.TypeAlias.LSPAny.t()))
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      {"title", :title} => str(),
      {"command", :command} => str(),
      optional({"arguments", :arguments}) => list(GenLSP.TypeAlias.LSPAny.schematic())
    })
  end
end
