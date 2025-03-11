# codegen: do not edit
defmodule GenDAP.Structures.InitializeRequestArguments do
  @moduledoc """
  Arguments for `initialize` request.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields
  
  * client_i_d: The ID of the client using this adapter.
  * client_name: The human-readable name of the client using this adapter.
  * adapter_i_d: The ID of the debug adapter.
  * locale: The ISO-639 locale of the client using this adapter, e.g. en-US or de-CH.
  * lines_start_at1: If true all line numbers are 1-based (default).
  * columns_start_at1: If true all column numbers are 1-based (default).
  * path_format: Determines in what format paths are specified. The default is `path`, which is the native format.
  * supports_variable_type: Client supports the `type` attribute for variables.
  * supports_variable_paging: Client supports the paging of variables.
  * supports_run_in_terminal_request: Client supports the `runInTerminal` request.
  * supports_memory_references: Client supports memory references.
  * supports_progress_reporting: Client supports progress reporting.
  * supports_invalidated_event: Client supports the `invalidated` event.
  * supports_memory_event: Client supports the `memory` event.
  * supports_args_can_be_interpreted_by_shell: Client supports the `argsCanBeInterpretedByShell` attribute on the `runInTerminal` request.
  * supports_start_debugging_request: Client supports the `startDebugging` request.
  * supports_a_n_s_i_styling: The client will interpret ANSI escape sequences in the display of `OutputEvent.output` and `Variable.value` fields when `Capabilities.supportsANSIStyling` is also enabled.
  """
  @derive JasonV.Encoder
  typedstruct do
    field :client_i_d, String.t()
    field :client_name, String.t()
    field :adapter_i_d, String.t(), enforce: true
    field :locale, String.t()
    field :lines_start_at1, boolean()
    field :columns_start_at1, boolean()
    field :path_format, String.t()
    field :supports_variable_type, boolean()
    field :supports_variable_paging, boolean()
    field :supports_run_in_terminal_request, boolean()
    field :supports_memory_references, boolean()
    field :supports_progress_reporting, boolean()
    field :supports_invalidated_event, boolean()
    field :supports_memory_event, boolean()
    field :supports_args_can_be_interpreted_by_shell, boolean()
    field :supports_start_debugging_request, boolean()
    field :supports_a_n_s_i_styling, boolean()
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      optional({"clientID", :client_i_d}) => str(),
      optional({"clientName", :client_name}) => str(),
      {"adapterID", :adapter_i_d} => str(),
      optional({"locale", :locale}) => str(),
      optional({"linesStartAt1", :lines_start_at1}) => bool(),
      optional({"columnsStartAt1", :columns_start_at1}) => bool(),
      optional({"pathFormat", :path_format}) => oneof(["path", "uri"]),
      optional({"supportsVariableType", :supports_variable_type}) => bool(),
      optional({"supportsVariablePaging", :supports_variable_paging}) => bool(),
      optional({"supportsRunInTerminalRequest", :supports_run_in_terminal_request}) => bool(),
      optional({"supportsMemoryReferences", :supports_memory_references}) => bool(),
      optional({"supportsProgressReporting", :supports_progress_reporting}) => bool(),
      optional({"supportsInvalidatedEvent", :supports_invalidated_event}) => bool(),
      optional({"supportsMemoryEvent", :supports_memory_event}) => bool(),
      optional({"supportsArgsCanBeInterpretedByShell", :supports_args_can_be_interpreted_by_shell}) => bool(),
      optional({"supportsStartDebuggingRequest", :supports_start_debugging_request}) => bool(),
      optional({"supportsANSIStyling", :supports_a_n_s_i_styling}) => bool(),
    })
  end
end
