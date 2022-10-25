defmodule ElixirLS.LanguageServer.Experimental.SourceFile.Position do
  defstruct [:line, :character]

  def new(line, character) when is_number(line) and is_number(character) do
    %__MODULE__{line: line, character: character}
  end
end
