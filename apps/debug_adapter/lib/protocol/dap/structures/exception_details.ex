# codegen: do not edit


defmodule GenDAP.Structures.ExceptionDetails do
  @moduledoc """
  Detailed information about an exception that has occurred.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields
  
  * evaluate_name: An expression that can be evaluated in the current scope to obtain the exception object.
  * full_type_name: Fully-qualified type name of the exception object.
  * inner_exception: Details of the exception contained by this exception, if any.
  * message: Message contained in the exception.
  * stack_trace: Stack trace at the time the exception was thrown.
  * type_name: Short type name of the exception object.
  """
  @derive JasonV.Encoder
  typedstruct do
    @typedoc "A type defining DAP structure ExceptionDetails"
    field :evaluate_name, String.t()
    field :full_type_name, String.t()
    field :inner_exception, list(GenDAP.Structures.ExceptionDetails.t())
    field :message, String.t()
    field :stack_trace, String.t()
    field :type_name, String.t()
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      optional({"evaluateName", :evaluate_name}) => str(),
      optional({"fullTypeName", :full_type_name}) => str(),
      optional({"innerException", :inner_exception}) => list({__MODULE__, :schematic, []}),
      optional({"message", :message}) => str(),
      optional({"stackTrace", :stack_trace}) => str(),
      optional({"typeName", :type_name}) => str(),
    })
  end
end

