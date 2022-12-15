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

  defstruct [:mappings, :imported_lsp_names]

  def new do
    with {:ok, type_mappings} = load_type_mappings() do
      imported_lsp_names = MapSet.new(type_mappings, & &1.source)
      current = %__MODULE__{mappings: type_mappings, imported_lsp_names: imported_lsp_names}
      {:ok, current}
    end
  end

  def put_new(%__MODULE__{} = current, source, destination) do
    if imported?(current, source) do
      :error
    else
      i = Mapping.new(source, destination)

      current = %__MODULE__{
        imported_lsp_names: MapSet.put(current.imported_lsp_names, i.source),
        mappings: [i | current.mappings]
      }

      {:ok, current}
    end
  end

  def write(%__MODULE__{} = current) do
    sorted = Enum.sort_by(current.mappings, fn %Mapping{} = mapping -> mapping.source end)

    with {:ok, json_text} <- JasonVendored.encode(sorted, pretty: true) do
      File.write(file_path(), json_text)
    end
  end

  def imported?(%__MODULE__{} = current, lsp_name) do
    lsp_name in current.imported_lsp_names
  end

  def fetch(%__MODULE__{} = current, lsp_name) do
    case Enum.find(current.mappings, fn %Mapping{source: source} -> source == lsp_name end) do
      %Mapping{} = mapping -> {:ok, mapping}
      nil -> :error
    end
  end

  def fetch_destination_module(current, needle, truncate? \\ false)

  def fetch_destination_module(%__MODULE__{} = current, %_{name: lsp_name}, truncate?) do
    fetch_destination_module(current, lsp_name, truncate?)
  end

  def fetch_destination_module(%__MODULE__{} = current, lsp_name, truncate?) do
    case fetch(current, lsp_name) do
      {:ok, %Mapping{} = mapping} ->
        module_string =
          if truncate? do
            [_, truncated] =
              mapping.destination
              |> String.splitter("Protocol.")
              |> Enum.to_list()

            truncated
          else
            mapping.destination
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
