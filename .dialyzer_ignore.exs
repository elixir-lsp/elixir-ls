[
  {"lib/launch.ex", :unknown_function},
  # :int and :dbg_iserver live in the OTP :debugger application which Mix sometimes fails to discover for PLT building.
  {"lib/debug_adapter/server.ex", :unknown_function},
  {"lib/debug_adapter/stacktrace.ex", :unknown_function},
  {"lib/language_server/providers/execute_command/restart.ex", :no_return},
  # @erlang_ex_doc? is true on OTP >= 27. Else branches needed for OTP 26 but appear dead when compiled on OTP 27+.
  {"lib/language_server/markdown_utils.ex", :pattern_match},
  # Conditional Code.ensure_loaded?/Version.match? branches that dialyzer evaluates statically based on the build environment.
  {"lib/launch.ex", :pattern_match},
  # Code.Fragment.cursor_context/1 spec in Elixir 1.20 omits :capture_arg, but runtime may still emit it.
  {"lib/completion_engine.ex", :pattern_match},
  {"lib/language_server/parser.ex", :pattern_match},
  # Defensive catch-all rescue clause for Phoenix tokenizer errors that may surface when Phoenix is loaded
  {"lib/language_server/parser.ex", :pattern_match_cov},
  {"lib/language_server/providers/hover/docs.ex", :pattern_match},
  # `Logger.configure(level: :none)` works at runtime (Logger passes `:none` through to
  # `:logger.set_primary_config/2`) but Logger's `level()` type doesn't list `:none`.
  {"lib/debug_adapter/server.ex", :call},
  # `:export`/`:runtime` branches in transitive-dep computation are currently unreachable
  # (all callers pass `:compile`) but are kept for the future `transitive: :runtime` /
  # `transitive: :export` tool capability.
  {"lib/language_server/providers/execute_command/llm_module_dependencies.ex", :pattern_match}
]
