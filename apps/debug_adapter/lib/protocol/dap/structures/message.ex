# codegen: do not edit

defmodule GenDAP.Structures.Message do
  @moduledoc """
  A structured message object. Used to return errors from requests.
  """

  import SchematicV, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * format: A format string for the message. Embedded variables have the form `{name}`.
    If variable name starts with an underscore character, the variable does not contain user data (PII) and can be safely used for telemetry purposes.
  * id: Unique (within a debug adapter implementation) identifier for the message. The purpose of these error IDs is to help extension authors that have the requirement that every user visible error message needs a corresponding error number, so that users or customer support can find information about the specific error more easily.
  * send_telemetry: If true send to telemetry.
  * show_user: If true show user.
  * url: A url where additional information about this message can be found.
  * url_label: A label that is presented to the user as the UI for opening the url.
  * variables: An object used as a dictionary for looking up the variables in the format string.
  """

  typedstruct do
    @typedoc "A type defining DAP structure Message"
    field(:format, String.t(), enforce: true)
    field(:id, integer(), enforce: true)
    field(:send_telemetry, boolean())
    field(:show_user, boolean())
    field(:url, String.t())
    field(:url_label, String.t())
    field(:variables, %{optional(String.t()) => String.t()})
  end

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    schema(__MODULE__, %{
      {"format", :format} => str(),
      {"id", :id} => int(),
      optional({"sendTelemetry", :send_telemetry}) => bool(),
      optional({"showUser", :show_user}) => bool(),
      optional({"url", :url}) => str(),
      optional({"urlLabel", :url_label}) => str(),
      optional({"variables", :variables}) => map(keys: str(), values: str())
    })
  end
end
