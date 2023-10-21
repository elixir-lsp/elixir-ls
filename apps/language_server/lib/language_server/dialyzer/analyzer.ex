defmodule ElixirLS.LanguageServer.Dialyzer.Analyzer do
  require Record
  require Logger
  alias ElixirLS.LanguageServer.JsonRpc

  # warn_race_condition is unsupported because it greatly increases analysis time
  # OTP 25 dropped support for warn_race_condition
  # see https://github.com/erlang/otp/commit/74c65fbb588b98ee24df9f7302a43552178dfac2
  # TODO remove this comment when OTP >= 25 is required

  # default warns taken from
  # https://github.com/erlang/otp/blob/4ed7957623e5ccbd420a09a506bd6bc9930fe93c/lib/dialyzer/src/dialyzer_options.erl#L34
  # macros defined in https://github.com/erlang/otp/blob/4ed7957623e5ccbd420a09a506bd6bc9930fe93c/lib/dialyzer/src/dialyzer.hrl#L36
  # as of OTP 25
  @default_warns [
    :warn_behaviour,
    :warn_bin_construction,
    :warn_callgraph,
    :warn_contract_range,
    :warn_contract_syntax,
    :warn_contract_types,
    :warn_failing_call,
    :warn_fun_app,
    :warn_map_construction,
    :warn_matching,
    :warn_non_proper_list,
    :warn_not_called,
    :warn_opaque,
    :warn_return_no_exit,
    :warn_undefined_callbacks
  ]
  @non_default_warns [
                       :warn_contract_not_equal,
                       :warn_contract_subtype,
                       :warn_contract_supertype,
                       :warn_return_only_exit,
                       :warn_umatched_return,
                       :warn_unknown
                     ] ++
                       (if String.to_integer(System.otp_release()) >= 25 do
                          [
                            # OTP >= 25 options
                            :warn_contract_missing_return,
                            :warn_contract_extra_return
                          ]
                        else
                          []
                        end)
  @log_cache_length 10

  defstruct [
    :backend_pid,
    :code_server,
    :mod_deps,
    external_calls: [],
    external_types: [],
    warnings: [],
    log_cache: []
  ]

  Record.defrecordp(
    :analysis_24,
    :analysis,
    analysis_pid: :undefined,
    type: :succ_typings,
    defines: [],
    doc_plt: :undefined,
    files: [],
    include_dirs: [],
    start_from: :byte_code,
    plt: :undefined,
    use_contracts: true,
    race_detection: false,
    behaviours_chk: false,
    timing: false,
    timing_server: :none,
    callgraph_file: [],
    solvers: :undefined
  )

  Record.defrecordp(
    :analysis_25,
    :analysis,
    analysis_pid: :undefined,
    type: :succ_typings,
    defines: [],
    doc_plt: :undefined,
    files: [],
    include_dirs: [],
    start_from: :byte_code,
    plt: :undefined,
    use_contracts: true,
    behaviours_chk: false,
    timing: false,
    timing_server: :none,
    callgraph_file: [],
    solvers: :undefined
  )

  Record.defrecordp(
    :analysis_26,
    :analysis,
    analysis_pid: :undefined,
    type: :succ_typings,
    defines: [],
    doc_plt: :undefined,
    files: [],
    include_dirs: [],
    start_from: :byte_code,
    plt: :undefined,
    use_contracts: true,
    behaviours_chk: false,
    timing: false,
    timing_server: :none,
    callgraph_file: [],
    mod_deps_file: [],
    solvers: :undefined
  )

  def analyze(active_plt, []) do
    {active_plt, %{}, []}
  end

  def analyze(active_plt, files) do
    analysis_config =
      case System.otp_release() |> String.to_integer() do
        ver when ver < 25 ->
          analysis_24(
            plt: active_plt,
            files: files,
            solvers: []
          )

        25 ->
          analysis_25(
            plt: active_plt,
            files: files,
            solvers: []
          )

        _ ->
          analysis_26(
            plt: active_plt,
            files: files,
            solvers: []
          )
      end

    parent = self()

    pid =
      spawn_link(fn ->
        :dialyzer_analysis_callgraph.start(
          parent,
          @default_warns ++ @non_default_warns,
          analysis_config
        )
      end)

    state = %__MODULE__{backend_pid: pid}
    main_loop(state)
  end

  def matching_tags(warn_opts) do
    :dialyzer_options.build_warnings(warn_opts, @default_warns)
  end

  defp main_loop(%__MODULE__{backend_pid: backend_pid} = state) do
    receive do
      {^backend_pid, :log, log_msg} ->
        state = update_in(state.log_cache, &Enum.slice([log_msg | &1], 0, @log_cache_length))
        main_loop(state)

      {^backend_pid, :warnings, warnings} ->
        state = update_in(state.warnings, &(&1 ++ warnings))
        main_loop(state)

      {^backend_pid, :cserver, code_server, _plt} ->
        state = put_in(state.code_server, code_server)
        main_loop(state)

      {^backend_pid, :done, new_plt, _new_doc_plt} ->
        {new_plt, state.mod_deps, state.warnings}

      {^backend_pid, :ext_calls, ext_calls} ->
        state = put_in(state.external_calls, ext_calls)
        main_loop(state)

      {^backend_pid, :ext_types, ext_types} ->
        state = put_in(state.external_types, ext_types)
        main_loop(state)

      {^backend_pid, :mod_deps, mod_deps_dict} ->
        mod_deps = mod_deps_dict |> :dict.to_list() |> Enum.into(%{})
        state = put_in(state.mod_deps, mod_deps)
        main_loop(state)

      {:EXIT, ^backend_pid, {:error, reason}} ->
        print_failure(reason, state.log_cache)

      {:EXIT, ^backend_pid, reason} when reason != :normal ->
        print_failure(reason, state.log_cache)

      _ ->
        main_loop(state)
    end
  end

  defp print_failure(reason, log_cache) do
    message =
      "Analysis failed: " <> Exception.format_exit(reason) <> "\n" <> Enum.join(log_cache, "\n")

    Logger.error(message)
    JsonRpc.telemetry("dialyzer_error", %{"elixir_ls.dialyzer_error" => message}, %{})
  end
end
