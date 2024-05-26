defmodule ElixirSenseExample.IO.Stream do
  defstruct [
    :device,
    :line_or_bytes,
    :raw
  ]

  @type t() :: %ElixirSenseExample.IO.Stream{
          device: IO.device(),
          line_or_bytes: :line | non_neg_integer(),
          raw: boolean()
        }
end
