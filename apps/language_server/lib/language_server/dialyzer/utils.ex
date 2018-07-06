defmodule ElixirLS.LanguageServer.Dialyzer.Utils do
  @epoch_gregorian_seconds 62_167_219_200

  def dialyzable?(module) do
    file = :code.which(module)
    is_list(file) and match?({:ok, _}, :dialyzer_utils.get_core_from_beam(file))
  end

  def pathname_to_module(path) do
    String.to_atom(Path.basename(path, ".beam"))
  end

  def expand_references(modules, exclude \\ [], result \\ MapSet.new())

  def expand_references([], _, result) do
    result
  end

  def expand_references([module | rest], exclude, result) do
    result =
      if module in result or module in exclude or not dialyzable?(module) do
        result
      else
        result = MapSet.put(result, module)
        expand_references(module_references(module), exclude, result)
      end

    expand_references(rest, exclude, result)
  end

  # Mix.Utils.last_modified/1 returns a :calendar.universal_time() in Elixir < 1.7,
  # otherwise posix time, so we normalize to a :calendar.universal_time()
  def normalize_timestamp(timestamp) when is_integer(timestamp),
    do: :calendar.gregorian_seconds_to_datetime(timestamp + @epoch_gregorian_seconds)

  def normalize_timestamp(timestamp), do: timestamp

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
