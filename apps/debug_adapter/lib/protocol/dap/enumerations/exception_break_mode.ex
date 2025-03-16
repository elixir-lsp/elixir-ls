# codegen: do not edit
defmodule GenDAP.Enumerations.ExceptionBreakMode do
  @moduledoc """
  This enumeration defines all possible conditions when a thrown exception should result in a break.
  never: never breaks,
  always: always breaks,
  unhandled: breaks when exception unhandled,
  userUnhandled: breaks if the exception is not handled by user code.
  """

  @typedoc "A type defining DAP enumeration ExceptionBreakMode"
  @type t :: String.t()

  import Schematic, warn: false

  @spec never() :: String.t()
  def never, do: "never"

  @spec always() :: String.t()
  def always, do: "always"

  @spec unhandled() :: String.t()
  def unhandled, do: "unhandled"

  @spec user_unhandled() :: String.t()
  def user_unhandled, do: "userUnhandled"

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    oneof([
      "never",
      "always",
      "unhandled",
      "userUnhandled"
    ])
  end
end
