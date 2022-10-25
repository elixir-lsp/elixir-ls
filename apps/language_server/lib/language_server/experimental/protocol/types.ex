defmodule ElixirLS.LanguageServer.Experimental.Protocol.Types do
  defmodule Position do
    defstruct [:line, :character]

    def new(opts \\ []) do
      line = Keyword.get(opts, :line, 0)
      character = Keyword.get(opts, :character, 0)
      %__MODULE__{line: line, character: character}
    end
  end

  defmodule Range do
    defstruct [:start, :end]

    def new(opts \\ []) do
      start_pos = Keyword.get(opts, :start, Position.new())
      end_pos = Keyword.get(opts, :end, Position.new())
      %__MODULE__{start: start_pos, end: end_pos}
    end
  end
end
