# Main entrypoint of language server script.
# This is distributed as an Elixir script because
# we don't want to deal with the complexities of maintaining
# parallel scripts for Unix and NT like environments. Going
# to Elixir helps a lot :)

### Step one: compile our application.

defmodule Eels.StartupHelper do
  def collect(path) do
    {:ok, files_and_dirs} = File.ls(path)
    result = Enum.group_by(files_and_dirs, fn f ->
      full_path = pathen(path, f)
      cond do
        File.dir?(full_path) -> :dir
        String.ends_with?(full_path, ".ex") -> :src
        true -> :rest
      end
    end)
    sources = get_full_paths(path, result, :src)
    dirs = (get_full_paths(path, result, :dir))

    recursive = Enum.flat_map(dirs, fn dir ->
      IO.puts("  recurse into #{inspect dir}")
      collect(dir)
    end)

    sources ++ recursive
  end

  defp get_full_paths(base, map, key) do
    names = Map.get(map, key, [])
    Enum.map(names, fn name -> pathen(base, name) end)
  end

  defp pathen(base, name) do
    base <> "/" <> name
  end
end

names = Eels.StartupHelper.collect("lib/eels-0.1.0/priv/lib") # TODO make version variable
IO.puts("Collected: #{inspect names}") # TODO make version variable
result = Kernel.ParallelCompiler.compile(names)
IO.puts("Result: #{inspect result}")

### Step two: start our application

Eels.Application.start()
