defimpl Protocols.Example, for: List do
  def some(t), do: t
end

defimpl Protocols.Example, for: String do
  def some(t), do: t
end
