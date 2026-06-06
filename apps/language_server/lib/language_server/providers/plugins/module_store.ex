defmodule ElixirLS.LanguageServer.Plugins.ModuleStore do
  @moduledoc """
  Caches the module list and a list of modules keyed by the behaviour they implement.
  """
  defstruct by_behaviour: %{}, list: [], plugins: []

  @type t :: %__MODULE__{
          by_behaviour: %{optional(atom) => module},
          list: list(module),
          plugins: list(module)
        }

  alias ElixirSense.Core.Applications

  @doc """
  Adds the given module(s) to the existing `:module_store` in `context`,
  if they are loadable.

  Originally forced compilation via `Code.ensure_compiled/1`, but that's
  prone to locking under concurrent Mix compilation. We now only consult
  the code server (`Code.ensure_loaded?/1`) — if the anchor module isn't
  already loadable in the running BEAM, the calling plugin silently skips
  (which matches the desired behaviour for projects that don't pull in
  Phoenix / Ecto / etc).
  """
  def ensure_loaded(context, module_or_modules) do
    modules = List.wrap(module_or_modules) |> Enum.filter(&Code.ensure_loaded?/1)
    Map.update!(context, :module_store, &build(modules, &1))
  end

  def build(list \\ all_loaded(), module_store \\ %__MODULE__{}) do
    Enum.reduce(list, module_store, fn module, module_store ->
      try do
        module_store = %{module_store | list: [module | module_store.list]}

        module_store =
          if is_plugin?(module) do
            %{module_store | plugins: [module | module_store.plugins]}
          else
            module_store
          end

        module.module_info(:attributes)
        |> Enum.flat_map(fn
          {:behaviour, behaviours} when is_list(behaviours) ->
            behaviours

          _ ->
            []
        end)
        |> Enum.reduce(module_store, &add_behaviour(module, &1, &2))
      rescue
        _ ->
          module_store
      end
    end)
  end

  defp is_plugin?(module) do
    module.module_info(:attributes)
    |> Enum.any?(fn
      {:behaviour, behaviours} when is_list(behaviours) ->
        ElixirSense.Plugin in behaviours or ElixirLS.LanguageServer.Plugin in behaviours

      {:is_elixir_sense_plugin, true} ->
        true

      {:is_elixir_ls_plugin, true} ->
        true

      _ ->
        false
    end)
  end

  defp all_loaded do
    Applications.get_modules_from_applications()
    |> Enum.filter(fn module ->
      function_exported?(module, :module_info, 0)
    end)
  end

  defp add_behaviour(adopter, behaviour, module_store) do
    new_by_behaviour =
      module_store.by_behaviour
      |> Map.put_new_lazy(behaviour, fn -> MapSet.new() end)
      |> Map.update!(behaviour, &MapSet.put(&1, adopter))

    %{module_store | by_behaviour: new_by_behaviour}
  end
end
