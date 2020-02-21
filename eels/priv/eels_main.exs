# Main entrypoint of language server script.
# This is distributed as an Elixir script because
# we don't want to deal with the complexities of maintaining
# parallel scripts for Unix and NT like environments. Going
# to Elixir helps a lot :)

eels = "eels-0.1.0" # TODO can we dynamically figure this out? Template?

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

names = Eels.StartupHelper.collect("lib/#{eels}/priv/lib")
{:ok, _, _} = Kernel.ParallelCompiler.compile(names)

### Step two: Load and start our application

# TODO is there a quicker way to get the app spec parsed and loaded?
app_spec_src = File.read!("lib/#{eels}/ebin/eels.app")
{:ok, app_spec_tokens, _} = :erl_scan.string(String.to_charlist(app_spec_src))
{:ok, app_spec} = :erl_parse.parse_term(app_spec_tokens)
:ok = :application.load(app_spec)

# All done, start the thing.
:ok = :application.start(:eels, :permanent)
