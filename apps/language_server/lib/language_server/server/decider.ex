defmodule ElixirLS.LanguageServer.Server.Decider do
  @moduledoc """
  A module that determines if a message should be handled by
  the extant server or the experimental server
  """
  alias ElixirLS.LanguageServer.Experimental.LanguageServer, as: ExperimentalLS
  import ElixirLS.LanguageServer.JsonRpc, only: [request: 2, notification: 1]

  def handles?(type, notification(method_name)) do
    handles?(type, method_name)
  end

  def handles?(type, request(_id, method_name)) do
    handles?(type, method_name)
  end

  def handles?(:standard, method_name) when is_binary(method_name) do
    ExperimentalLS.handler_state(method_name) != :exclusive
  end

  def handles?(:experimental, method_name) when is_binary(method_name) do
    ExperimentalLS.handler_state(method_name) != :ignored
  end
end
