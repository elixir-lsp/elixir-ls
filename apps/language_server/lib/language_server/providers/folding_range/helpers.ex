defmodule ElixirLS.LanguageServer.Providers.FoldingRange.Helpers do
  @moduledoc """
  """
  def first_and_last_of_list([]), do: :empty_list

  def first_and_last_of_list(list) when is_list(list) do
    [head | tail] = list
    do_falo_list(tail, head)
  end

  defp do_falo_list([], first), do: {first, first}
  defp do_falo_list([last | []], first), do: {first, last}
  defp do_falo_list([_ | tail], first), do: do_falo_list(tail, first)
end
