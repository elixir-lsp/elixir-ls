defmodule ElixirLS.Utils.Config.SettingDef do
  @moduledoc """
  Defines attributes for an individual setting supported by ElixirLS.
  """

  @enforce_keys [:key, :json_key, :type, :default, :doc]
  defstruct [:key, :json_key, :type, :default, :doc]
end
