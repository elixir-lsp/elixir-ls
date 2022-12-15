defmodule Mix.Tasks.Lsp.DataModel.Request do
  defstruct [:method, :result, :direction, :params]
end
