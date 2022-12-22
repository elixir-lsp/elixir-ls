defmodule Mix.Tasks.Lsp.DataModel.Enumeration do
  defmodule Value do
    defstruct [:name, :value, :documentation]

    def new(%{"name" => name, "value" => value} = value_meta) do
      docs = value_meta["documentation"]
      %__MODULE__{name: name, value: value, documentation: docs}
    end
  end

  alias Mix.Tasks.Lsp.Mappings
  alias Mix.Tasks.Lsp.DataModel
  alias Mix.Tasks.Lsp.DataModel.Type
  defstruct [:name, :values, :type]

  def new(%{"name" => name, "type" => type, "values" => values}) do
    %__MODULE__{
      name: name,
      type: Type.new(name, type),
      values: Enum.map(values, &Value.new/1)
    }
  end

  def to_protocol(%__MODULE__{} = enumeration, _, _) do
    module_name = Module.concat([enumeration.name])
    quote(do: unquote(module_name))
  end

  def resolve(%__MODULE__{} = enumeration, %DataModel{} = data_model) do
    %__MODULE__{enumeration | type: Type.resolve(enumeration.type, data_model)}
  end

  def build_definition(
        %__MODULE__{} = enumeration,
        %Mappings{} = mappings,
        %DataModel{}
      ) do
    proto_module = Mappings.proto_module(mappings)

    with {:ok, destination_module} <-
           Mappings.fetch_destination_module(mappings, enumeration.name) do
      values =
        Enum.map(enumeration.values, fn value ->
          name = value.name |> Macro.underscore() |> String.to_atom()
          quote(do: {unquote(name), unquote(value.value)})
        end)

      ast =
        quote do
          defmodule unquote(destination_module) do
            alias unquote(proto_module)
            use Proto

            defenum unquote(values)
          end
        end

      {:ok, ast}
    end
  end

  def references(%__MODULE__{}) do
    []
  end
end
