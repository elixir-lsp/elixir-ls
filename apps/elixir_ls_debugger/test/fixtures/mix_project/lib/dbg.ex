if Version.match?(System.version(), ">= 1.14.0-dev") do
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
  end
end
