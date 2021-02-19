defmodule ElixirLS.LanguageServer.Providers.FoldingRange.Helpers do
  @moduledoc false

  def first_and_last_of_list([]), do: :empty_list

  def first_and_last_of_list([head | tail]) do
    tail
    |> List.last()
    |> case do
      nil -> {head, head}
      last -> {head, last}
    end
  end
end
