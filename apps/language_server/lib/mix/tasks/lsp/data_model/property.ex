defmodule Mix.Tasks.Lsp.DataModel.Property do
  alias Mix.Tasks.Lsp.DataModel
  alias Mix.Tasks.Lsp.Mappings
  alias Mix.Tasks.Lsp.DataModel.Type

  defstruct [:name, :type, :required?, :references, :documentation]

  def new(%{"name" => name, "type" => type} = property_meta) do
    required? = !Map.get(property_meta, "optional", false)

    keys = Keyword.merge([name: name, required?: required?], type: Type.new(name, type))
    struct(__MODULE__, keys)
  end

  def resolve(%__MODULE__{} = property, %DataModel{} = data_model) do
    %__MODULE__{property | type: Type.resolve(property.type, data_model)}
  end

  def to_protocol(%__MODULE__{} = property, %DataModel{} = data_model, %Mappings{} = mappings) do
    underscored = property.name |> Macro.underscore() |> String.to_atom()
    type_call = Type.to_protocol(property.type, data_model, mappings)

    if property.required? do
      quote(do: {unquote(underscored), unquote(type_call)})
    else
      quote(do: {unquote(underscored), optional(unquote(type_call))})
    end
  end

  def references(%__MODULE__{} = property) do
    %type_module{} = property.type

    property.type
    |> type_module.references()
    |> Enum.reject(fn name -> String.starts_with?(name, "LSP") end)
  end
end
