# codegen: do not edit
defmodule GenLSP.Structures.WorkDoneProgressReport do
  import SchematicV, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * kind
  * cancellable: Controls enablement state of a cancel button.

    Clients that don't support cancellation or don't support controlling the button's
    enablement state are allowed to ignore the property.
  * message: Optional, more detailed associated progress message. Contains
    complementary information to the `title`.

    Examples: "3/25 files", "project/src/module2", "node_modules/some_dep".
    If unset, the previous progress message (if any) is still valid.
  * percentage: Optional progress percentage to display (value 100 is considered 100%).
    If not provided infinite progress is assumed and clients are allowed
    to ignore the `percentage` value in subsequent in report notifications.

    The value should be steadily rising. Clients are free to ignore values
    that are not following this rule. The value range is [0, 100]
  """

  typedstruct do
    field(:kind, String.t(), enforce: true)
    field(:cancellable, boolean())
    field(:message, String.t())
    field(:percentage, GenLSP.BaseTypes.uinteger())
  end

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    schema(__MODULE__, %{
      {"kind", :kind} => "report",
      optional({"cancellable", :cancellable}) => bool(),
      optional({"message", :message}) => str(),
      optional({"percentage", :percentage}) => int()
    })
  end
end
