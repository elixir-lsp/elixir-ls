# codegen: do not edit
defmodule GenDAP.Structures.Capabilities do
  @moduledoc """
  Information about the capabilities of a debug adapter.
  """

  import Schematic, warn: false

  use TypedStruct

  @doc """
  ## Fields
  
  * support_suspend_debuggee: The debug adapter supports the `suspendDebuggee` attribute on the `disconnect` request.
  * supported_checksum_algorithms: Checksum algorithms supported by the debug adapter.
  * supports_write_memory_request: The debug adapter supports the `writeMemory` request.
  * supports_a_n_s_i_styling: The debug adapter supports ANSI escape sequences in styling of `OutputEvent.output` and `Variable.value` fields.
  * supports_terminate_threads_request: The debug adapter supports the `terminateThreads` request.
  * supports_value_formatting_options: The debug adapter supports a `format` attribute on the `stackTrace`, `variables`, and `evaluate` requests.
  * supports_evaluate_for_hovers: The debug adapter supports a (side effect free) `evaluate` request for data hovers.
  * supports_loaded_sources_request: The debug adapter supports the `loadedSources` request.
  * supports_function_breakpoints: The debug adapter supports function breakpoints.
  * supports_delayed_stack_trace_loading: The debug adapter supports the delayed loading of parts of the stack, which requires that both the `startFrame` and `levels` arguments and the `totalFrames` result of the `stackTrace` request are supported.
  * supports_conditional_breakpoints: The debug adapter supports conditional breakpoints.
  * supports_log_points: The debug adapter supports log points by interpreting the `logMessage` attribute of the `SourceBreakpoint`.
  * supports_data_breakpoints: The debug adapter supports data breakpoints.
  * supports_disassemble_request: The debug adapter supports the `disassemble` request.
  * supports_goto_targets_request: The debug adapter supports the `gotoTargets` request.
  * supports_step_back: The debug adapter supports stepping back via the `stepBack` and `reverseContinue` requests.
  * supports_exception_info_request: The debug adapter supports the `exceptionInfo` request.
  * supports_set_variable: The debug adapter supports setting a variable to a value.
  * completion_trigger_characters: The set of characters that should trigger completion in a REPL. If not specified, the UI should assume the `.` character.
  * supports_restart_request: The debug adapter supports the `restart` request. In this case a client should not implement `restart` by terminating and relaunching the adapter but by calling the `restart` request.
  * supports_breakpoint_locations_request: The debug adapter supports the `breakpointLocations` request.
  * supports_configuration_done_request: The debug adapter supports the `configurationDone` request.
  * supports_read_memory_request: The debug adapter supports the `readMemory` request.
  * supports_clipboard_context: The debug adapter supports the `clipboard` context value in the `evaluate` request.
  * supports_modules_request: The debug adapter supports the `modules` request.
  * exception_breakpoint_filters: Available exception filter options for the `setExceptionBreakpoints` request.
  * supports_hit_conditional_breakpoints: The debug adapter supports breakpoints that break execution after a specified number of hits.
  * supports_stepping_granularity: The debug adapter supports stepping granularities (argument `granularity`) for the stepping requests.
  * supports_exception_options: The debug adapter supports `exceptionOptions` on the `setExceptionBreakpoints` request.
  * supports_exception_filter_options: The debug adapter supports `filterOptions` as an argument on the `setExceptionBreakpoints` request.
  * supports_step_in_targets_request: The debug adapter supports the `stepInTargets` request.
  * supports_data_breakpoint_bytes: The debug adapter supports the `asAddress` and `bytes` fields in the `dataBreakpointInfo` request.
  * supports_completions_request: The debug adapter supports the `completions` request.
  * breakpoint_modes: Modes of breakpoints supported by the debug adapter, such as 'hardware' or 'software'. If present, the client may allow the user to select a mode and include it in its `setBreakpoints` request.
    
    Clients may present the first applicable mode in this array as the 'default' mode in gestures that set breakpoints.
  * supports_terminate_request: The debug adapter supports the `terminate` request.
  * supports_set_expression: The debug adapter supports the `setExpression` request.
  * supports_single_thread_execution_requests: The debug adapter supports the `singleThread` property on the execution requests (`continue`, `next`, `stepIn`, `stepOut`, `reverseContinue`, `stepBack`).
  * supports_restart_frame: The debug adapter supports restarting a frame.
  * support_terminate_debuggee: The debug adapter supports the `terminateDebuggee` attribute on the `disconnect` request.
  * additional_module_columns: The set of additional module information exposed by the debug adapter.
  * supports_instruction_breakpoints: The debug adapter supports adding breakpoints based on instruction references.
  * supports_cancel_request: The debug adapter supports the `cancel` request.
  """
  @derive JasonV.Encoder
  typedstruct do
    field :support_suspend_debuggee, boolean()
    field :supported_checksum_algorithms, list(GenDAP.Enumerations.ChecksumAlgorithm.t())
    field :supports_write_memory_request, boolean()
    field :supports_a_n_s_i_styling, boolean()
    field :supports_terminate_threads_request, boolean()
    field :supports_value_formatting_options, boolean()
    field :supports_evaluate_for_hovers, boolean()
    field :supports_loaded_sources_request, boolean()
    field :supports_function_breakpoints, boolean()
    field :supports_delayed_stack_trace_loading, boolean()
    field :supports_conditional_breakpoints, boolean()
    field :supports_log_points, boolean()
    field :supports_data_breakpoints, boolean()
    field :supports_disassemble_request, boolean()
    field :supports_goto_targets_request, boolean()
    field :supports_step_back, boolean()
    field :supports_exception_info_request, boolean()
    field :supports_set_variable, boolean()
    field :completion_trigger_characters, list(String.t())
    field :supports_restart_request, boolean()
    field :supports_breakpoint_locations_request, boolean()
    field :supports_configuration_done_request, boolean()
    field :supports_read_memory_request, boolean()
    field :supports_clipboard_context, boolean()
    field :supports_modules_request, boolean()
    field :exception_breakpoint_filters, list(GenDAP.Structures.ExceptionBreakpointsFilter.t())
    field :supports_hit_conditional_breakpoints, boolean()
    field :supports_stepping_granularity, boolean()
    field :supports_exception_options, boolean()
    field :supports_exception_filter_options, boolean()
    field :supports_step_in_targets_request, boolean()
    field :supports_data_breakpoint_bytes, boolean()
    field :supports_completions_request, boolean()
    field :breakpoint_modes, list(GenDAP.Structures.BreakpointMode.t())
    field :supports_terminate_request, boolean()
    field :supports_set_expression, boolean()
    field :supports_single_thread_execution_requests, boolean()
    field :supports_restart_frame, boolean()
    field :support_terminate_debuggee, boolean()
    field :additional_module_columns, list(GenDAP.Structures.ColumnDescriptor.t())
    field :supports_instruction_breakpoints, boolean()
    field :supports_cancel_request, boolean()
  end

  @doc false
  @spec schematic() :: Schematic.t()
  def schematic() do
    schema(__MODULE__, %{
      optional({"supportSuspendDebuggee", :support_suspend_debuggee}) => bool(),
      optional({"supportedChecksumAlgorithms", :supported_checksum_algorithms}) => list(GenDAP.Enumerations.ChecksumAlgorithm.schematic()),
      optional({"supportsWriteMemoryRequest", :supports_write_memory_request}) => bool(),
      optional({"supportsANSIStyling", :supports_a_n_s_i_styling}) => bool(),
      optional({"supportsTerminateThreadsRequest", :supports_terminate_threads_request}) => bool(),
      optional({"supportsValueFormattingOptions", :supports_value_formatting_options}) => bool(),
      optional({"supportsEvaluateForHovers", :supports_evaluate_for_hovers}) => bool(),
      optional({"supportsLoadedSourcesRequest", :supports_loaded_sources_request}) => bool(),
      optional({"supportsFunctionBreakpoints", :supports_function_breakpoints}) => bool(),
      optional({"supportsDelayedStackTraceLoading", :supports_delayed_stack_trace_loading}) => bool(),
      optional({"supportsConditionalBreakpoints", :supports_conditional_breakpoints}) => bool(),
      optional({"supportsLogPoints", :supports_log_points}) => bool(),
      optional({"supportsDataBreakpoints", :supports_data_breakpoints}) => bool(),
      optional({"supportsDisassembleRequest", :supports_disassemble_request}) => bool(),
      optional({"supportsGotoTargetsRequest", :supports_goto_targets_request}) => bool(),
      optional({"supportsStepBack", :supports_step_back}) => bool(),
      optional({"supportsExceptionInfoRequest", :supports_exception_info_request}) => bool(),
      optional({"supportsSetVariable", :supports_set_variable}) => bool(),
      optional({"completionTriggerCharacters", :completion_trigger_characters}) => list(str()),
      optional({"supportsRestartRequest", :supports_restart_request}) => bool(),
      optional({"supportsBreakpointLocationsRequest", :supports_breakpoint_locations_request}) => bool(),
      optional({"supportsConfigurationDoneRequest", :supports_configuration_done_request}) => bool(),
      optional({"supportsReadMemoryRequest", :supports_read_memory_request}) => bool(),
      optional({"supportsClipboardContext", :supports_clipboard_context}) => bool(),
      optional({"supportsModulesRequest", :supports_modules_request}) => bool(),
      optional({"exceptionBreakpointFilters", :exception_breakpoint_filters}) => list(GenDAP.Structures.ExceptionBreakpointsFilter.schematic()),
      optional({"supportsHitConditionalBreakpoints", :supports_hit_conditional_breakpoints}) => bool(),
      optional({"supportsSteppingGranularity", :supports_stepping_granularity}) => bool(),
      optional({"supportsExceptionOptions", :supports_exception_options}) => bool(),
      optional({"supportsExceptionFilterOptions", :supports_exception_filter_options}) => bool(),
      optional({"supportsStepInTargetsRequest", :supports_step_in_targets_request}) => bool(),
      optional({"supportsDataBreakpointBytes", :supports_data_breakpoint_bytes}) => bool(),
      optional({"supportsCompletionsRequest", :supports_completions_request}) => bool(),
      optional({"breakpointModes", :breakpoint_modes}) => list(GenDAP.Structures.BreakpointMode.schematic()),
      optional({"supportsTerminateRequest", :supports_terminate_request}) => bool(),
      optional({"supportsSetExpression", :supports_set_expression}) => bool(),
      optional({"supportsSingleThreadExecutionRequests", :supports_single_thread_execution_requests}) => bool(),
      optional({"supportsRestartFrame", :supports_restart_frame}) => bool(),
      optional({"supportTerminateDebuggee", :support_terminate_debuggee}) => bool(),
      optional({"additionalModuleColumns", :additional_module_columns}) => list(GenDAP.Structures.ColumnDescriptor.schematic()),
      optional({"supportsInstructionBreakpoints", :supports_instruction_breakpoints}) => bool(),
      optional({"supportsCancelRequest", :supports_cancel_request}) => bool(),
    })
  end
end
