defmodule ElixirLS.LanguageServer.Test.TestUtils do
  alias ElixirLS.LanguageServer.Protocol.TextEdit
  alias ElixirLS.LanguageServer.SourceFile

  def apply_text_edit(text, %TextEdit{} = text_edit) do
    %TextEdit{range: range, newText: new_text} = text_edit

    SourceFile.apply_edit(text, range, new_text)
  end
end
