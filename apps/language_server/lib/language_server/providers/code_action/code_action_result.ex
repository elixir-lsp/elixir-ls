defmodule ElixirLS.LanguageServer.Providers.CodeAction.CodeActionResult do
  alias ElixirLS.LanguageServer.Protocol.TextEdit

  @type t :: %{
          title: String.t(),
          kind: String.t(),
          edit: %{
            changes: %{String.t() => TextEdit.t()}
          }
        }

  @spec new(String.t(), String.t(), [TextEdit.t()], String.t()) :: t()
  def new(title, kind, text_edits, uri) do
    %{
      :title => title,
      :kind => kind,
      :edit => %{
        :changes => %{
          uri => text_edits
        }
      }
    }
  end
end
