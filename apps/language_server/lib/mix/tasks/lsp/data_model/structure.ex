defmodule Mix.Tasks.Lsp.DataModel.Structure do
  alias Mix.Tasks.Lsp.Mappings.NumberingContext
  alias Mix.Tasks.Lsp.DataModel.Type.ObjectLiteral
  alias Mix.Tasks.Lsp.Mappings
  alias Mix.Tasks.Lsp.DataModel
  alias Mix.Tasks.Lsp.DataModel.Type
  alias Mix.Tasks.Lsp.DataModel.Property

  defstruct name: nil, documentation: nil, properties: nil, definition: nil, module: nil

  def new(%{"name" => name, "properties" => _} = definition) do
    NumberingContext.new()

    %__MODULE__{
      name: name,
      documentation: definition[:documentation],
      definition: definition,
      module: Module.concat([name])
    }
  end

  def to_protocol(%__MODULE__{} = structure, _, %Mappings{} = _mappings) do
    quote(do: unquote(structure.module))
  end

  def build_definition(
        %__MODULE__{} = structure,
        %Mappings{} = mappings,
        %DataModel{} = data_model
      ) do
    with {:ok, destination_module} <- Mappings.fetch_destination_module(mappings, structure.name) do
      NumberingContext.new()
      types_module = Mappings.types_module(mappings)
      proto_module = Mappings.proto_module(mappings)
      structure = resolve(structure, data_model)
      object_literals = Type.collect_object_literals(structure, data_model)

      literal_definitions =
        Enum.map(object_literals, &ObjectLiteral.build_definition(&1, data_model, mappings))

      protocol_properties =
        structure.properties
        |> Enum.sort_by(& &1.name)
        |> Enum.map(&Property.to_protocol(&1, data_model, mappings))

      type_module_alias =
        case references(structure) do
          [] -> []
          _ -> [quote(do: alias(unquote(types_module)))]
        end

      ast =
        quote do
          defmodule unquote(destination_module) do
            alias unquote(proto_module)
            unquote_splicing(type_module_alias)

            unquote_splicing(literal_definitions)

            use Proto
            deftype unquote(protocol_properties)
          end
        end

      {:ok, ast}
    end
  end

  def references(%__MODULE__{} = structure) do
    Enum.flat_map(structure.properties, &Property.references/1)
  end

  def resolve(%__MODULE__{properties: properties} = structure) when is_list(properties) do
    structure
  end

  def resolve(%__MODULE__{} = structure, %DataModel{} = data_model) do
    %__MODULE__{structure | properties: properties(structure, data_model)}
  end

  def properties(%__MODULE__{properties: properties}) when is_list(properties) do
    properties
  end

  def properties(%__MODULE__{} = structure, %DataModel{} = data_model) do
    property_list(structure, data_model)
  end

  defp resolve_remote_properties(%__MODULE__{} = structure, %DataModel{} = data_model) do
    []
    |> add_extends(structure.definition)
    |> add_mixins(structure.definition)
    |> Enum.flat_map(fn %{"kind" => "reference", "name" => type_name} ->
      data_model
      |> DataModel.fetch!(type_name)
      |> property_list(data_model)
    end)
  end

  defp property_list(%__MODULE__{} = structure, %DataModel{} = data_model) do
    base_properties =
      structure.definition
      |> Map.get("properties")
      |> Enum.map(&Property.new/1)

    base_property_names = MapSet.new(base_properties, & &1.name)

    # Note: The reject here is so that properties defined in the
    # current structure override those defined in mixins and extends
    resolved_remote_properties =
      structure
      |> resolve_remote_properties(data_model)
      |> Enum.reject(&(&1.name in base_property_names))

    base_properties
    |> Enum.concat(resolved_remote_properties)
    |> Enum.sort_by(& &1.name)
  end

  defp add_extends(queue, %{"extends" => extends}) do
    extends ++ queue
  end

  defp add_extends(queue, _), do: queue

  defp add_mixins(queue, %{"mixins" => mixins}) do
    mixins ++ queue
  end

  defp add_mixins(queue, _), do: queue
end
