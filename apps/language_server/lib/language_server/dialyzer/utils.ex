defmodule ElixirLS.LanguageServer.Dialyzer.Utils do
  require Logger

  @epoch_gregorian_seconds 62_167_219_200

  def check_support do
    _ = String.to_integer(System.otp_release())
    {_compiled_with, _} = System.build_info() |> Map.fetch!(:otp_release) |> Integer.parse()

    cond do
      not Code.ensure_loaded?(:dialyzer) ->
        # TODO is this check relevant? We check for dialyzer app in CLI
        {:error, :no_dialyzer,
         "The current Erlang installation does not include Dialyzer. It may be available as a " <>
           "separate package."}

      not dialyzable?(System) ->
        {:error, :no_debug_info,
         "Dialyzer is disabled because core Elixir modules are missing debug info. " <>
           "You may need to recompile Elixir"}

      true ->
        :ok
    end
  end

  # erl_anno:location() is `line | {line, column}` — accept either shape.
  def normalize_position({line, column}) when line > 0 do
    {line, column}
  end

  # 0 means unknown line
  def normalize_position(line) when line >= 0 do
    line
  end

  def normalize_position(position) do
    Logger.warning(
      "[ElixirLS Dialyzer] dialyzer returned warning with invalid position #{inspect(position)}"
    )

    0
  end

  def warning_message({_, _, {warning_name, args}} = raw_warning, warning_format)
      when warning_format in ["dialyxir_long", "dialyxir_short"] do
    format_function =
      case warning_format do
        "dialyxir_long" -> :format_long
        "dialyxir_short" -> :format_short
      end

    try do
      %{^warning_name => warning_module} = DialyxirVendored.Warnings.warnings()
      <<_::binary>> = apply(warning_module, format_function, [args])
    rescue
      _ -> warning_message(raw_warning, "dialyzer")
    catch
      _ -> warning_message(raw_warning, "dialyzer")
    end
  end

  def warning_message(raw_warning, "dialyzer") do
    dialyzer_raw_warning_message(raw_warning)
  end

  def warning_message(raw_warning, warning_format) do
    Logger.info(
      "[ElixirLS Dialyzer] Unrecognized dialyzerFormat setting: #{inspect(warning_format)}" <>
        ", falling back to \"dialyzer\""
    )

    dialyzer_raw_warning_message(raw_warning)
  end

  defp dialyzer_raw_warning_message(raw_warning) do
    message = String.trim(to_string(:dialyzer.format_warning(raw_warning)))
    Regex.replace(~r/^.*:\d+: /u, message, "")
  end

  @spec dialyzable?(module()) :: boolean()
  def dialyzable?(module) do
    file = get_beam_file(module)

    is_list(file) and match?({:ok, _}, :dialyzer_utils.get_core_from_beam(file))
  end

  @spec get_beam_file(module()) :: charlist() | :preloaded | :non_existing | :cover_compiled
  def get_beam_file(module) do
    case :code.which(module) do
      [_ | _] = file ->
        file

      other ->
        case :code.get_object_code(module) do
          {_module, _binary, beam_filename} -> beam_filename
          :error -> other
        end
    end
  end

  def pathname_to_module(path) do
    String.to_atom(Path.basename(path, ".beam"))
  end

  def expand_references(modules, exclude \\ MapSet.new(), result \\ MapSet.new())

  def expand_references([], _, result) do
    result
  end

  def expand_references([module | rest], exclude, result) do
    result =
      if module in result or module in exclude or not dialyzable?(module) do
        result
      else
        result = MapSet.put(result, module)
        expand_references(module_references(module), exclude, result)
      end

    expand_references(rest, exclude, result)
  end

  # Mix.Utils.last_modified/1 returns a posix time, so we normalize to a :calendar.universal_time()
  def normalize_timestamp(timestamp) when is_integer(timestamp),
    do: :calendar.gregorian_seconds_to_datetime(timestamp + @epoch_gregorian_seconds)

  defp module_references(mod) do
    try do
      for form <- read_forms(mod),
          # TODO does import create remote call?
          {:call, _, {:remote, _, {:atom, _, module}, _}, _} <- form,
          uniq: true,
          do: module
    rescue
      _ -> []
    catch
      _ -> []
    end
  end

  # Read the Erlang abstract forms from the specified Module
  # compiled using the -debug_info compile option
  defp read_forms(module) do
    case :beam_lib.chunks(:code.which(module), [:abstract_code]) do
      {:ok, {^module, [{:abstract_code, {:raw_abstract_v1, forms}}]}} ->
        forms

      {:ok, {:no_debug_info, _}} ->
        throw({:forms_not_found, module})

      {:error, :beam_lib, {:file_error, _, :enoent}} ->
        throw({:module_not_found, module})
    end
  end
end
