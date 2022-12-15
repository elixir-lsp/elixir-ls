defmodule Mix.Tasks.Lsp.DataModel.Notification do
  defstruct [:method, :direction, :params, :documentation]
end
