defmodule Mix.Tasks.Lsp.Mappings.Init do
  alias Mix.Shell.IO, as: ShellIO
  alias Mix.Tasks.Lsp.Mappings
  alias Mix.Tasks.Lsp.DataModel

  use Mix.Task
  @base_module "ElixirLS.LanguageServer.Experimental.Protocol.Types"
  def run(_) do
    with {:ok, data_model} <- DataModel.new(),
         {:ok, current} <- Mappings.new() do
      current =
        current
        |> write_structures(data_model)
        |> write_enumerations(data_model)
        |> write_type_aliases(data_model)

      Mappings.write(current)
    end
  end

  defp write_structures(%Mappings{} = mappings, %DataModel{} = data_model) do
    write_data_type(data_model.structures, mappings)
  end

  defp write_enumerations(%Mappings{} = mappings, %DataModel{} = data_model) do
    write_data_type(data_model.enumerations, mappings)
  end

  defp write_type_aliases(%Mappings{} = mappings, %DataModel{} = data_model) do
    write_data_type(data_model.type_aliases, mappings)
  end

  defp write_data_type(list_of_data_types, %Mappings{} = mappings) do
    Enum.reduce(list_of_data_types, mappings, fn
      {name, _}, %Mappings{} = curr ->
        destination_module = "#{@base_module}.#{name}"

        case Mappings.put_new(curr, name, destination_module) do
          {:ok, new_current} ->
            new_current

          :error ->
            ShellIO.info("#{name} has already been mapped")
            mappings
        end
    end)
  end
end
