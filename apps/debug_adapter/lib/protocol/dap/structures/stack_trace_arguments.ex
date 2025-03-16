# codegen: do not edit


defmodule GenDAP.Structures.StackTraceArguments do
  @moduledoc """
  Arguments for `stackTrace` request.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields
  
  * format: Specifies details on how to format the returned `StackFrame.name`. The debug adapter may format requested details in any way that would make sense to a developer.
    The attribute is only honored by a debug adapter if the corresponding capability `supportsValueFormattingOptions` is true.
  * levels: The maximum number of frames to return. If levels is not specified or 0, all frames are returned.
  * start_frame: The index of the first frame to return; if omitted frames start at 0.
  * thread_id: Retrieve the stacktrace for this thread.
  """
  @derive JasonV.Encoder
  typedstruct do
    @typedoc "A type defining DAP structure StackTraceArguments"
    field :format, GenDAP.Structures.StackFrameFormat.t()
    field :levels, integer()
    field :start_frame, integer()
    field :thread_id, integer(), enforce: true
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      optional({"format", :format}) => GenDAP.Structures.StackFrameFormat.schematic(),
      optional({"levels", :levels}) => int(),
      optional({"startFrame", :start_frame}) => int(),
      {"threadId", :thread_id} => int(),
    })
  end
end

