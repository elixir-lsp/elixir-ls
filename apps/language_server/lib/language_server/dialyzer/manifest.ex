defmodule ElixirLS.LanguageServer.Dialyzer.Manifest do
  alias ElixirLS.LanguageServer.{Dialyzer, JsonRpc}
  import Record
  import Dialyzer.Utils
  require Logger

  @manifest_vsn :v2

  defrecord(:plt, [:info, :types, :contracts, :callbacks, :exported_types])

  def build_new_manifest() do
    parent = self()

    spawn_link(fn ->
      active_plt = load_elixir_plt()
      transfer_plt(active_plt, parent)

      Dialyzer.analysis_finished(parent, :noop, active_plt, %{}, %{}, %{}, nil, nil)
    end)
  end

  def write(_, _, _, _, _, nil) do
    nil
  end

  def write(root_path, active_plt, mod_deps, md5, warnings, timestamp) do
    Task.start_link(fn ->
      manifest_path = manifest_path(root_path)

      plt(
        info: info,
        types: types,
        contracts: contracts,
        callbacks: callbacks,
        exported_types: exported_types
      ) = active_plt

      manifest_data = {
        @manifest_vsn,
        mod_deps,
        md5,
        warnings,
        :ets.tab2list(info),
        :ets.tab2list(types),
        :ets.tab2list(contracts),
        :ets.tab2list(callbacks),
        :ets.tab2list(exported_types)
      }

      # Because the manifest file can be several megabytes, we do a write-then-rename
      # to reduce the likelihood of corrupting the manifest
      JsonRpc.log_message(:info, "[ElixirLS Dialyzer] Writing manifest...")
      File.mkdir_p!(Path.dirname(manifest_path))
      tmp_manifest_path = manifest_path <> ".new"
      File.write!(tmp_manifest_path, :erlang.term_to_binary(manifest_data, compressed: 9))
      File.rename(tmp_manifest_path, manifest_path)
      File.touch!(manifest_path, timestamp)
      JsonRpc.log_message(:info, "[ElixirLS Dialyzer] Done writing manifest.")
    end)
  end

  def read(root_path) do
    manifest_path = manifest_path(root_path)
    timestamp = normalize_timestamp(Mix.Utils.last_modified(manifest_path))

    {
      @manifest_vsn,
      mod_deps,
      md5,
      warnings,
      info_list,
      types_list,
      contracts_list,
      callbacks_list,
      exported_types_list
    } = File.read!(manifest_path) |> :erlang.binary_to_term()

    plt(
      info: info,
      types: types,
      contracts: contracts,
      callbacks: callbacks,
      exported_types: exported_types
    ) = active_plt = :dialyzer_plt.new()

    for item <- info_list, do: :ets.insert(info, item)
    for item <- types_list, do: :ets.insert(types, item)
    for item <- contracts_list, do: :ets.insert(contracts, item)
    for item <- callbacks_list, do: :ets.insert(callbacks, item)
    for item <- exported_types_list, do: :ets.insert(exported_types, item)
    {:ok, active_plt, mod_deps, md5, warnings, timestamp}
  rescue
    _ ->
      :error
  end

  def load_elixir_plt() do
    :dialyzer_plt.from_file(to_charlist(elixir_plt_path()))
  rescue
    _ -> build_elixir_plt()
  catch
    _ -> build_elixir_plt()
  end

  def elixir_plt_path() do
    Path.join([Mix.Utils.mix_home(), "elixir-ls-#{otp_vsn()}_elixir-#{System.version()}"])
  end

  defp build_elixir_plt() do
    JsonRpc.show_message(:info, "Building core Elixir PLT. This will take a few minutes.")

    files =
      Path.join([Application.app_dir(:elixir), "**/*.beam"])
      |> Path.wildcard()
      |> Enum.map(&pathname_to_module/1)
      |> expand_references()
      |> Enum.map(&:code.which/1)
      |> Enum.filter(&is_list/1)

    File.mkdir_p!(Path.dirname(elixir_plt_path()))

    :dialyzer.run(
      analysis_type: :plt_build,
      files: files,
      from: :byte_code,
      output_plt: to_charlist(elixir_plt_path())
    )

    JsonRpc.show_message(:info, "Saved Elixir PLT to #{elixir_plt_path()}")
    :dialyzer_plt.from_file(to_charlist(elixir_plt_path()))
  end

  defp otp_vsn() do
    major = :erlang.system_info(:otp_release) |> List.to_string()
    vsn_file = Path.join([:code.root_dir(), "releases", major, "OTP_VERSION"])

    try do
      {:ok, contents} = File.read(vsn_file)
      String.split(contents, "\n", trim: true)
    else
      [full] ->
        full

      _ ->
        major
    catch
      :error, _ ->
        major
    end
  end

  defp manifest_path(root_path) do
    Path.join([
      root_path,
      ".elixir_ls/dialyzer_manifest_#{otp_vsn()}_elixir-#{System.version()}_#{Mix.env()}"
    ])
  end

  defp transfer_plt(active_plt, pid) do
    plt(
      info: info,
      types: types,
      contracts: contracts,
      callbacks: callbacks,
      exported_types: exported_types
    ) = active_plt

    for table <- [info, types, contracts, callbacks, exported_types] do
      :ets.give_away(table, pid, nil)
    end
  end
end
