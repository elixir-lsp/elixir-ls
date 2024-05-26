defmodule ElixirLS.LanguageServer.Providers.CodeLens.Test.DescribeBlock do
  alias ElixirSense.Core.State.Env

  @struct_keys [:line, :name, :body_scope_id, :module]

  @enforce_keys @struct_keys
  defstruct @struct_keys

  def find_block_info(line, lines_to_env_list, lines_to_env_list_length, source_lines) do
    name = get_name(source_lines, line)

    if name do
      module =
        lines_to_env_list
        |> Enum.find(fn {env_line, _env} -> env_line == line end)
        |> elem(1)
        |> Map.get(:module)

      body_scope_id =
        get_body_scope_id(
          line,
          lines_to_env_list,
          lines_to_env_list_length
        )

      %__MODULE__{line: line, body_scope_id: body_scope_id, name: name, module: module}
    end
  end

  defp get_name(source_lines, declaration_line) do
    case Regex.named_captures(
           ~r/^\s*describe "(?<name>.*)" do/u,
           Enum.at(source_lines, declaration_line - 1)
         ) do
      %{"name" => name} ->
        name

      nil ->
        nil
    end
  end

  defp get_body_scope_id(
         declaration_line,
         lines_to_env_list,
         lines_to_env_list_length
       ) do
    env_index =
      lines_to_env_list
      |> Enum.find_index(fn {line, _env} -> line == declaration_line end)

    {_line, %{scope_id: declaration_scope_id}} =
      lines_to_env_list
      |> Enum.at(env_index)

    with true <- env_index + 1 < lines_to_env_list_length,
         next_env = Enum.at(lines_to_env_list, env_index + 1),
         {_line, %Env{scope_id: body_scope_id}} <- next_env,
         true <- body_scope_id != declaration_scope_id do
      body_scope_id
    else
      _ -> nil
    end
  end
end
