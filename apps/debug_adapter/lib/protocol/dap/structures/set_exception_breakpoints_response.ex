# codegen: do not edit
defmodule GenDAP.Structures.SetExceptionBreakpointsResponse do
  @moduledoc """
  Response to `setExceptionBreakpoints` request.
  The response contains an array of `Breakpoint` objects with information about each exception breakpoint or filter. The `Breakpoint` objects are in the same order as the elements of the `filters`, `filterOptions`, `exceptionOptions` arrays given as arguments. If both `filters` and `filterOptions` are given, the returned array must start with `filters` information first, followed by `filterOptions` information.
  The `verified` property of a `Breakpoint` object signals whether the exception breakpoint or filter could be successfully created and whether the condition is valid. In case of an error the `message` property explains the problem. The `id` property can be used to introduce a unique ID for the exception breakpoint or filter so that it can be updated subsequently by sending breakpoint events.
  For backward compatibility both the `breakpoints` array and the enclosing `body` are optional. If these elements are missing a client is not able to show problems for individual exception breakpoints or filters.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields
  
  * body
  * command: The command requested.
  * message: Contains the raw error in short form if `success` is false.
    This raw error might be interpreted by the client and is not shown in the UI.
    Some predefined values exist.
  * type
  * success: Outcome of the request.
    If true, the request was successful and the `body` attribute may contain the result of the request.
    If the value is false, the attribute `message` contains the error in short form and the `body` may contain additional information (see `ErrorResponse.body.error`).
  * request_seq: Sequence number of the corresponding request.
  """
  @derive JasonV.Encoder
  typedstruct do
    field :body, %{breakpoints: list(GenDAP.Structures.Breakpoint.t())}
    field :command, String.t(), enforce: true
    field :message, String.t()
    field :type, String.t(), enforce: true
    field :success, boolean(), enforce: true
    field :request_seq, integer(), enforce: true
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      optional({"body", :body}) => schema(__MODULE__, %{
      optional(:breakpoints) => list(GenDAP.Structures.Breakpoint.schematic())
    }),
      {"command", :command} => str(),
      optional({"message", :message}) => oneof(["cancelled", "notStopped"]),
      {"type", :type} => oneof(["response"]),
      {"success", :success} => bool(),
      {"request_seq", :request_seq} => int(),
    })
  end
end
