defmodule ElixirLS.LanguageServer.Experimental.Protocol.Proto.CompileMetadata do
  @moduledoc """
  Compile-time storage of protocol metadata
  """

  @notification_modules_key {__MODULE__, :notification_modules}
  @type_modules_key {__MODULE__, :type_modules}
  @request_modules_key {__MODULE__, :request_modules}
  @response_modules_key {__MODULE__, :response_modules}

  def notification_modules do
    :persistent_term.get(@notification_modules_key, [])
  end

  def request_modules do
    :persistent_term.get(@request_modules_key, [])
  end

  def response_modules do
    :persistent_term.get(@response_modules_key, [])
  end

  def type_modules do
    :persistent_term.get(@type_modules_key)
  end

  def add_notification_module(module) do
    add_module(@notification_modules_key, module)
  end

  def add_request_module(module) do
    add_module(@request_modules_key, module)
  end

  def add_response_module(module) do
    add_module(@response_modules_key, module)
  end

  def add_type_module(module) do
    add_module(@type_modules_key, module)
  end

  defp update(key, initial_value, update_fn) do
    case :persistent_term.get(key, :not_found) do
      :not_found -> :persistent_term.put(key, initial_value)
      found -> :persistent_term.put(key, update_fn.(found))
    end
  end

  defp add_module(key, module) do
    update(key, [module], fn old_list -> [module | old_list] end)
  end
end
