defmodule Mix.Tasks.Lsp.DataModel.TypeAlias do
  alias Mix.Tasks.Lsp.DataModel.Type.ObjectLiteral
  alias Mix.Tasks.Lsp.DataModel.Type.Base
  alias Mix.Tasks.Lsp.Mappings
  alias Mix.Tasks.Lsp.DataModel
  alias Mix.Tasks.Lsp.DataModel.Type

  defstruct name: nil, type: nil

  def new(%{"name" => name, "type" => type}) do
    type = Type.new(name, type)

    %__MODULE__{
      name: name,
      type: type
    }
  end

  def resolve(%__MODULE__{name: "LSP" <> _} = type_alias, %DataModel{}) do
    type_alias
  end

  def resolve(%__MODULE__{} = type_alias, %DataModel{} = data_model) do
    %__MODULE__{type_alias | type: Type.resolve(type_alias.type, data_model)}
  end

  def build_definition(%__MODULE__{name: "LSP" <> _}, _, _) do
    :skip
  end

  def build_definition(%__MODULE__{type: %Base{}}, _, _) do
    :skip
  end

  def build_definition(
        %__MODULE__{} = type_alias,
        %Mappings{} = mappings,
        %DataModel{} = data_model
      ) do
    with {:ok, destination_module} <- Mappings.fetch_destination_module(mappings, type_alias.name) do
      type = Type.to_protocol(type_alias.type, data_model, mappings)
      object_literals = Type.collect_object_literals(type_alias.type, data_model)
      types_module = Mappings.types_module(mappings)
      proto_module = Mappings.proto_module(mappings)

      literal_definitions =
        Enum.map(object_literals, &ObjectLiteral.build_definition(&1, data_model, mappings))

      type_module_alias =
        case references(type_alias) do
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
            defalias unquote(type)
          end
        end

      {:ok, ast}
    end
  end

  def references(%__MODULE__{} = type_alias) do
    %type_module{} = type_alias.type
    type_module.references(type_alias.type)
  end
end
