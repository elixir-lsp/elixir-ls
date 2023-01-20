defmodule ElixirLS.LanguageServer.Experimental.SourceFile.Line do
  import Record

  defrecord :line, text: nil, ending: nil, line_number: 0, ascii?: true

  @type t :: tuple()
end
