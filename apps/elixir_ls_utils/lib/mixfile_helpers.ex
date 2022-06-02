defmodule ElixirLS.Utils.MixfileHelpers do
  def mix_exs do
    System.get_env("MIX_EXS") || "mix.exs"
  end
end
