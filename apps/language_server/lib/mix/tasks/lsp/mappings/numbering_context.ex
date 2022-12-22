defmodule Mix.Tasks.Lsp.Mappings.NumberingContext do
  def new do
    Process.put(:numbering, %{})
  end

  def get(name) do
    :numbering
    |> Process.get(%{})
    |> Map.get(name)
  end

  def get_and_increment(name) do
    case Process.get(:numbering, :undefined) do
      :undefined ->
        Process.put(:numbering, %{name => 1})
        0

      %{} = other ->
        {existing, updated} =
          Map.get_and_update(other, name, fn
            nil ->
              {0, 1}

            current ->
              {current, current + 1}
          end)

        Process.put(:numbering, updated)
        existing
    end
  end
end
