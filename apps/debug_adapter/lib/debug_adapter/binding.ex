defmodule ElixirLS.DebugAdapter.Binding do
  def to_elixir_variable_names(bindings) do
    bindings
    |> Enum.group_by(fn {key, _} -> get_elixir_variable(key) end)
    # filter out underscore binding as those are invalid in elixir
    |> Enum.reject(fn
      {:"", _} ->
        true

      {classic_key, _} ->
        classic_key |> Atom.to_string() |> String.starts_with?("_")
    end)
    |> Enum.map(fn {classic_key, list} ->
      # assume binding with highest number is the current one
      # this may not be always true, e.g. in
      # a = 5
      # if true do
      #   a = 4
      # end
      # results in _a@1 = 5 and _a@2 = 4
      # but we have no way of telling which one is current
      {_, last_value} = list |> Enum.max_by(fn {key, _} -> key end)
      {classic_key, last_value}
    end)
  end

  def get_elixir_variable(key) do
    # binding is present with prefix _ and postfix @
    # for example _key@1 and _value@1 are representations of current function variables
    key
    |> Atom.to_string()
    |> String.replace(~r/_(.*)@\d+/, "\\1")
    |> String.to_atom()
  end

  def get_number(key) do
    key
    |> Atom.to_string()
    |> String.replace(~r/_.*@(\d+)/, "\\1")
    |> String.to_integer()
  end
end
