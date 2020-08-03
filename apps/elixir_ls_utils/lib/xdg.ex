defmodule ElixirLS.Utils.XDG do
  @moduledoc """
  Utilities for reading files within ElixirLS's XDG configuration directory
  """

  @default_xdg_directory "$HOME/.config"

  def read_elixir_ls_config_file(path) do
    xdg_directory()
    |> Path.join("elixir_ls")
    |> Path.join(path)
    |> File.read()
    |> case do
      {:ok, file_contents} -> {:ok, file_contents}
      err -> err
    end
  end

  defp xdg_directory do
    case System.get_env("XDG_CONFIG_HOME") do
      nil ->
        @default_xdg_directory

      xdg_directory ->
        if File.dir?(xdg_directory) do
          xdg_directory
        else
          raise "$XDG_CONFIG_HOME environment variable set, but directory does not exist"
        end
    end
  end
end
