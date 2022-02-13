defmodule ElixirLS.Debugger.Protocol do
  @moduledoc """
  Macros for VS Code debug protocol requests

  These macros can be used for pattern matching against incoming requests, or for creating request
  messages for use in tests.
  """
  import ElixirLS.Debugger.Protocol.Basic

  defmacro __using__(_) do
    quote do
      import ElixirLS.Debugger.Protocol.Basic
      import unquote(__MODULE__)
    end
  end

  defmacro initialize_req(seq, client_info) do
    quote do
      request(unquote(seq), "initialize", unquote(client_info))
    end
  end

  defmacro launch_req(seq, config) do
    quote do
      request(unquote(seq), "launch", unquote(config))
    end
  end

  defmacro set_breakpoints_req(seq, source, breakpoints) do
    quote do
      request(unquote(seq), "setBreakpoints", %{
        "source" => unquote(source),
        "breakpoints" => unquote(breakpoints)
      })
    end
  end

  defmacro set_function_breakpoints_req(seq, breakpoints) do
    quote do
      request(unquote(seq), "setFunctionBreakpoints", %{
        "breakpoints" => unquote(breakpoints)
      })
    end
  end

  defmacro configuration_done_req(seq) do
    quote do
      request(unquote(seq), "configurationDone")
    end
  end

  defmacro threads_req(seq) do
    quote do
      request(unquote(seq), "threads")
    end
  end

  defmacro terminate_threads_req(seq, thread_ids) do
    quote do
      request(unquote(seq), "terminateThreads", %{"threadIds" => unquote(thread_ids)})
    end
  end

  defmacro pause_req(seq, thread_id) do
    quote do
      request(unquote(seq), "pause", %{"threadId" => unquote(thread_id)})
    end
  end

  defmacro stacktrace_req(seq, thread_id) do
    quote do
      request(unquote(seq), "stackTrace", %{"threadId" => unquote(thread_id)})
    end
  end

  defmacro scopes_req(seq, frame_id) do
    quote do
      request(unquote(seq), "scopes", %{"frameId" => unquote(frame_id)})
    end
  end

  defmacro vars_req(seq, var_id) do
    quote do
      request(unquote(seq), "variables", %{"variablesReference" => unquote(var_id)})
    end
  end

  defmacro continue_req(seq, thread_id) do
    quote do
      request(unquote(seq), "continue", %{"threadId" => unquote(thread_id)})
    end
  end

  defmacro next_req(seq, thread_id) do
    quote do
      request(unquote(seq), "next", %{"threadId" => unquote(thread_id)})
    end
  end

  defmacro step_in_req(seq, thread_id) do
    quote do
      request(unquote(seq), "stepIn", %{"threadId" => unquote(thread_id)})
    end
  end

  defmacro step_out_req(seq, thread_id) do
    quote do
      request(unquote(seq), "stepOut", %{"threadId" => unquote(thread_id)})
    end
  end
end
