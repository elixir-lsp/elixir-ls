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
  
  * id: Unique identifier for the module.
  * name: A name of the module.
  * version: Version of Module.
  * path: Logical full path to the module. The exact definition is implementation defined, but usually this would be a full path to the on-disk file for the module.
  * is_optimized: True if the module is optimized.
  * is_user_code: True if the module is considered 'user code' by a debugger that supports 'Just My Code'.
  * symbol_status: User-understandable description of if symbols were found for the module (ex: 'Symbols Loaded', 'Symbols not found', etc.)
  * symbol_file_path: Logical full path to the symbol file. The exact definition is implementation defined.
  * date_time_stamp: Module created or modified, encoded as a RFC 3339 timestamp.
  * address_range: Address range covered by this module.
  """
  @derive JasonV.Encoder
  typedstruct do
    field :id, integer() | String.t(), enforce: true
    field :name, String.t(), enforce: true
    field :version, String.t()
    field :path, String.t()
    field :is_optimized, boolean()
    field :is_user_code, boolean()
    field :symbol_status, String.t()
    field :symbol_file_path, String.t()
    field :date_time_stamp, String.t()
    field :address_range, String.t()
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      {"id", :id} => oneof([int(), str()]),
      {"name", :name} => str(),
      optional({"version", :version}) => str(),
      optional({"path", :path}) => str(),
      optional({"isOptimized", :is_optimized}) => bool(),
      optional({"isUserCode", :is_user_code}) => bool(),
      optional({"symbolStatus", :symbol_status}) => str(),
      optional({"symbolFilePath", :symbol_file_path}) => str(),
      optional({"dateTimeStamp", :date_time_stamp}) => str(),
      optional({"addressRange", :address_range}) => str(),
    })
  end
end
