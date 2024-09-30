defmodule ElixirLS.DebugAdapter.Code do
  if Version.match?(System.version(), ">= 1.14.0-dev") do
    defdelegate env_for_eval(env), to: Code
  else
    def env_for_eval(%{lexical_tracker: pid} = env) do
      new_env = %{
        env
        | context: nil,
          context_modules: [],
          macro_aliases: [],
          versioned_vars: %{}
      }

      if is_pid(pid) do
        if Process.alive?(pid) do
          new_env
        else
          IO.warn("""
          an __ENV__ with outdated compilation information was given to eval, \
          call Macro.Env.prune_compile_info/1 to prune it
          """)

          %{new_env | lexical_tracker: nil, tracers: []}
        end
      else
        %{new_env | tracers: []}
      end
    end

    def env_for_eval(opts) when is_list(opts) do
      env = :elixir_env.new()

      line =
        case Keyword.get(opts, :line) do
          line_opt when is_integer(line_opt) -> line_opt
          nil -> Map.get(env, :line)
        end

      file =
        case Keyword.get(opts, :file) do
          file_opt when is_binary(file_opt) -> file_opt
          nil -> Map.get(env, :file)
        end

      module =
        case Keyword.get(opts, :module) do
          module_opt when is_atom(module_opt) -> module_opt
          nil -> nil
        end

      fa =
        case Keyword.get(opts, :function) do
          {function, arity} when is_atom(function) and is_integer(arity) -> {function, arity}
          nil -> nil
        end

      temp_tracers =
        case Keyword.get(opts, :tracers) do
          tracers_opt when is_list(tracers_opt) -> tracers_opt
          nil -> []
        end

      aliases =
        case Keyword.get(opts, :aliases) do
          aliases_opt when is_list(aliases_opt) ->
            IO.warn(":aliases option in eval is deprecated")
            aliases_opt

          nil ->
            Map.get(env, :aliases)
        end

      requires =
        case Keyword.get(opts, :requires) do
          requires_opt when is_list(requires_opt) ->
            IO.warn(":requires option in eval is deprecated")
            MapSet.new(requires_opt)

          nil ->
            Map.get(env, :requires)
        end

      functions =
        case Keyword.get(opts, :functions) do
          functions_opt when is_list(functions_opt) ->
            IO.warn(":functions option in eval is deprecated")
            functions_opt

          nil ->
            Map.get(env, :functions)
        end

      macros =
        case Keyword.get(opts, :macros) do
          macros_opt when is_list(macros_opt) ->
            IO.warn(":macros option in eval is deprecated")
            macros_opt

          nil ->
            Map.get(env, :macros)
        end

      {lexical_tracker, tracers} =
        case Keyword.get(opts, :lexical_tracker) do
          pid when is_pid(pid) ->
            IO.warn(":lexical_tracker option in eval is deprecated")

            if Process.alive?(pid) do
              {pid, temp_tracers}
            else
              {nil, []}
            end

          nil ->
            IO.warn(":lexical_tracker option in eval is deprecated")
            {nil, []}

          _ ->
            {nil, temp_tracers}
        end

      %{
        env
        | file: file,
          module: module,
          function: fa,
          tracers: tracers,
          macros: macros,
          functions: functions,
          lexical_tracker: lexical_tracker,
          requires: requires,
          aliases: aliases,
          line: line
      }
    end
  end
end
