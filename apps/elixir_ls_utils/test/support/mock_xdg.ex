defmodule ElixirLS.Utils.Test.MockXDG do
  def read_elixir_ls_config_file(_) do
    {:error, :enoent}
  end
end
