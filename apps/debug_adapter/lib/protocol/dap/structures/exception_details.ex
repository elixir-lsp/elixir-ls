# codegen: do not edit
defmodule GenDAP.Structures.ExceptionDetails do
  @moduledoc """
  Detailed information about an exception that has occurred.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields
  
  * message: Message contained in the exception.
  * evaluate_name: An expression that can be evaluated in the current scope to obtain the exception object.
  * type_name: Short type name of the exception object.
  * full_type_name: Fully-qualified type name of the exception object.
  * stack_trace: Stack trace at the time the exception was thrown.
  * inner_exception: Details of the exception contained by this exception, if any.
  """
  @derive JasonV.Encoder
  typedstruct do
    field :message, String.t()
    field :evaluate_name, String.t()
    field :type_name, String.t()
    field :full_type_name, String.t()
    field :stack_trace, String.t()
    field :inner_exception, list(GenDAP.Structures.ExceptionDetails.t())
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      optional({"message", :message}) => str(),
      optional({"evaluateName", :evaluate_name}) => str(),
      optional({"typeName", :type_name}) => str(),
      optional({"fullTypeName", :full_type_name}) => str(),
      optional({"stackTrace", :stack_trace}) => str(),
      optional({"innerException", :inner_exception}) => list({__MODULE__, :schematic, []}),
    })
  end
end
