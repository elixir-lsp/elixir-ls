# codegen: do not edit
defmodule GenDAP.Structures.ColumnDescriptor do
  @moduledoc """
  A `ColumnDescriptor` specifies what module attribute to show in a column of the modules view, how to format it,
  and what the column's label should be.
  It is only used if the underlying UI actually supports this level of customization.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields
  
  * label: Header UI label of column.
  * type: Datatype of values in this column. Defaults to `string` if not specified.
  * format: Format to use for the rendered values in this column. TBD how the format strings looks like.
  * width: Width of this column in characters (hint only).
  * attribute_name: Name of the attribute rendered in this column.
  """
  @derive JasonV.Encoder
  typedstruct do
    field :label, String.t(), enforce: true
    field :type, String.t()
    field :format, String.t()
    field :width, integer()
    field :attribute_name, String.t(), enforce: true
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      {"label", :label} => str(),
      optional({"type", :type}) => oneof(["string", "number", "boolean", "unixTimestampUTC"]),
      optional({"format", :format}) => str(),
      optional({"width", :width}) => int(),
      {"attributeName", :attribute_name} => str(),
    })
  end
end
