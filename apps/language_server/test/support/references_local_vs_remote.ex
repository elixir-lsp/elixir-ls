defmodule ElixirSenseExample.ReferencesLocalVsRemote do
  defmodule SubModule do
    def abc(), do: :ok

    def cde(), do: abc()
  end

  @type t :: %ElixirSenseExample.ReferencesLocalVsRemote{
          field: String.t()
        }
  defstruct field: ""

  def my_fun(arg) do
    :ok
  end
end

defmodule ElixirSenseExample.ReferencesLocalVsRemoteCaller do
  alias ElixirSenseExample.ReferencesLocalVsRemote, as: M

  @spec process(M.t()) :: :ok
  def process(%M{} = struct) do
    M.my_fun(struct)
  end

  def abc() do
    import Enum
    require Logger

    Logger.info("abc")
    Enum.map([1, 2, 3], fn x -> x + 1 end)
    map([1, 2, 3], fn x -> x + 1 end)
  end
end
