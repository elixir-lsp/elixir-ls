# This file's contents are auto-generated. Do not edit.
defmodule ElixirLS.LanguageServer.Experimental.Protocol.Types.FailureHandling.Kind do
  alias ElixirLS.LanguageServer.Experimental.Protocol.Proto
  use Proto

  defenum abort: "abort",
          transactional: "transactional",
          text_only_transactional: "textOnlyTransactional",
          undo: "undo"
end
