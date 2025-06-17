defmodule ElixirLS.LanguageServer.Test.TestUtils do
  alias GenLSP.Structures.TextEdit
  alias ElixirLS.LanguageServer.SourceFile

  def apply_text_edit(text, %TextEdit{} = text_edit) do
    %GenLSP.Structures.TextEdit{range: range, new_text: new_text} = text_edit
    SourceFile.apply_edit(text, range, new_text)
  end
end
