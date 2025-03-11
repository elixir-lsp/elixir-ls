# codegen: do not edit
defmodule GenDAP.Requests do
  import Schematic

  def new(request) do
    unify(oneof(fn
      
        %{"command" => "attach"} -> GenDAP.Requests.Attach.schematic()
      
        %{"command" => "breakpointLocations"} -> GenDAP.Requests.BreakpointLocations.schematic()
      
        %{"command" => "cancel"} -> GenDAP.Requests.Cancel.schematic()
      
        %{"command" => "completions"} -> GenDAP.Requests.Completions.schematic()
      
        %{"command" => "configurationDone"} -> GenDAP.Requests.ConfigurationDone.schematic()
      
        %{"command" => "continue"} -> GenDAP.Requests.Continue.schematic()
      
        %{"command" => "dataBreakpointInfo"} -> GenDAP.Requests.DataBreakpointInfo.schematic()
      
        %{"command" => "disassemble"} -> GenDAP.Requests.Disassemble.schematic()
      
        %{"command" => "disconnect"} -> GenDAP.Requests.Disconnect.schematic()
      
        %{"command" => "evaluate"} -> GenDAP.Requests.Evaluate.schematic()
      
        %{"command" => "exceptionInfo"} -> GenDAP.Requests.ExceptionInfo.schematic()
      
        %{"command" => "goto"} -> GenDAP.Requests.Goto.schematic()
      
        %{"command" => "gotoTargets"} -> GenDAP.Requests.GotoTargets.schematic()
      
        %{"command" => "initialize"} -> GenDAP.Requests.Initialize.schematic()
      
        %{"command" => "launch"} -> GenDAP.Requests.Launch.schematic()
      
        %{"command" => "loadedSources"} -> GenDAP.Requests.LoadedSources.schematic()
      
        %{"command" => "locations"} -> GenDAP.Requests.Locations.schematic()
      
        %{"command" => "modules"} -> GenDAP.Requests.Modules.schematic()
      
        %{"command" => "next"} -> GenDAP.Requests.Next.schematic()
      
        %{"command" => "pause"} -> GenDAP.Requests.Pause.schematic()
      
        %{"command" => "readMemory"} -> GenDAP.Requests.ReadMemory.schematic()
      
        %{"command" => "restart"} -> GenDAP.Requests.Restart.schematic()
      
        %{"command" => "restartFrame"} -> GenDAP.Requests.RestartFrame.schematic()
      
        %{"command" => "reverseContinue"} -> GenDAP.Requests.ReverseContinue.schematic()
      
        %{"command" => "runInTerminal"} -> GenDAP.Requests.RunInTerminal.schematic()
      
        %{"command" => "scopes"} -> GenDAP.Requests.Scopes.schematic()
      
        %{"command" => "setBreakpoints"} -> GenDAP.Requests.SetBreakpoints.schematic()
      
        %{"command" => "setDataBreakpoints"} -> GenDAP.Requests.SetDataBreakpoints.schematic()
      
        %{"command" => "setExceptionBreakpoints"} -> GenDAP.Requests.SetExceptionBreakpoints.schematic()
      
        %{"command" => "setExpression"} -> GenDAP.Requests.SetExpression.schematic()
      
        %{"command" => "setFunctionBreakpoints"} -> GenDAP.Requests.SetFunctionBreakpoints.schematic()
      
        %{"command" => "setInstructionBreakpoints"} -> GenDAP.Requests.SetInstructionBreakpoints.schematic()
      
        %{"command" => "setVariable"} -> GenDAP.Requests.SetVariable.schematic()
      
        %{"command" => "source"} -> GenDAP.Requests.Source.schematic()
      
        %{"command" => "stackTrace"} -> GenDAP.Requests.StackTrace.schematic()
      
        %{"command" => "startDebugging"} -> GenDAP.Requests.StartDebugging.schematic()
      
        %{"command" => "stepBack"} -> GenDAP.Requests.StepBack.schematic()
      
        %{"command" => "stepIn"} -> GenDAP.Requests.StepIn.schematic()
      
        %{"command" => "stepInTargets"} -> GenDAP.Requests.StepInTargets.schematic()
      
        %{"command" => "stepOut"} -> GenDAP.Requests.StepOut.schematic()
      
        %{"command" => "terminate"} -> GenDAP.Requests.Terminate.schematic()
      
        %{"command" => "terminateThreads"} -> GenDAP.Requests.TerminateThreads.schematic()
      
        %{"command" => "threads"} -> GenDAP.Requests.Threads.schematic()
      
        %{"command" => "variables"} -> GenDAP.Requests.Variables.schematic()
      
        %{"command" => "writeMemory"} -> GenDAP.Requests.WriteMemory.schematic()
      
        _ -> {:error, "unexpected request payload"}
    end), request)
  end
end
