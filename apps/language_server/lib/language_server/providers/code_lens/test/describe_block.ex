defmodule ElixirLS.LanguageServer.Providers.CodeLens.Test.DescribeBlock do
  alias ElixirSense.Core.State.Env

  @struct_keys [:line, :name, :body_scope_id]

  @enforce_keys @struct_keys
  defstruct @struct_keys

  def find_block_info(line, lines_to_env_list, lines_to_env_list_length, source_lines) do
    name = get_name(source_lines, line)

    body_scope_id =
      get_body_scope_id(
        line,
        lines_to_env_list,
        lines_to_env_list_length
      )

    %__MODULE__{line: line, body_scope_id: body_scope_id, name: name}
  end

  defp get_name(source_lines, declaration_line) do
    %{"name" => name} =
      ~r/^\s*describe "(?<name>.*)" do/
      |> Regex.named_captures(Enum.at(source_lines, declaration_line - 1))

    name
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
