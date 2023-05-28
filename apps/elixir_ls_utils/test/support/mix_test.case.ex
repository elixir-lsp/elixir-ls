defmodule ElixirLS.Utils.MixTest.Case do
  # This module is based heavily on MixTest.Case in Elixir's tests
  # https://github.com/elixir-lang/elixir/blob/db64b413a036c01c8e1cac8dd5e1c65107d90176/lib/mix/test/test_helper.exs#L29
  use ExUnit.CaseTemplate

  using do
    quote do
      import ElixirLS.Utils.MixTest.Case
    end
  end

  @apps Enum.map(Application.loaded_applications(), &elem(&1, 0))
  @allowed_apps ~w(
    iex
    elixir_sense
    elixir_ls_debugger
    elixir_ls_utils
    language_server
    stream_data
    statistex
    patch
    deep_merge
    erlex
    benchee
    path_glob_vendored
    dialyzer
    dialyxir_vendored
    erl2ex
    jason_v
    sourceror
    )a

  setup do
    on_exit(fn ->
      Application.start(:logger)
      Mix.env(:dev)
      Mix.target(:host)
      Mix.Task.clear()
      Mix.Shell.Process.flush()
      Mix.State.clear_cache()
      Mix.ProjectStack.clear_stack()
      delete_tmp_paths()

      for {app, _, _} <- Application.loaded_applications(),
          app not in @apps,
          app not in @allowed_apps do
        Application.stop(app)
        Application.unload(app)
      end
    end)

    :ok
  end

  def fixture_path(dir) do
    Path.expand("fixtures", dir)
  end

  def fixture_path(dir, extension) do
    Path.join(fixture_path(dir), remove_colons(extension))
  end

  def tmp_path do
    Path.expand("../../.tmp", __DIR__)
  end

  def tmp_path(extension) do
    Path.join(tmp_path(), remove_colons(extension))
  end

  defp remove_colons(term) do
    term
    |> to_string()
    |> String.replace(":", "")
  end

  def purge(modules) do
    Enum.each(modules, fn m ->
      :code.purge(m)
      :code.delete(m)
    end)
  end

  def in_tmp(which, function) do
    path = tmp_path(which)
    File.rm_rf!(path)
    File.mkdir_p!(path)
    File.cd!(path, function)
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

    try do
      File.cd!(dest, function)
    after
      :code.set_path(get_path)

      for {mod, file} <- :code.all_loaded() -- previous,
          file == [] or (is_list(file) and List.starts_with?(file, flag)) do
        purge([mod])
      end
    end
  end

  defp delete_tmp_paths do
    tmp = tmp_path() |> String.to_charlist()
    for path <- :code.get_path(), :string.str(path, tmp) != 0, do: :code.del_path(path)
  end

  def capture_log_and_io(device, fun) when is_function(fun, 0) do
    # Logger gets stopped during some tests so restart it to be able to capture logs (and kept the
    # test output clean)
    Application.ensure_started(:logger)

    log =
      ExUnit.CaptureLog.capture_log(fn ->
        io = ExUnit.CaptureIO.capture_io(device, fun)
        send(self(), {:block_result, io})
      end)

    assert_received {:block_result, io_result}
    {log, io_result}
  end
end
