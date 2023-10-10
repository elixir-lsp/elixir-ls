defmodule ElixirLS.LanguageServer.DocLinks do
  @moduledoc """
  Provides links to hex docs
  """

  @hex_base_url "https://hexdocs.pm"

  defp get_app(module) do
    with {:ok, app} <- :application.get_application(module),
         {:ok, vsn} <- :application.get_key(app, :vsn) do
      {app, vsn}
    else
      _ ->
        nil
    end
  end

  def hex_docs_module_link(module) do
    case get_app(module) do
      {app, vsn} ->
        "#{@hex_base_url}/#{app}/#{vsn}/#{inspect(module)}.html"

      nil ->
        nil
    end
  end

  def hex_docs_function_link(module, function, arity) do
    case get_app(module) do
      {app, vsn} ->
        "#{@hex_base_url}/#{app}/#{vsn}/#{inspect(module)}.html##{function}/#{arity}"

      nil ->
        nil
    end
  end

  def hex_docs_type_link(module, type, arity) do
    case get_app(module) do
      {app, vsn} ->
        "#{@hex_base_url}/#{app}/#{vsn}/#{inspect(module)}.html#t:#{type}/#{arity}"

      nil ->
        nil
    end
  end
end
