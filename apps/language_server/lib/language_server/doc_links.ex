defmodule ElixirLS.LanguageServer.DocLinks do
  @moduledoc """
  Provides links to hex docs
  """

  @hex_base_url "https://hexdocs.pm"

  def get_app(module) do
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
        "#{@hex_base_url}/#{app}/#{vsn}/#{inspect_module(module)}.html"

      nil ->
        nil
    end
  end

  def hex_docs_function_link(module, function, arity) do
    case get_app(module) do
      {app, vsn} ->
        "#{@hex_base_url}/#{app}/#{vsn}/#{inspect_module(module)}.html##{function}/#{arity}"

      nil ->
        nil
    end
  end

  def hex_docs_type_link(module, type, arity) do
    case get_app(module) do
      {app, vsn} ->
        "#{@hex_base_url}/#{app}/#{vsn}/#{inspect_module(module)}.html#t:#{type}/#{arity}"

      nil ->
        nil
    end
  end

  def hex_docs_callback_link(module, callback, arity) do
    case get_app(module) do
      {app, vsn} ->
        "#{@hex_base_url}/#{app}/#{vsn}/#{inspect_module(module)}.html#c:#{callback}/#{arity}"

      nil ->
        nil
    end
  end

  def hex_docs_extra_link({app, vsn}, page) do
    "#{@hex_base_url}/#{app}/#{vsn}/#{page}"
  end

  def hex_docs_extra_link(app, page) do
    "#{@hex_base_url}/#{app}/#{page}"
  end

  defp inspect_module(module) do
    module |> inspect |> String.replace_prefix(":", "")
  end
end
