defmodule ElixirLS.LanguageServer.Providers.CodeAction do
  use ElixirLS.LanguageServer.Protocol

  alias ElixirLS.LanguageServer.SourceFile

  @variable_is_unused ~r/variable "(.*)" is unused/

  def code_actions(uri, diagnostics, source_file) do
    actions =
      diagnostics
      |> Enum.map(fn diagnostic -> actions(uri, diagnostic, source_file) end)
      |> List.flatten()

    {:ok, actions}
  end

  defp actions(uri, %{"message" => message} = diagnostic, source_file) do
    [
      {@variable_is_unused, &prefix_with_underscore/3},
      {@variable_is_unused, &remove_variable/3}
    ]
    |> Enum.filter(fn {r, _fun} -> String.match?(message, r) end)
    |> Enum.map(fn {_r, fun} -> fun.(uri, diagnostic, source_file) end)
  end

  defp prefix_with_underscore(uri, %{"message" => message, "range" => range}, source_file) do
    [_, variable] = Regex.run(@variable_is_unused, message)

    start_line = start_line_from_range(range)

    source_line =
      source_file
      |> SourceFile.lines()
      |> Enum.at(start_line)

    pattern = Regex.compile!("(?<![[:alnum:]._])#{variable}(?![[:alnum:]._])")

    if pattern |> Regex.scan(source_line) |> length() == 1 do
      %{
        "title" => "Add '_' to unused variable",
        "kind" => "quickfix",
        "edit" => %{
          "changes" => %{
            uri => [
              %{
                "newText" => String.replace(source_line, pattern, "_" <> variable),
                "range" => range(start_line, 0, start_line, String.length(source_line))
              }
            ]
          }
        }
      }
    else
      []
    end
  end

  defp remove_variable(uri, %{"range" => range}, _source_file) do
    %{
      "title" => "Remove unused variable",
      "kind" => "quickfix",
      "edit" => %{
        "changes" => %{
          uri => [
            %{
              "newText" => "",
              "range" => range
            }
          ]
        }
      }
    }
  end

  defp start_line_from_range(%{"start" => %{"line" => start_line}}), do: start_line
end
