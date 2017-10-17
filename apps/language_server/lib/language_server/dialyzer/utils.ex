defmodule ElixirLS.LanguageServer.Dialyzer.Utils do
  def pathname_to_module(path) do
    String.to_atom(Path.basename(path, ".beam"))
  end

  def expand_references(modules, exclude \\ [], result \\ MapSet.new())

  def expand_references([], _, result) do
    result
  end

  def expand_references([module | rest], exclude, result) do
    result =
      if module in result or module in exclude do
        result
      else
        result = MapSet.put(result, module)
        expand_references(module_references(module), exclude, result)
      end

    expand_references(rest, exclude, result)
  end

  defp module_references(mod) do
    try do
      forms = :forms.read(mod)

      calls =
        :forms.filter(
          fn
            {:call, _, {:remote, _, {:atom, _, _}, _}, _} -> true
            _ -> false
          end,
          forms
        )

      modules = for {:call, _, {:remote, _, {:atom, _, module}, _}, _} <- calls, do: module
      Enum.uniq(modules)
    rescue
      _ -> []
    catch
      _ -> []
    end
  end
end
