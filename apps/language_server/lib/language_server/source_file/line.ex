defmodule ElixirLS.LanguageServer.SourceFile.Line do
  import Record

  defrecord :line, text: nil, ending: nil, line_number: 0
end
