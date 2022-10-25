defmodule ElixirLS.LanguageServer.Experimental.Protocol.Proto.Macros.Typespec do
  def build(_opts \\ []) do
    quote do
      @type t :: %__MODULE__{}
    end
  end
end
