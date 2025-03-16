# codegen: do not edit
defmodule GenDAP.Responses do
  import Schematic

  def new(request) do
    unify(
      oneof(fn
        %{"command" => "attach"} ->
          GenDAP.Requests.AttachResponse.schematic()

        %{"command" => "breakpointLocations"} ->
          GenDAP.Requests.BreakpointLocationsResponse.schematic()

        %{"command" => "cancel"} ->
          GenDAP.Requests.CancelResponse.schematic()

        %{"command" => "completions"} ->
          GenDAP.Requests.CompletionsResponse.schematic()

        %{"command" => "configurationDone"} ->
          GenDAP.Requests.ConfigurationDoneResponse.schematic()

        %{"command" => "continue"} ->
          GenDAP.Requests.ContinueResponse.schematic()

        %{"command" => "dataBreakpointInfo"} ->
          GenDAP.Requests.DataBreakpointInfoResponse.schematic()

        %{"command" => "disassemble"} ->
          GenDAP.Requests.DisassembleResponse.schematic()

        %{"command" => "disconnect"} ->
          GenDAP.Requests.DisconnectResponse.schematic()

        %{"command" => "evaluate"} ->
          GenDAP.Requests.EvaluateResponse.schematic()

        %{"command" => "exceptionInfo"} ->
          GenDAP.Requests.ExceptionInfoResponse.schematic()

        %{"command" => "goto"} ->
          GenDAP.Requests.GotoResponse.schematic()

        %{"command" => "gotoTargets"} ->
          GenDAP.Requests.GotoTargetsResponse.schematic()

        %{"command" => "initialize"} ->
          GenDAP.Requests.InitializeResponse.schematic()

        %{"command" => "launch"} ->
          GenDAP.Requests.LaunchResponse.schematic()

        %{"command" => "loadedSources"} ->
          GenDAP.Requests.LoadedSourcesResponse.schematic()

        %{"command" => "locations"} ->
          GenDAP.Requests.LocationsResponse.schematic()

        %{"command" => "modules"} ->
          GenDAP.Requests.ModulesResponse.schematic()

        %{"command" => "next"} ->
          GenDAP.Requests.NextResponse.schematic()

        %{"command" => "pause"} ->
          GenDAP.Requests.PauseResponse.schematic()

        %{"command" => "readMemory"} ->
          GenDAP.Requests.ReadMemoryResponse.schematic()

        %{"command" => "restart"} ->
          GenDAP.Requests.RestartResponse.schematic()

        %{"command" => "restartFrame"} ->
          GenDAP.Requests.RestartFrameResponse.schematic()

        %{"command" => "reverseContinue"} ->
          GenDAP.Requests.ReverseContinueResponse.schematic()

        %{"command" => "runInTerminal"} ->
          GenDAP.Requests.RunInTerminalResponse.schematic()

        %{"command" => "scopes"} ->
          GenDAP.Requests.ScopesResponse.schematic()

        %{"command" => "setBreakpoints"} ->
          GenDAP.Requests.SetBreakpointsResponse.schematic()

        %{"command" => "setDataBreakpoints"} ->
          GenDAP.Requests.SetDataBreakpointsResponse.schematic()

        %{"command" => "setExceptionBreakpoints"} ->
          GenDAP.Requests.SetExceptionBreakpointsResponse.schematic()

        %{"command" => "setExpression"} ->
          GenDAP.Requests.SetExpressionResponse.schematic()

        %{"command" => "setFunctionBreakpoints"} ->
          GenDAP.Requests.SetFunctionBreakpointsResponse.schematic()

        %{"command" => "setInstructionBreakpoints"} ->
          GenDAP.Requests.SetInstructionBreakpointsResponse.schematic()

        %{"command" => "setVariable"} ->
          GenDAP.Requests.SetVariableResponse.schematic()

        %{"command" => "source"} ->
          GenDAP.Requests.SourceResponse.schematic()

        %{"command" => "stackTrace"} ->
          GenDAP.Requests.StackTraceResponse.schematic()

        %{"command" => "startDebugging"} ->
          GenDAP.Requests.StartDebuggingResponse.schematic()

        %{"command" => "stepBack"} ->
          GenDAP.Requests.StepBackResponse.schematic()

        %{"command" => "stepIn"} ->
          GenDAP.Requests.StepInResponse.schematic()

        %{"command" => "stepInTargets"} ->
          GenDAP.Requests.StepInTargetsResponse.schematic()

        %{"command" => "stepOut"} ->
          GenDAP.Requests.StepOutResponse.schematic()

        %{"command" => "terminate"} ->
          GenDAP.Requests.TerminateResponse.schematic()

        %{"command" => "terminateThreads"} ->
          GenDAP.Requests.TerminateThreadsResponse.schematic()

        %{"command" => "threads"} ->
          GenDAP.Requests.ThreadsResponse.schematic()

        %{"command" => "variables"} ->
          GenDAP.Requests.VariablesResponse.schematic()

        %{"command" => "writeMemory"} ->
          GenDAP.Requests.WriteMemoryResponse.schematic()

        _ ->
          {:error, "unexpected response payload"}
      end),
      request
    )
  end
end
