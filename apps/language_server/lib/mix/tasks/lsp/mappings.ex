defmodule Mix.Tasks.Lsp.Mappings do
  defmodule Mapping do
    @derive JasonVendored.Encoder

    defstruct [:source, :destination, :imported_version]

    @version "3.17"
    def new(%{
          "source" => source,
          "destination" => destination
        }) do
      new(source, destination)
    end

    def new(source, destination) do
      %__MODULE__{source: source, destination: destination, imported_version: @version}
    end
  end

  @types_module ElixirLS.LanguageServer.Experimental.Protocol.Types
  @proto_module ElixirLS.LanguageServer.Experimental.Protocol.Proto

  defstruct [:mappings, :imported_lsp_names, :types_module, :proto_module]

  def new(options \\ []) do
    types_module =
      options
      |> Keyword.get(:types_module, @types_module)
      |> List.wrap()
      |> Module.concat()

    proto_module =
      options
      |> Keyword.get(:proto_module, @proto_module)
      |> List.wrap()
      |> Module.concat()

    with {:ok, type_mappings} = load_type_mappings() do
      imported_lsp_names = MapSet.new(type_mappings, & &1.source)

      mappings = %__MODULE__{
        mappings: type_mappings,
        imported_lsp_names: imported_lsp_names,
        types_module: types_module,
        proto_module: proto_module
      }

      {:ok, mappings}
    end
  end

  def proto_module(%__MODULE__{} = mappings) do
    mappings.proto_module
  end

  def types_module(%__MODULE__{} = mappings) do
    mappings.types_module
  end

  def put_new(%__MODULE__{} = mappings, source, destination) do
    if imported?(mappings, source) do
      :error
    else
      i = Mapping.new(source, destination)

      mappings = %__MODULE__{
        imported_lsp_names: MapSet.put(mappings.imported_lsp_names, i.source),
        mappings: [i | mappings.mappings]
      }

      {:ok, mappings}
    end
  end

  def write(%__MODULE__{} = mappings) do
    sorted = Enum.sort_by(mappings.mappings, fn %Mapping{} = mapping -> mapping.source end)

    with {:ok, json_text} <- JasonVendored.encode(sorted, pretty: true) do
      json_text = [json_text, "\n"]
      File.write(file_path(), json_text)
    end
  end

  def imported?(%__MODULE__{} = mappings, lsp_name) do
    lsp_name in mappings.imported_lsp_names
  end

  def fetch(%__MODULE__{} = mappings, lsp_name) do
    case Enum.find(mappings.mappings, fn %Mapping{source: source} -> source == lsp_name end) do
      %Mapping{} = mapping -> {:ok, mapping}
      nil -> :error
    end
  end

  def fetch_destination_module(mappings, needle, truncate? \\ false)

  def fetch_destination_module(%__MODULE__{} = mappings, %_{name: lsp_name}, truncate?) do
    fetch_destination_module(mappings, lsp_name, truncate?)
  end

  def fetch_destination_module(%__MODULE__{} = mappings, lsp_name, truncate?) do
    case fetch(mappings, lsp_name) do
      {:ok, %Mapping{} = mapping} ->
        module_string =
          if truncate? do
            aliased =
              mappings
              |> types_module()
              |> Module.split()
              |> List.last()

            Module.concat([aliased, mapping.destination])
          else
            Module.concat([types_module(mappings), mapping.destination])
          end

        {:ok, Module.concat([module_string])}

      error ->
        error
    end
  end

  @import_filename "type_mappings.json"
  defp load_type_mappings do
    import_file_path = file_path()

    with {:ok, json_text} <- File.read(import_file_path),
         {:ok, contents} <- JasonVendored.decode(json_text) do
      {:ok, from_json(contents)}
    end
  end

  defp from_json(json_file) do
    Enum.map(json_file, &Mapping.new/1)
  end

  defp file_path do
    current_dir = Path.dirname(__ENV__.file)
    Path.join([current_dir, @import_filename])
  end
end
