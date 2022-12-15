defmodule Mix.Tasks.Lsp.DataModel do
  alias Mix.Tasks.Lsp.DataModel.Enumeration
  alias Mix.Tasks.Lsp.DataModel.Structure
  alias Mix.Tasks.Lsp.DataModel.TypeAlias

  defstruct names_to_types: %{},
            notifications: %{},
            requests: %{},
            structures: %{},
            type_aliases: %{},
            enumerations: %{}

  def new do
    with {:ok, root_meta} <- load_meta_model() do
      names_to_types =
        root_meta
        |> Map.take(~w(structures enumerations typeAliases))
        |> Enum.flat_map(fn {type, list_of_things} ->
          Enum.map(list_of_things, fn %{"name" => name} -> {name, type_name(type)} end)
        end)
        |> Map.new()

      type_aliases = load_from_meta(root_meta, "typeAliases", &TypeAlias.new/1)
      enumerations = load_from_meta(root_meta, "enumerations", &Enumeration.new/1)
      structures = load_from_meta(root_meta, "structures", &Structure.new/1)

      data_model = %__MODULE__{
        names_to_types: names_to_types,
        enumerations: enumerations,
        type_aliases: type_aliases,
        structures: structures
      }

      {:ok, data_model}
    end
  end

  def all_types(%__MODULE__{} = data_model) do
    data_model.type_aliases
    |> Map.merge(data_model.enumerations)
    |> Map.merge(data_model.structures)
  end

  def fetch(%__MODULE__{} = data_model, name) do
    field =
      case kind(data_model, name) do
        :structure -> :structures
        :type_alias -> :type_aliases
        :enumeration -> :enumerations
      end

    data_model
    |> Map.get(field, %{})
    |> Map.fetch(name)
    |> case do
      {:ok, %element_module{} = element} ->
        {:ok, element_module.resolve(element, data_model)}

      :error ->
        :error
    end
  end

  def fetch!(%__MODULE__{} = data_model, name) do
    case fetch(data_model, name) do
      {:ok, thing} -> thing
      :error -> raise "Could not find type #{name}"
    end
  end

  defp load_from_meta(root_meta, name, new_fn) do
    root_meta
    |> Map.get(name)
    |> Map.new(fn definition ->
      loaded = new_fn.(definition)
      {loaded.name, loaded}
    end)
  end

  defp kind(%__MODULE__{} = data_model, name) do
    Map.fetch!(data_model.names_to_types, name)
  end

  defp type_name("structures"), do: :structure
  defp type_name("enumerations"), do: :enumeration
  defp type_name("typeAliases"), do: :type_alias

  @meta_model_file_name "metamodel.3.17.json"
  defp load_meta_model do
    file_name =
      __ENV__.file
      |> Path.dirname()
      |> Path.join([@meta_model_file_name])

    with {:ok, file_contents} <- File.read(file_name) do
      JasonVendored.decode(file_contents)
    end
  end
end
