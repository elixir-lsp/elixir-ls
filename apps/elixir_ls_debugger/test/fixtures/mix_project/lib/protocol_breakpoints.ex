defprotocol Proto do
  def go(t)
end

defimpl Proto, for: [List, BitString] do
  def go(t) do
    IO.inspect(t)
  end
end

defprotocol DerivedProto do
  def go(t)
end

defimpl DerivedProto, for: Any do
  defmacro __deriving__(module, _struct, _options) do
    quote do
      defimpl unquote(@protocol), for: unquote(module) do
        def go(term) do
          IO.puts("")
        end
      end
    end
  end

  def go(term) do
    raise Protocol.UndefinedError, protocol: @protocol, value: term
  end
end

defmodule MyStruct do
  @derive [{DerivedProto, []}]
  defstruct [:a]
end

defmodule ProtocolBreakpoints do
  def go1() do
    Proto.go([])
    Proto.go("")
  end

  def go2() do
    DerivedProto.go(%MyStruct{})
  end
end
