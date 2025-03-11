# codegen: do not edit
defmodule GenDAP.Structures.ExceptionOptions do
  @moduledoc """
  An `ExceptionOptions` assigns configuration options to a set of exceptions.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields
  
  * path: A path that selects a single or multiple exceptions in a tree. If `path` is missing, the whole tree is selected.
    By convention the first segment of the path is a category that is used to group exceptions in the UI.
  * break_mode: Condition when a thrown exception should result in a break.
  """
  @derive JasonV.Encoder
  typedstruct do
    field :path, list(GenDAP.Structures.ExceptionPathSegment.t())
    field :break_mode, GenDAP.Enumerations.ExceptionBreakMode.t(), enforce: true
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      optional({"path", :path}) => list(GenDAP.Structures.ExceptionPathSegment.schematic()),
      {"breakMode", :break_mode} => GenDAP.Enumerations.ExceptionBreakMode.schematic(),
    })
  end
end
