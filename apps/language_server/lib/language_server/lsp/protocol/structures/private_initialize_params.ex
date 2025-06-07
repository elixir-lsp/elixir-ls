# codegen: do not edit
defmodule GenLSP.Structures.PrivateInitializeParams do
  @moduledoc """
  The initialize parameters
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * process_id: The process Id of the parent process that started
    the server.

    Is `null` if the process has not been started by another process.
    If the parent process is not alive then the server should exit.
  * client_info: Information about the client

    @since 3.15.0
  * locale: The locale the client is currently showing the user interface
    in. This must not necessarily be the locale of the operating
    system.

    Uses IETF language tags as the value's syntax
    (See https://en.wikipedia.org/wiki/IETF_language_tag)

    @since 3.16.0
  * root_path: The rootPath of the workspace. Is null
    if no folder is open.

    @deprecated in favour of rootUri.
  * root_uri: The rootUri of the workspace. Is null if no
    folder is open. If both `rootPath` and `rootUri` are set
    `rootUri` wins.

    @deprecated in favour of workspaceFolders.
  * capabilities: The capabilities provided by the client (editor or tool)
  * initialization_options: User provided initialization options.
  * trace: The initial trace setting. If omitted trace is disabled ('off').
  * work_done_token: An optional token that a server can use to report work done progress.
  """
  
  typedstruct do
    field :process_id, integer() | nil, enforce: true
    field :client_info, map()
    field :locale, String.t()
    field :root_path, String.t() | nil
    field :root_uri, GenLSP.BaseTypes.document_uri() | nil, enforce: true
    field :capabilities, GenLSP.Structures.ClientCapabilities.t(), enforce: true
    field :initialization_options, GenLSP.TypeAlias.LSPAny.t()
    field :trace, GenLSP.Enumerations.TraceValues.t()
    field :work_done_token, GenLSP.TypeAlias.ProgressToken.t()
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      {"processId", :process_id} => oneof([int(), nil]),
      optional({"clientInfo", :client_info}) =>
        map(%{
          {"name", :name} => str(),
          optional({"version", :version}) => str()
        }),
      optional({"locale", :locale}) => str(),
      optional({"rootPath", :root_path}) => oneof([str(), nil]),
      {"rootUri", :root_uri} => oneof([str(), nil]),
      {"capabilities", :capabilities} => GenLSP.Structures.ClientCapabilities.schematic(),
      optional({"initializationOptions", :initialization_options}) =>
        GenLSP.TypeAlias.LSPAny.schematic(),
      optional({"trace", :trace}) => GenLSP.Enumerations.TraceValues.schematic(),
      optional({"workDoneToken", :work_done_token}) => GenLSP.TypeAlias.ProgressToken.schematic()
    })
  end
end
