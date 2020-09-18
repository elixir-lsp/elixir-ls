defmodule ElixirLS.Utils.MixTest.Case do
  # This module is based heavily on MixTest.Case in Elixir's tests
  use ExUnit.CaseTemplate

  using do
    quote do
      import ElixirLS.Utils.MixTest.Case
    end
  end

  setup config do
    if apps = config[:apps] do
      Logger.remove_backend(:console)
    end

    on_exit(fn ->
      Application.start(:logger)
      Mix.Task.clear()
      Mix.Shell.Process.flush()
      delete_tmp_paths()

      if apps do
        for app <- apps do
          Application.stop(app)
          Application.unload(app)
        end

        Logger.add_backend(:console, flush: true)
      end
    end)

    :ok
  end

  def fixture_path(dir, extension) do
    Path.join(Path.expand("fixtures", dir), extension)
  end

  def tmp_path do
    Path.expand("../tmp", __DIR__)
  end

  def tmp_path(extension) do
    Path.join(tmp_path(), to_string(extension))
  end

  def purge(modules) do
    Enum.each(modules, fn m ->
      :code.purge(m)
      :code.delete(m)
    end)
  end

  defmacro in_fixture(dir, which, block) do
    module = inspect(__CALLER__.module)
    function = Atom.to_string(elem(__CALLER__.function, 0))
    tmp = Path.join(module, function)

    quote do
      unquote(__MODULE__).in_fixture(unquote(dir), unquote(which), unquote(tmp), unquote(block))
    end
  end

  def in_fixture(dir, which, tmp, function) do
    src = fixture_path(dir, which)
    dest = tmp_path(String.replace(tmp, ":", "_"))
    flag = String.to_charlist(tmp_path())

    File.rm_rf!(dest)
    File.mkdir_p!(dest)
    File.cp_r!(src, dest)

    get_path = :code.get_path()
    previous = :code.all_loaded()
    project_stack = clear_project_stack!()

    try do
      File.cd!(dest, function)
    after
      :code.set_path(get_path)

      for {mod, file} <- :code.all_loaded() -- previous,
          file == :in_memory or file == [] or (is_list(file) and :lists.prefix(flag, file)) do
        mod
      end
      |> purge

      restore_project_stack!(project_stack)
    end
  end

  defp delete_tmp_paths do
    tmp = tmp_path() |> String.to_charlist()
    for path <- :code.get_path(), :string.str(path, tmp) != 0, do: :code.del_path(path)
  end

  defp clear_project_stack! do
    stack = clear_project_stack!([])

    clear_mix_cache()

    # Attempt to purge mixfiles for dependencies to avoid module redefinition warnings
    mix_exs = System.get_env("MIX_EXS") || "mix.exs"

    for {mod, :in_memory} <- :code.all_loaded(),
        source = mod.module_info[:compile][:source],
        is_list(source),
        String.ends_with?(to_string(source), mix_exs),
        do: purge([mod])

    stack
  end

  defp clear_project_stack!(stack) do
    # FIXME: Private API
    case Mix.Project.pop() do
      nil ->
        stack

      project ->
        clear_project_stack!([project | stack])
    end
  end

  defp restore_project_stack!(stack) do
    # FIXME: Private API
    Mix.ProjectStack.clear_stack()
    clear_mix_cache()

    for %{name: module, file: file} <- stack do
      :code.purge(module)
      :code.delete(module)
      # It's important to use `compile_file` here instead of `require_file`
      # because we are recompiling this file to reload the mix project back onto
      # the project stack.
      Code.compile_file(file)
    end
  end

  # FIXME: Private API
  defp clear_mix_cache do
    module =
      if Version.match?(System.version(), ">= 1.10.0") do
        Mix.State
      else
        Mix.ProjectStack
      end

    module.clear_cache()
  end
end
