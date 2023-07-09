defprotocol Proto do
  def go(t)
end

defimpl Proto, for: [List, BitString] do
  def go(t) do
    IO.inspect(t)
  end
end

defmodule ProtocolBreakpoints do
  def go1() do
    Proto.go([])
    Proto.go("")
  end
end
