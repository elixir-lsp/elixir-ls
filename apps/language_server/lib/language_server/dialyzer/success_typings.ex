defmodule ElixirLS.LanguageServer.Dialyzer.SuccessTypings do
  alias ElixirLS.LanguageServer.SourceFile
  require Logger

  def suggest_contracts(plt, files) do
    {us, results} =
      :timer.tc(fn ->
        modules =
          plt
          |> :dialyzer_plt.all_modules()
          |> :sets.to_list()

        # TODO filter by apps?        
        for mod <- modules,
            file = source(mod),
            file in files,
            docs = ElixirSense.Core.Normalized.Code.get_docs(mod, :docs),
            {{^mod, fun, arity} = mfa, success_typing} <- success_typings(plt, mod),
            :dialyzer_plt.lookup_contract(plt, mfa) == :none,
            {stripped_fun, stripped_arity} = SourceFile.strip_macro_prefix({fun, arity}),
            line = SourceFile.function_line(mod, stripped_fun, stripped_arity, docs),
            is_integer(line) and line > 0,
            do:
              {file, line, {mod, stripped_fun, stripped_arity}, success_typing,
               stripped_fun != fun}
      end)

    Logger.info("Success typings computed in #{div(us, 1000)}ms")
    results
  end

  defp source(module) do
    if Code.ensure_loaded?(module) do
      source = module.module_info(:compile)[:source]
      if is_list(source), do: List.to_string(source)
    end
  end

  defp success_typings(plt, mod) do
    case :dialyzer_plt.lookup_module(plt, mod) do
      {:value, list} ->
        for {{module, fun, arity}, ret, args} <- list, into: %{} do
          t = :erl_types.t_fun(args, ret)
          sig = :dialyzer_utils.format_sig(t)
          {{module, fun, arity}, sig}
        end
    end
  end
end
