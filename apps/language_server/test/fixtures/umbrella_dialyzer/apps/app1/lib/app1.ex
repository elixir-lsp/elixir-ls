defmodule App1 do
  def check_error() do
    :ok = App2.error()
  end
end
