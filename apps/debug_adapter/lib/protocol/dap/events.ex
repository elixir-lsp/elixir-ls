# codegen: do not edit
defmodule GenDAP.Events do
  import Schematic

  def new(event) do
    unify(oneof(fn
      
        %{"event" => "breakpoint"} -> GenDAP.Events.BreakpointEvent.schematic()
      
        %{"event" => "capabilities"} -> GenDAP.Events.CapabilitiesEvent.schematic()
      
        %{"event" => "continued"} -> GenDAP.Events.ContinuedEvent.schematic()
      
        %{"event" => "exited"} -> GenDAP.Events.ExitedEvent.schematic()
      
        %{"event" => "initialized"} -> GenDAP.Events.InitializedEvent.schematic()
      
        %{"event" => "invalidated"} -> GenDAP.Events.InvalidatedEvent.schematic()
      
        %{"event" => "loadedSource"} -> GenDAP.Events.LoadedSourceEvent.schematic()
      
        %{"event" => "memory"} -> GenDAP.Events.MemoryEvent.schematic()
      
        %{"event" => "module"} -> GenDAP.Events.ModuleEvent.schematic()
      
        %{"event" => "output"} -> GenDAP.Events.OutputEvent.schematic()
      
        %{"event" => "process"} -> GenDAP.Events.ProcessEvent.schematic()
      
        %{"event" => "progressEnd"} -> GenDAP.Events.ProgressEndEvent.schematic()
      
        %{"event" => "progressStart"} -> GenDAP.Events.ProgressStartEvent.schematic()
      
        %{"event" => "progressUpdate"} -> GenDAP.Events.ProgressUpdateEvent.schematic()
      
        %{"event" => "stopped"} -> GenDAP.Events.StoppedEvent.schematic()
      
        %{"event" => "terminated"} -> GenDAP.Events.TerminatedEvent.schematic()
      
        %{"event" => "thread"} -> GenDAP.Events.ThreadEvent.schematic()
      
        _ -> {:error, "unexpected event payload"}
    end), event)
  end
end
