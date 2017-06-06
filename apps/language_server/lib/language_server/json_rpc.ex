defmodule ElixirLS.LanguageServer.JsonRpc do
  @moduledoc """
  Macros and functions for JSON RPC

  Contains macros for creating or pattern-matching against packets and helper functions for sending
  responses and notifications
  """

  defmacro notification(method, params) do 
    quote do
      %{"method" => unquote(method), "params" => unquote(params), "jsonrpc" => "2.0"}
    end
  end

  defmacro notification(method) do
    quote do
      %{"method" => unquote(method), "jsonrpc" => "2.0"}
    end
  end

  defmacro request(id, method, params) do
    quote do
      %{"id" => unquote(id), "method" => unquote(method), "params" => unquote(params), 
        "jsonrpc" => "2.0"}
    end
  end

  defmacro response(id, result) do 
    quote do
      %{"result" => unquote(result), "id" => unquote(id), "jsonrpc" => "2.0"}
    end
  end

  def notify(method, params) do
    send(notification(method, params))
  end

  def respond(id, result) do
    send(response(id, result))
  end

  def error_response(id, type, message) do 
    {code, default_message} = error_code_and_message(type)
    %{"error" => %{"code" => code, "message" => message || default_message}, "id" => id,
      "jsonrpc" => "2.0"}
  end

  def respond_with_error(id, type, message) do
    send(error_response(id, type, message))
  end

  def show_message(type, message) do
    notify("window/showMessage", %{type: message_type_code(type), message: message})
  end

  def log_message(type, message) do
    notify("window/logMessage", %{type: message_type_code(type), message: message})
  end

  ## Helpers

  defp send(packet) do
    ElixirLS.IOHandler.send(packet)
  end

  defp message_type_code(type) do
    case type do
      :error -> 1
      :warning -> 2
      :info -> 3
      :log -> 4
    end
  end

  defp error_code_and_message(:parse_error), do: {-32700, "Parse error"}
  defp error_code_and_message(:invalid_request), do: {-32600, "Invalid Request"}
  defp error_code_and_message(:method_not_found), do: {-32601, "Method not found"}
  defp error_code_and_message(:invalid_params), do: {-32602, "Invalid params"}
  defp error_code_and_message(:internal_error), do: {-32603, "Internal error"}
  defp error_code_and_message(:server_error), do: {-32000, "Server error"}
  defp error_code_and_message(:request_cancelled), do: {-32800, "Request cancelled"}
end