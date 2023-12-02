defmodule ElixirLS.DebugAdapter.Stacktrace do
  @moduledoc """
  Retrieves the stack trace for a process that's paused at a breakpoint
  """
  alias ElixirLS.DebugAdapter.Output
  alias ElixirLS.DebugAdapter.ModuleInfoCache

  defmodule Frame do
    defstruct [
      :level,
      :file,
      :module,
      :function,
      :args,
      :line,
      :bindings,
      :messages,
      {:dbg_frame?, false},
      :dbg_env
    ]

    def name(%__MODULE__{function: function} = frame) when not is_nil(function) do
      {f, a} = frame.function

      case a do
        :undefined -> "#{inspect(frame.module)}.#{f}/?"
        _ -> "#{inspect(frame.module)}.#{f}/#{a}"
      end
    end

    def name(%__MODULE__{} = frame) do
      "#{inspect(frame.module)}"
    end
  end

  def get(pid) do
    case :dbg_iserver.safe_call({:get_meta, pid}) do
      {:ok, meta_pid} ->
        [{level, {module, function, args}} | backtrace_rest] =
          :int.meta(meta_pid, :backtrace, :all)

        messages = :int.meta(meta_pid, :messages)

        first_frame = %Frame{
          level: level,
          module: module,
          function: {function, get_arity(args)},
          args: args,
          file: get_file(module),
          # vscode raises invalid request when line is nil
          line: break_line(pid) || 1,
          bindings: get_bindings(meta_pid, level),
          messages: messages
        }

        # If backtrace_rest is empty, calling stack_frames causes an exception
        other_frames =
          case backtrace_rest do
            [] ->
              []

            _ ->
              frames = List.zip([backtrace_rest, stack_frames(meta_pid, level)])

              for {{level, {mod, function, args}}, {level, {mod, line}, bindings}} <- frames do
                %Frame{
                  level: level,
                  module: mod,
                  function: {function, get_arity(args)},
                  args: args,
                  file: get_file(mod),
                  # vscode raises invalid request when line is nil
                  line: line || 1,
                  bindings: Enum.into(bindings, %{}),
                  messages: messages
                }
              end
          end

        [first_frame | other_frames]

      error ->
        Output.debugger_important(
          "Failed to obtain meta for pid #{inspect(pid)}: #{inspect(error)}"
        )

        []
    end
  end

  defp break_line(pid) do
    Enum.find_value(:int.snapshot(), fn
      {^pid, _init, :break, {_module, line}} -> line
      _ -> false
    end)
  end

  defp stack_frames(meta_pid, level) do
    frame = :int.meta(meta_pid, :stack_frame, {:up, level})

    case frame do
      {next_level, _, _} -> [frame | stack_frames(meta_pid, next_level)]
      _ -> []
    end
  end

  defp get_bindings(meta_pid, stack_level) do
    Enum.into(:int.meta(meta_pid, :bindings, stack_level), %{})
  end

  def get_file(module) do
    Path.expand(to_string(ModuleInfoCache.get(module)[:compile][:source]))
  end

  defp get_arity(:undefined), do: :undefined
  defp get_arity(args), do: Enum.count(args)
end
