# codegen: do not edit

defmodule GenDAP.Structures.InitializeRequestArguments do
  @moduledoc """
  Arguments for `initialize` request.
  """

  import SchematicV, warn: false

  use TypedStruct

  @doc """
  ## Fields

  * adapter_i_d: The ID of the debug adapter.
  * client_i_d: The ID of the client using this adapter.
  * client_name: The human-readable name of the client using this adapter.
  * columns_start_at1: If true all column numbers are 1-based (default).
  * lines_start_at1: If true all line numbers are 1-based (default).
  * locale: The ISO-639 locale of the client using this adapter, e.g. en-US or de-CH.
  * path_format: Determines in what format paths are specified. The default is `path`, which is the native format.
  * supports_a_n_s_i_styling: The client will interpret ANSI escape sequences in the display of `OutputEvent.output` and `Variable.value` fields when `Capabilities.supportsANSIStyling` is also enabled.
  * supports_args_can_be_interpreted_by_shell: Client supports the `argsCanBeInterpretedByShell` attribute on the `runInTerminal` request.
  * supports_invalidated_event: Client supports the `invalidated` event.
  * supports_memory_event: Client supports the `memory` event.
  * supports_memory_references: Client supports memory references.
  * supports_progress_reporting: Client supports progress reporting.
  * supports_run_in_terminal_request: Client supports the `runInTerminal` request.
  * supports_start_debugging_request: Client supports the `startDebugging` request.
  * supports_variable_paging: Client supports the paging of variables.
  * supports_variable_type: Client supports the `type` attribute for variables.
  """

  typedstruct do
    @typedoc "A type defining DAP structure InitializeRequestArguments"
    field(:adapter_i_d, String.t(), enforce: true)
    field(:client_i_d, String.t())
    field(:client_name, String.t())
    field(:columns_start_at1, boolean())
    field(:lines_start_at1, boolean())
    field(:locale, String.t())
    field(:path_format, String.t())
    field(:supports_a_n_s_i_styling, boolean())
    field(:supports_args_can_be_interpreted_by_shell, boolean())
    field(:supports_invalidated_event, boolean())
    field(:supports_memory_event, boolean())
    field(:supports_memory_references, boolean())
    field(:supports_progress_reporting, boolean())
    field(:supports_run_in_terminal_request, boolean())
    field(:supports_start_debugging_request, boolean())
    field(:supports_variable_paging, boolean())
    field(:supports_variable_type, boolean())
  end

  @doc false
  @spec schematic() :: SchematicV.t()
  def schematic() do
    schema(__MODULE__, %{
      {"adapterID", :adapter_i_d} => str(),
      optional({"clientID", :client_i_d}) => str(),
      optional({"clientName", :client_name}) => str(),
      optional({"columnsStartAt1", :columns_start_at1}) => bool(),
      optional({"linesStartAt1", :lines_start_at1}) => bool(),
      optional({"locale", :locale}) => str(),
      optional({"pathFormat", :path_format}) => oneof(["path", "uri", str()]),
      optional({"supportsANSIStyling", :supports_a_n_s_i_styling}) => bool(),
      optional(
        {"supportsArgsCanBeInterpretedByShell", :supports_args_can_be_interpreted_by_shell}
      ) => bool(),
      optional({"supportsInvalidatedEvent", :supports_invalidated_event}) => bool(),
      optional({"supportsMemoryEvent", :supports_memory_event}) => bool(),
      optional({"supportsMemoryReferences", :supports_memory_references}) => bool(),
      optional({"supportsProgressReporting", :supports_progress_reporting}) => bool(),
      optional({"supportsRunInTerminalRequest", :supports_run_in_terminal_request}) => bool(),
      optional({"supportsStartDebuggingRequest", :supports_start_debugging_request}) => bool(),
      optional({"supportsVariablePaging", :supports_variable_paging}) => bool(),
      optional({"supportsVariableType", :supports_variable_type}) => bool()
    })
  end
end
