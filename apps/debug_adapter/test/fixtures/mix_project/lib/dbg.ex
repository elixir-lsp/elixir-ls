defmodule MixProject.Dbg do
  def simple() do
    a = 5
    b = __ENV__.file |> dbg()
    c = String.split(b, "/", trim: true) |> dbg()
    d = List.last(c) |> dbg()
    File.exists?(d)
  end

  def pipe() do
    a = 5

    __ENV__.file
    |> String.split("/", trim: true)
    |> List.last()
    |> File.exists?()
    |> dbg()
  end

  def pipe_multi_stage() do
    __ENV__.file
    |> Path.dirname()
    |> Path.split()
    |> Enum.reject(&(&1 == ""))
    |> Enum.map(&String.upcase/1)
    |> Enum.join("/")
    |> dbg()
  end

  def case_pipe_dbg(arg \\ {:ok, ["a", "b"]}) do
    case arg do
      {:ok, list} ->
        list
        |> Enum.reverse()
        |> Enum.map(&String.upcase/1)
        |> Enum.join("/")
        |> dbg()

      {:error, reason} ->
        reason
        |> Atom.to_string()
        |> dbg()
    end
  end
end
