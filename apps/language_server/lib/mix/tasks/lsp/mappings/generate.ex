defmodule Mix.Tasks.Lsp.Mappings.Generate do
  use Mix.Task
  @shortdoc "Generate the LSP protocol modules"
  @moduledoc """
  Generate the LSP protocol modules

  This task reads the mapping file and generates all of the LSP protocol artifacts.
  Prior to running this task, you must first generate the mapping file with `mix lsp.mappings.init`.
  That will create the file `type_mappings.json` which contains the source and destination modules for all
  defined LSP types.

  Once that file is generated, the file can be edited to control where the generated elixir modules will live.
  While doing the mapping, it's often helpful to run `mix lsp.mappings.print` to see current state of the mapping.
  Once you're satisfied, run this task and elixir files will be generated in `lib/generated`.
  """

  alias Mix.Tasks.Lsp.DataModel
  alias Mix.Tasks.Lsp.Mappings
  alias Mix.Tasks.Lsp.Mappings.Mapping

  @generated_files_root ~w(lib generated)

  def run(_) do
    with {:ok, %DataModel{} = data_model} <- DataModel.new(),
         {:ok, mappings} <- Mappings.new(),
         {:ok, results} <- map_lsp_types(data_model, mappings) do
      IO.puts("Mapping complete, writing #{length(results)} files")

      for {file_name, ast} <- results do
        write_file(file_name, ast)
        IO.write(".")
      end

      IO.puts("\nComplete.")
    else
      error ->
        Mix.Shell.IO.error("An error occurred during mapping #{inspect(error)}")
    end
  end

  defp map_lsp_types(%DataModel{} = data_model, %Mappings{} = mappings) do
    mapping_results =
      [data_model.type_aliases, data_model.enumerations, data_model.structures]
      |> Enum.flat_map(fn type_map ->
        type_map
        |> Map.values()
        |> Enum.sort_by(& &1.name)
      end)
      |> Enum.map(&do_mapping(&1, mappings, data_model))
      |> Enum.reduce_while([], fn
        :skip, acc ->
          IO.write([IO.ANSI.yellow(), ".", IO.ANSI.reset()])

          {:cont, acc}

        {:ok, file, ast}, results ->
          IO.write([IO.ANSI.green(), ".", IO.ANSI.reset()])

          {:cont, [{file, ast} | results]}

        error, _ ->
          IO.write([IO.ANSI.red(), "x", IO.ANSI.reset()])

          {:halt, error}
      end)

    IO.puts("")

    case mapping_results do
      results when is_list(results) ->
        {:ok, Enum.reverse(results)}

      error ->
        error
    end
  end

  defp do_mapping(%struct_module{} = structure, %Mappings{} = mappings, %DataModel{} = data_model) do
    with {:ok, %Mapping{} = mapping} <- Mappings.fetch(mappings, structure.name),
         {:ok, definition_ast} <- struct_module.build_definition(structure, mappings, data_model) do
      {:ok, file_for(mapping), definition_ast}
    end
  end

  defp file_for(%Mapping{} = mapping) do
    base = Path.split(File.cwd!()) ++ @generated_files_root

    pieces = String.split(mapping.destination, ".")
    {modules, [file]} = Enum.split(pieces, length(pieces) - 1)

    directories =
      for module <- modules,
          module != "ElixirLS" do
        Macro.underscore(module)
      end

    file_name =
      case Macro.underscore(file) do
        "_" <> rest -> rest <> ".ex"
        other -> other <> ".ex"
      end

    (base ++ directories)
    |> Path.join()
    |> Path.join(file_name)
  end

  def write_file(file_path, ast) do
    dir = Path.dirname(file_path)
    File.mkdir_p!(dir)

    file_contents = [
      header(),
      Macro.to_string(ast)
    ]

    File.write!(file_path, file_contents)
  end

  defp header do
    """
    # This file's contents are auto-generated. Do not edit.
    """
  end
end
