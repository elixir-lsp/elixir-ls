defmodule ElixirLS.LanguageServer.DocLinks do
  @moduledoc """
  Provides links to hex docs
  """

  @hex_base_url "https://hexdocs.pm"

  defp get_erts_modules do
    {:ok, [[erlang_lib_dir]]} = :init.get_argument(:root)
    erts_version = :erlang.system_info(:version)
    erts_app_path = Path.join([erlang_lib_dir, "lib", "erts-#{erts_version}", "ebin", "erts.app"])

    {:ok, [{:application, _, props}]} = :file.consult(erts_app_path)
    modules = Keyword.get(props, :modules)
    for module <- modules, into: %{}, do: {module, {:erts, erts_version}}
  end

  defp get_app(module) do
    module_to_app =
      for {app, _, vsn} <- Application.loaded_applications(),
          {:ok, app_modules} = :application.get_key(app, :modules),
          mod <- app_modules,
          into: %{},
          do: {mod, {app, vsn}}

    module_to_app
    |> Map.merge(get_erts_modules())
    |> Map.get(module)
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
