# codegen: do not edit
defmodule GenDAP.Requests do
  import SchematicV

  def new(request) do
    unify(
      oneof(fn
        %{"command" => "attach"} ->
          GenDAP.Requests.AttachRequest.schematic()

        %{"command" => "breakpointLocations"} ->
          GenDAP.Requests.BreakpointLocationsRequest.schematic()

        %{"command" => "cancel"} ->
          GenDAP.Requests.CancelRequest.schematic()

        %{"command" => "completions"} ->
          GenDAP.Requests.CompletionsRequest.schematic()

        %{"command" => "configurationDone"} ->
          GenDAP.Requests.ConfigurationDoneRequest.schematic()

        %{"command" => "continue"} ->
          GenDAP.Requests.ContinueRequest.schematic()

        %{"command" => "dataBreakpointInfo"} ->
          GenDAP.Requests.DataBreakpointInfoRequest.schematic()

        %{"command" => "disassemble"} ->
          GenDAP.Requests.DisassembleRequest.schematic()

        %{"command" => "disconnect"} ->
          GenDAP.Requests.DisconnectRequest.schematic()

        %{"command" => "evaluate"} ->
          GenDAP.Requests.EvaluateRequest.schematic()

        %{"command" => "exceptionInfo"} ->
          GenDAP.Requests.ExceptionInfoRequest.schematic()

        %{"command" => "goto"} ->
          GenDAP.Requests.GotoRequest.schematic()

        %{"command" => "gotoTargets"} ->
          GenDAP.Requests.GotoTargetsRequest.schematic()

        %{"command" => "initialize"} ->
          GenDAP.Requests.InitializeRequest.schematic()

        %{"command" => "launch"} ->
          GenDAP.Requests.LaunchRequest.schematic()

        %{"command" => "loadedSources"} ->
          GenDAP.Requests.LoadedSourcesRequest.schematic()

        %{"command" => "locations"} ->
          GenDAP.Requests.LocationsRequest.schematic()

        %{"command" => "modules"} ->
          GenDAP.Requests.ModulesRequest.schematic()

        %{"command" => "next"} ->
          GenDAP.Requests.NextRequest.schematic()

        %{"command" => "pause"} ->
          GenDAP.Requests.PauseRequest.schematic()

        %{"command" => "readMemory"} ->
          GenDAP.Requests.ReadMemoryRequest.schematic()

        %{"command" => "restart"} ->
          GenDAP.Requests.RestartRequest.schematic()

        %{"command" => "restartFrame"} ->
          GenDAP.Requests.RestartFrameRequest.schematic()

        %{"command" => "reverseContinue"} ->
          GenDAP.Requests.ReverseContinueRequest.schematic()

        %{"command" => "runInTerminal"} ->
          GenDAP.Requests.RunInTerminalRequest.schematic()

        %{"command" => "scopes"} ->
          GenDAP.Requests.ScopesRequest.schematic()

        %{"command" => "setBreakpoints"} ->
          GenDAP.Requests.SetBreakpointsRequest.schematic()

        %{"command" => "setDataBreakpoints"} ->
          GenDAP.Requests.SetDataBreakpointsRequest.schematic()

        %{"command" => "setExceptionBreakpoints"} ->
          GenDAP.Requests.SetExceptionBreakpointsRequest.schematic()

        %{"command" => "setExpression"} ->
          GenDAP.Requests.SetExpressionRequest.schematic()

        %{"command" => "setFunctionBreakpoints"} ->
          GenDAP.Requests.SetFunctionBreakpointsRequest.schematic()

        %{"command" => "setInstructionBreakpoints"} ->
          GenDAP.Requests.SetInstructionBreakpointsRequest.schematic()

        %{"command" => "setVariable"} ->
          GenDAP.Requests.SetVariableRequest.schematic()

        %{"command" => "source"} ->
          GenDAP.Requests.SourceRequest.schematic()

        %{"command" => "stackTrace"} ->
          GenDAP.Requests.StackTraceRequest.schematic()

        %{"command" => "startDebugging"} ->
          GenDAP.Requests.StartDebuggingRequest.schematic()

        %{"command" => "stepBack"} ->
          GenDAP.Requests.StepBackRequest.schematic()

        %{"command" => "stepIn"} ->
          GenDAP.Requests.StepInRequest.schematic()

        %{"command" => "stepInTargets"} ->
          GenDAP.Requests.StepInTargetsRequest.schematic()

        %{"command" => "stepOut"} ->
          GenDAP.Requests.StepOutRequest.schematic()

        %{"command" => "terminate"} ->
          GenDAP.Requests.TerminateRequest.schematic()

        %{"command" => "terminateThreads"} ->
          GenDAP.Requests.TerminateThreadsRequest.schematic()

        %{"command" => "threads"} ->
          GenDAP.Requests.ThreadsRequest.schematic()

        %{"command" => "variables"} ->
          GenDAP.Requests.VariablesRequest.schematic()

        %{"command" => "writeMemory"} ->
          GenDAP.Requests.WriteMemoryRequest.schematic()

        _ ->
          {:error, "unexpected request payload"}
      end),
      request
    )
  end
end
