defmodule MixProject do
  def quadruple(x) do
    double(double(x))
  end

  def double(y) do
    2 * y
  end

  def exit do
    Task.start(fn ->
      Task.start_link(fn ->
        Process.sleep(1000)
        raise "Fixture MixProject expected error"
      end)

      Process.sleep(:infinity)
    end)

    Process.sleep(:infinity)
  end

  def exit_self do
    Task.start_link(fn ->
      Process.sleep(1000)
      raise "Fixture MixProject raise for exit_self/0"
    end)

    Process.sleep(:infinity)
  end
end
