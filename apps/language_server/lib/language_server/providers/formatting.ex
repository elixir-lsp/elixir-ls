defmodule ElixirLS.LanguageServer.Providers.Formatting do
  alias ElixirLS.LanguageServer.SourceFile

  def supported? do
    :erlang.function_exported(Code, :format_string!, 2)
  end

  def options(settings) do
    opts = []
    opts =
      case settings["formatterLineLength"] do
        %{"formatterLineLength" => line_length} when is_integer(line_length) ->
          [{:line_length, line_length} | opts]
        _ ->
          opts
      end

    # TODO: other settings

    opts
  end

  def format(source_file, opts) do
    formatted = Code.format_string!(source_file.text, opts)

    response = [
      %{"newText" => to_string(formatted), "range" => SourceFile.full_range(source_file)}
    ]

    {:ok, response}
  end
end
