# codegen: do not edit
defmodule GenDAP.Structures.Module do
  @moduledoc """
  A Module object represents a row in the modules view.
  The `id` attribute identifies a module in the modules view and is used in a `module` event for identifying a module for adding, updating or deleting.
  The `name` attribute is used to minimally render the module in the UI.
  
  Additional attributes can be added to the module. They show up in the module view if they have a corresponding `ColumnDescriptor`.
  
  To avoid an unnecessary proliferation of additional attributes with similar semantics but different names, we recommend to re-use attributes from the 'recommended' list below first, and only introduce new attributes if nothing appropriate could be found.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields
  
  * address_range: Address range covered by this module.
  * date_time_stamp: Module created or modified, encoded as a RFC 3339 timestamp.
  * id: Unique identifier for the module.
  * is_optimized: True if the module is optimized.
  * is_user_code: True if the module is considered 'user code' by a debugger that supports 'Just My Code'.
  * name: A name of the module.
  * path: Logical full path to the module. The exact definition is implementation defined, but usually this would be a full path to the on-disk file for the module.
  * symbol_file_path: Logical full path to the symbol file. The exact definition is implementation defined.
  * symbol_status: User-understandable description of if symbols were found for the module (ex: 'Symbols Loaded', 'Symbols not found', etc.)
  * version: Version of Module.
  """
  @derive JasonV.Encoder
  typedstruct do
    @typedoc "A type defining DAP structure Module"
    field :address_range, String.t()
    field :date_time_stamp, String.t()
    field :id, integer() | String.t(), enforce: true
    field :is_optimized, boolean()
    field :is_user_code, boolean()
    field :name, String.t(), enforce: true
    field :path, String.t()
    field :symbol_file_path, String.t()
    field :symbol_status, String.t()
    field :version, String.t()
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      optional({"addressRange", :address_range}) => str(),
      optional({"dateTimeStamp", :date_time_stamp}) => str(),
      {"id", :id} => oneof([int(), str()]),
      optional({"isOptimized", :is_optimized}) => bool(),
      optional({"isUserCode", :is_user_code}) => bool(),
      {"name", :name} => str(),
      optional({"path", :path}) => str(),
      optional({"symbolFilePath", :symbol_file_path}) => str(),
      optional({"symbolStatus", :symbol_status}) => str(),
      optional({"version", :version}) => str(),
    })
  end
end
