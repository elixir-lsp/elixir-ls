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


  ## Command line options
    * `--types-module` - Controls the module in which the generated structures are placed.
      (defaults to `ElixirLS.LanguageServer.Experimental.Protocol.Types`)
    * `--proto-module` - Controls the module in which the generated structures are placed.
      (defaults to `ElixirLS.LanguageServer.Experimental.Protocol.Proto`)
    * `--only` - Only generate the LSP types in the comma separated list
    * `--roots` - A comma separated list of types to import. The types given will be interrogated
      and all their references will also be imported. This is useful when importing complex structures,
      as you don't need to specify all the types you wish to import.
  """

  alias Mix.Tasks.Lsp.DataModel
  alias Mix.Tasks.Lsp.Mappings
  alias Mix.Tasks.Lsp.Mappings.Mapping

  @generated_files_root ~w(lib generated)
  @switches [
    only: :string,
    proto_module: :string,
    roots: :string,
    types_module: :string
  ]

  def run(args) do
    args
    |> parse_options()
    |> do_run()
  end

  def do_run(options) do
    mappings_opts = Keyword.take(options, [:types_module, :proto_module])

    with {:ok, %DataModel{} = data_model} <- DataModel.new(),
         {:ok, mappings} <- Mappings.new(mappings_opts),
         {:ok, types_to_map} <- get_mapped_types(options, data_model),
         {:ok, results} <- map_lsp_types(types_to_map, data_model, mappings) do
      IO.puts("Mapping complete, writing #{length(results)} files")

      for {file_name, ast} <- results do
        write_file(file_name, ast)
        IO.write(".")
      end

      IO.puts("\nComplete.")
    else
      {:error, reason} ->
        Mix.Shell.IO.error("An error occurred during mapping #{to_string(reason)}")

      error ->
        Mix.Shell.IO.error("An error occurred during mapping #{inspect(error)}")
    end
  end

  defp parse_options(args) do
    {keywords, _, _} = OptionParser.parse(args, strict: @switches)

    if Keyword.has_key?(keywords, :only) and Keyword.has_key?(keywords, :roots) do
      raise "You can only specify one of --only and --roots"
    end

    keywords
    |> Keyword.replace_lazy(:only, &split_comma_delimited/1)
    |> Keyword.replace_lazy(:roots, &split_comma_delimited/1)
  end

  defp map_lsp_types(types_to_map, %DataModel{} = data_model, %Mappings{} = mappings) do
    mapping_results =
      types_to_map
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
    with {:ok, %Mapping{}} <- Mappings.fetch(mappings, structure.name),
         {:ok, destination_module} <- Mappings.fetch_destination_module(mappings, structure.name),
         {:ok, definition_ast} <- struct_module.build_definition(structure, mappings, data_model) do
      {:ok, file_for(destination_module), definition_ast}
    end
  end

  defp get_mapped_types(options, %DataModel{} = data_model) do
    cond do
      Keyword.has_key?(options, :only) ->
        options
        |> Keyword.get(:only)
        |> do_get_mapped_types(data_model)

      Keyword.has_key?(options, :roots) ->
        roots = Keyword.get(options, :roots)

        data_model
        |> DataModel.references(roots)
        |> do_get_mapped_types(data_model)

      true ->
        do_get_mapped_types(:all, data_model)
    end
  end

  defp do_get_mapped_types(:all, %DataModel{} = data_model) do
    all_types =
      data_model
      |> DataModel.all_types()
      |> Enum.sort_by(& &1.name)

    {:ok, all_types}
  end

  defp do_get_mapped_types(structure_names, %DataModel{} = data_model) do
    results =
      Enum.reduce_while(structure_names, [], fn name, acc ->
        case DataModel.fetch(data_model, name) do
          {:ok, structure} -> {:cont, [structure | acc]}
          _ -> {:halt, {:error, "'#{name}' is not the name of a valid LSP structure"}}
        end
      end)

    case results do
      mappings when is_list(mappings) ->
        {:ok, Enum.sort_by(mappings, & &1.name)}

      error ->
        error
    end
  end

  defp file_for(destination_module) do
    base = Path.split(File.cwd!()) ++ @generated_files_root

    pieces = Module.split(destination_module)
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
    {formatter, options} = formatter_and_opts_for(file_path)
    locals_without_parens = Keyword.get(options, :locals_without_parens)
    code = ast_to_string(ast, locals_without_parens, formatter)
    File.write!(file_path, [header(), code])
  end

  defp ast_to_string(ast, locals_without_parens, formatter) do
    ast
    |> Code.quoted_to_algebra(locals_without_parens: locals_without_parens)
    |> Inspect.Algebra.format(:infinity)
    |> IO.iodata_to_binary()
    |> formatter.()
  end

  defp formatter_and_opts_for(file_path) do
    Mix.Tasks.Format.formatter_for_file(file_path)
  end

  defp header do
    """
    # This file's contents are auto-generated. Do not edit.
    """
  end

  defp split_comma_delimited(string) do
    string
    |> String.split(",")
    |> Enum.map(&String.trim/1)
  end
end
