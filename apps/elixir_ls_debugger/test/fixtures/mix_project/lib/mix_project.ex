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

defmodule MixProject.Some do
  def double(y) do
    2 * y
  end

  def quadruple(x) do
    double(double(x))
  end

  def sleep do
    Supervisor.start_link([], strategy: :one_for_one, name: __MODULE__)
    Process.sleep(:infinity)
  end
end

defmodule Some do
  def fun_1(x) do
    a = fun_3(x + 1)
    b = fun_2(a)
    b * 2
  end

  def fun_2(x) do
    a = fun_3(x + 2)
    b = a + x
    b * 2
  end

  def fun_3(x) do
    x + 9
  end

  def multiple(x) do
    Task.start(fn ->
      fun_2(3)
    end)

    x + 2
  end
end
