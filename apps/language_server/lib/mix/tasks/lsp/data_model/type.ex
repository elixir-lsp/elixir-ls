defmodule Mix.Tasks.Lsp.DataModel.Type do
  alias Mix.Tasks.Lsp.DataModel
  alias Mix.Tasks.Lsp.DataModel.Property
  alias Mix.Tasks.Lsp.DataModel.Structure
  alias Mix.Tasks.Lsp.DataModel.TypeAlias
  alias Mix.Tasks.Lsp.Mappings

  defmodule Base do
    defstruct [:kind, :type_name]

    def new(type_name) do
      %__MODULE__{kind: :base, type_name: type_name}
    end

    def resolve(%__MODULE__{} = base, %DataModel{}) do
      base
    end

    def to_protocol(%__MODULE__{} = type, %DataModel{} = _data_model, _) do
      case type.type_name do
        "string" -> quote(do: string())
        "integer" -> quote(do: integer())
        "uinteger" -> quote(do: integer())
        "boolean" -> quote(do: boolean())
        "null" -> quote(do: nil)
        "DocumentUri" -> quote(do: string())
        "decimal" -> quote(do: float())
        "URI" -> quote(do: string())
      end
    end

    def references(%__MODULE__{}) do
      []
    end
  end

  defmodule Array do
    alias Mix.Tasks.Lsp.DataModel.Type
    defstruct [:kind, :element_type]

    def new(parent_name, element_type) do
      %__MODULE__{kind: :array, element_type: Type.new(parent_name, element_type)}
    end

    def resolve(%__MODULE__{} = array, %DataModel{} = data_model) do
      %__MODULE__{array | element_type: Type.resolve(array.element_type, data_model)}
    end

    def to_protocol(
          %__MODULE__{} = type,
          %DataModel{} = data_model,
          %Mappings{} = mappings
        ) do
      element_protocol = Type.to_protocol(type.element_type, data_model, mappings)
      quote(do: list_of(unquote(element_protocol)))
    end

    def references(%__MODULE__{} = array) do
      %type_module{} = array.element_type
      type_module.references(array.element_type)
    end
  end

  defmodule Tuple do
    alias Mix.Tasks.Lsp.DataModel.Type
    defstruct [:kind, :item_types]

    def new(parent_name, items) do
      item_types = Enum.map(items, &Type.new(parent_name, &1))
      %__MODULE__{kind: :tuple, item_types: item_types}
    end

    def resolve(%__MODULE__{} = tuple, %DataModel{} = data_model) do
      resolved_types = Enum.map(tuple.item_types, &Type.resolve(&1, data_model))
      %__MODULE__{tuple | item_types: resolved_types}
    end

    def to_protocol(
          %__MODULE__{} = type,
          %DataModel{} = data_model,
          %Mappings{} = mappings
        ) do
      types = Enum.map(type.item_types, &Type.to_protocol(&1, data_model, mappings))
      quote(do: tuple_of(unquote(types)))
    end

    def references(%__MODULE__{} = tuple) do
      Enum.flat_map(tuple.item_types, fn %type_module{} = type -> type_module.references(type) end)
    end
  end

  defmodule Reference do
    alias Mix.Tasks.Lsp.DataModel.Enumeration
    alias Mix.Tasks.Lsp.DataModel.Structure
    alias Mix.Tasks.Lsp.DataModel.Type
    alias Mix.Tasks.Lsp.DataModel.TypeAlias
    defstruct [:kind, :reference]

    def new(reference) do
      %__MODULE__{kind: :reference, reference: reference}
    end

    def resolve(%__MODULE__{} = reference, %DataModel{} = data_model) do
      case DataModel.fetch!(data_model, reference.reference) do
        %Enumeration{} = enumeration ->
          Enumeration.resolve(enumeration, data_model)

        %Structure{} = structure ->
          structure

        %TypeAlias{} = type_alias ->
          TypeAlias.resolve(type_alias, data_model)
      end
    end

    def to_protocol(
          %__MODULE__{} = type,
          %DataModel{} = data_model,
          %Mappings{} = mappings
        ) do
      case DataModel.fetch!(data_model, type.reference) do
        %Enumeration{} = enumeration ->
          {:ok, enumeration_module} =
            Mappings.fetch_destination_module(mappings, enumeration, true)

          quote(do: unquote(enumeration_module))

        %Structure{} = structure ->
          {:ok, mapped_module} = Mappings.fetch_destination_module(mappings, structure, true)

          quote(do: unquote(mapped_module))

        %TypeAlias{} = type_alias ->
          {:ok, mapped_module} = Mappings.fetch_destination_module(mappings, type_alias, true)
          quote(do: unquote(mapped_module))
      end
    end

    def references(%__MODULE__{} = reference) do
      [reference.reference]
    end
  end

  defmodule Or do
    alias Mix.Tasks.Lsp.Mappings.NumberingContext
    alias Mix.Tasks.Lsp.DataModel.Property
    alias Mix.Tasks.Lsp.DataModel.Type

    defstruct [:kind, :subtypes]

    def new(parent_name, subtypes) do
      subtypes = Enum.map(subtypes, &Type.new(parent_name, &1))
      %__MODULE__{kind: :or, subtypes: subtypes}
    end

    def resolve(%__MODULE__{} = or_type, %DataModel{} = data_model) do
      resolved_subtypes = Enum.map(or_type.subtypes, &Type.resolve(&1, data_model))

      %__MODULE__{or_type | subtypes: resolved_subtypes}
      or_type
    end

    def to_protocol(%__MODULE__{} = type, %DataModel{} = data_model, %Mappings{} = mappings) do
      subtypes = Enum.map(type.subtypes, &Type.to_protocol(&1, data_model, mappings))
      quote(do: one_of(unquote(subtypes)))
    end

    def references(%__MODULE__{} = type) do
      Enum.flat_map(type.subtypes, fn %type_module{} = type -> type_module.references(type) end)
    end
  end

  defmodule ObjectLiteral do
    alias Mix.Tasks.Lsp.Mappings.NumberingContext
    alias Mix.Tasks.Lsp.DataModel.Structure
    alias Mix.Tasks.Lsp.DataModel.Property
    defstruct [:kind, :name, :properties, :definition, :module]

    def new(parent_name, definition) do
      base_name = Macro.camelize(parent_name)

      module =
        case NumberingContext.get_and_increment(base_name) do
          0 -> Module.concat([base_name])
          sequence -> Module.concat(["#{base_name}#{sequence}"])
        end

      properties = Enum.map(definition, &Property.new/1)

      %__MODULE__{
        definition: definition,
        kind: :object_literal,
        properties: properties,
        name: base_name,
        module: module
      }
    end

    def resolve(%__MODULE__{properties: nil} = literal, %DataModel{} = data_model) do
      resolved_properties =
        %{"properties" => literal.definition, "name" => "Literal"}
        |> Structure.new()
        |> Structure.resolve(data_model)
        |> Structure.properties(data_model)

      %__MODULE__{literal | properties: resolved_properties}
    end

    def resolve(%__MODULE__{} = literal, _) do
      literal
    end

    def to_protocol(%__MODULE__{} = literal, %DataModel{}, %Mappings{}) do
      module = module(literal)
      quote(do: unquote(module))
    end

    def build_definition(
          %__MODULE__{} = literal,
          %DataModel{} = data_model,
          %Mappings{} = mappings
        ) do
      resolved = resolve(literal, data_model)
      module = module(literal)

      properties =
        resolved.properties
        |> Enum.sort_by(& &1.name)
        |> Enum.map(&Property.to_protocol(&1, data_model, mappings))

      quote do
        defmodule unquote(module) do
          use Proto

          deftype unquote(properties)
        end
      end
    end

    defp module(%__MODULE__{} = literal) do
      literal.module
    end

    def references(%__MODULE__{} = literal) do
      Enum.flat_map(literal.properties, &Property.references/1)
    end
  end

  defmodule Literal do
    defstruct [:kind, :value, :base_type]

    def new(base_type, value) do
      %__MODULE__{base_type: base_type, value: value, kind: :literal}
    end

    def resolve(%__MODULE__{} = literal, %DataModel{}) do
      literal
    end

    def to_protocol(%__MODULE__{} = type, %DataModel{}, %Mappings{}) do
      quote(do: literal(unquote(type.value)))
    end

    def references(%__MODULE__{}) do
      []
    end
  end

  defmodule Dictionary do
    alias Mix.Tasks.Lsp.DataModel.Type
    defstruct [:kind, :key_type, :value_type]

    def new(parent_name, key_type, value_type) do
      %__MODULE__{
        kind: :map,
        key_type: Type.new(parent_name, key_type),
        value_type: Type.new(parent_name, value_type)
      }
    end

    def resolve(%__MODULE__{} = map, %DataModel{} = data_model) do
      resolved_key_type = Type.resolve(map.key_type, data_model)
      resolved_value_type = Type.resolve(map.value_type, data_model)
      %__MODULE__{map | key_type: resolved_key_type, value_type: resolved_value_type}
    end

    def to_protocol(
          %__MODULE__{} = type,
          %DataModel{} = data_model,
          %Mappings{} = mappings
        ) do
      value_type = Type.to_protocol(type.value_type, data_model, mappings)
      quote(do: map_of(unquote(value_type)))
    end

    def references(%__MODULE__{} = dictionary) do
      %key_module{} = dictionary.key_type
      %value_module{} = dictionary.value_type

      List.flatten([
        key_module.references(dictionary.key_type),
        value_module.references(dictionary.value_type)
      ])
    end
  end

  def new(_parent_name, %{"kind" => "base", "name" => name}) do
    Base.new(name)
  end

  def new(_parent_name, %{"kind" => "reference", "name" => name}) do
    Reference.new(name)
  end

  def new(parent_name, %{"kind" => "or", "items" => types}) do
    Or.new(parent_name, types)
  end

  def new(_parent_name, %{"kind" => "stringLiteral", "value" => value}) do
    Literal.new(:string, value)
  end

  def new(parent_name, %{"kind" => "literal", "value" => %{"properties" => properties}}) do
    ObjectLiteral.new(parent_name, properties)
  end

  def new(parent_name, %{"kind" => "array", "element" => element_type}) do
    Array.new(parent_name, element_type)
  end

  def new(parent_name, %{"kind" => "map", "key" => key_type, "value" => value_type}) do
    Dictionary.new(parent_name, key_type, value_type)
  end

  def new(parent_name, %{"kind" => "tuple", "items" => items}) do
    Tuple.new(parent_name, items)
  end

  def resolve(%type_module{} = type, %DataModel{} = data_model) do
    type_module.resolve(type, data_model)
  end

  def to_protocol(%{reference: "LSPAny"}, _, _) do
    quote(do: any())
  end

  def to_protocol(%{reference: "LSPObject"}, _, _) do
    quote(do: map_of(any()))
  end

  def to_protocol(%{reference: "LSPArray"}, _, _) do
    quote(do: list_of(any()))
  end

  def to_protocol(
        %type_module{} = type,
        %DataModel{} = data_model,
        %Mappings{} = mappings
      ) do
    type_module.to_protocol(type, data_model, mappings)
  end

  def collect_object_literals(type, %DataModel{} = data_model) do
    type
    |> collect_object_literals(data_model, [])
    |> Enum.sort_by(& &1.module)
  end

  def collect_object_literals(%ObjectLiteral{} = literal, %DataModel{} = data_model, acc) do
    Enum.reduce(literal.properties, [literal | acc], &collect_object_literals(&1, data_model, &2))
  end

  def collect_object_literals(%Property{} = property, %DataModel{} = data_model, acc) do
    collect_object_literals(property.type, data_model, acc)
  end

  def collect_object_literals(%Array{} = array, %DataModel{} = data_model, acc) do
    collect_object_literals(array.element_type, data_model, acc)
  end

  def collect_object_literals(%Tuple{} = tuple, %DataModel{} = data_model, acc) do
    Enum.reduce(tuple.item_types, acc, &collect_object_literals(&1, data_model, &2))
  end

  def collect_object_literals(%Structure{} = structure, %DataModel{} = data_model, acc) do
    Enum.reduce(structure.properties, acc, &collect_object_literals(&1.type, data_model, &2))
  end

  def collect_object_literals(%Or{} = or_type, %DataModel{} = data_model, acc) do
    Enum.reduce(or_type.subtypes, acc, &collect_object_literals(&1, data_model, &2))
  end

  def collect_object_literals(%Base{}, %DataModel{}, acc) do
    acc
  end

  def collect_object_literals(%Reference{}, %DataModel{}, acc) do
    acc
  end

  def collect_object_literals(%TypeAlias{name: "LSP" <> _}, _, acc) do
    acc
  end

  def collect_object_literals(_, _, acc) do
    acc
  end
end
