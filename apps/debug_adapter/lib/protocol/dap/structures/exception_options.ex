# codegen: do not edit

defmodule GenDAP.Structures.ExceptionOptions do
  @moduledoc """
  An `ExceptionOptions` assigns configuration options to a set of exceptions.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * break_mode: Condition when a thrown exception should result in a break.
  * path: A path that selects a single or multiple exceptions in a tree. If `path` is missing, the whole tree is selected.
    By convention the first segment of the path is a category that is used to group exceptions in the UI.
  """
  @derive JasonV.Encoder
  typedstruct do
    @typedoc "A type defining DAP structure ExceptionOptions"
    field(:break_mode, GenDAP.Enumerations.ExceptionBreakMode.t(), enforce: true)
    field(:path, list(GenDAP.Structures.ExceptionPathSegment.t()))
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      {"breakMode", :break_mode} => GenDAP.Enumerations.ExceptionBreakMode.schematic(),
      optional({"path", :path}) => list(GenDAP.Structures.ExceptionPathSegment.schematic())
    })
  end
end
