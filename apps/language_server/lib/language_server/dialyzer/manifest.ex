defmodule ElixirLS.LanguageServer.Dialyzer.Manifest do
  import Record

  defrecord(:plt, [:info, :types, :contracts, :callbacks, :exported_types])

  def otp_vsn() do
    major = :erlang.system_info(:otp_release) |> List.to_string()
    vsn_file = Path.join([:code.root_dir(), "releases", major, "OTP_VERSION"])

    try do
      {:ok, contents} = File.read(vsn_file)
      String.split(contents, ["\r\n", "\r", "\n"], trim: true)
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

  def transfer_plt(active_plt, pid) do
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
