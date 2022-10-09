defmodule ElixirLS.LanguageServer.Providers.CodeAction do
  use ElixirLS.LanguageServer.Protocol

  def code_actions(uri, diagnostics) do
    actions =
      diagnostics
      |> Enum.map(fn diagnostic -> actions(uri, diagnostic) end)
      |> List.flatten()

    {:ok, actions}
  end

  defp actions(uri, %{"message" => message} = diagnostic) do
    [
      {~r/variable "(.*)" is unused/, &prefix_with_underscore/2},
      {~r/variable "(.*)" is unused/, &remove_variable/2}
    ]
    |> Enum.filter(fn {r, _fun} -> String.match?(message, r) end)
    |> Enum.map(fn {_r, fun} -> fun.(uri, diagnostic) end)
  end

  defp prefix_with_underscore(uri, %{"range" => range}) do
    %{
      "title" => "Add '_' to unused variable",
      "kind" => "quickfix",
      "edit" => %{
        "changes" => %{
          uri => [
            %{
              "newText" => "_",
              "range" =>
                range(
                  range["start"]["line"],
                  range["start"]["character"],
                  range["start"]["line"],
                  range["start"]["character"]
                )
            }
          ]
        }
      }
    }
  end

  defp remove_variable(uri, %{"range" => range}) do
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
end
