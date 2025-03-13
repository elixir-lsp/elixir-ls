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
  
  * attribute_name: Name of the attribute rendered in this column.
  * format: Format to use for the rendered values in this column. TBD how the format strings looks like.
  * label: Header UI label of column.
  * type: Datatype of values in this column. Defaults to `string` if not specified.
  * width: Width of this column in characters (hint only).
  """
  @derive JasonV.Encoder
  typedstruct do
    @typedoc "A type defining DAP structure ColumnDescriptor"
    field :attribute_name, String.t(), enforce: true
    field :format, String.t()
    field :label, String.t(), enforce: true
    field :type, String.t()
    field :width, integer()
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      {"attributeName", :attribute_name} => str(),
      optional({"format", :format}) => str(),
      {"label", :label} => str(),
      optional({"type", :type}) => oneof(["string", "number", "boolean", "unixTimestampUTC"]),
      optional({"width", :width}) => int(),
    })
  end
end
