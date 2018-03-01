defmodule ElixirLS.Utils.Launch do
  @doc """
  This is an unfortunate hack to allow us to launch the language server or debugger using Mix
  without automatically loading the mixfile in the current directory (which is unsafe until we've
  called [ElixirLS.Utils.WireProtocol.intercept_output/2])

  The launcher script overrides MIX_EXS, but we can restore it from ELIXIR_LS_MIX_EXS once
  we've launched.
  """
  def restore_mix_exs_var do
    case System.get_env("ELIXIR_LS_MIX_EXS") do
      nil -> System.delete_env("MIX_EXS")
      "" -> System.delete_env("MIX_EXS")
      mix_exs -> System.put_env("MIX_EXS", mix_exs)
    end

    System.delete_env("ELIXIR_LS_MIX_EXS")
  end
end
