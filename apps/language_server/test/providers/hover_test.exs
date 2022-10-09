defmodule ElixirLS.LanguageServer.Providers.HoverTest do
  use ElixirLS.Utils.MixTest.Case, async: false
  import ElixirLS.LanguageServer.Test.PlatformTestHelpers

  alias ElixirLS.LanguageServer.Providers.Hover
  # mix cmd --app language_server mix test test/providers/hover_test.exs

  def fake_dir() do
    Path.join(__DIR__, "../../../..") |> Path.expand() |> maybe_convert_path_separators()
  end

  test "blank hover" do
    text = """
    defmodule MyModule do
      def hello() do
        IO.inspect("hello world")
      end
    end
    """

    {line, char} = {2, 1}

    assert {:ok, resp} = Hover.hover(text, line, char, fake_dir())
    assert nil == resp
  end

  test "Elixir builtin module hover" do
    text = """
    defmodule MyModule do
      def hello() do
        IO.inspect("hello world")
      end
    end
    """

    {line, char} = {2, 5}

    assert {:ok, %{"contents" => %{kind: "markdown", value: v}}} =
             Hover.hover(text, line, char, fake_dir())

    assert String.starts_with?(v, "> IO  [view on hexdocs](https://hexdocs.pm/elixir/IO.html)")
  end

  test "Elixir builtin function hover" do
    text = """
    defmodule MyModule do
      def hello() do
        IO.inspect("hello world")
      end
    end
    """

    {line, char} = {2, 10}

    assert {:ok, %{"contents" => %{kind: "markdown", value: v}}} =
             Hover.hover(text, line, char, fake_dir())

    assert String.starts_with?(
             v,
             "> IO.inspect(item, opts \\\\\\\\ [])  [view on hexdocs](https://hexdocs.pm/elixir/IO.html#inspect/2)"
           )
  end

  test "Umbrella projects: Third deps module hover" do
    text = """
    defmodule MyModule do
      def hello() do
        StreamData.integer() |> Stream.map(&abs/1) |> Enum.take(3) |> IO.inspect()
      end
    end
    """

    {line, char} = {2, 10}

    assert {:ok, %{"contents" => %{kind: "markdown", value: v}}} =
             Hover.hover(text, line, char, fake_dir())

    assert String.starts_with?(
             v,
             "> StreamData  [view on hexdocs](https://hexdocs.pm/stream_data/StreamData.html)"
           )
  end

  test "Umbrella projects: Third deps function hover" do
    text = """
    defmodule MyModule do
      def hello() do
        StreamData.integer() |> Stream.map(&abs/1) |> Enum.take(3) |> IO.inspect()
      end
    end
    """

    {line, char} = {2, 18}

    assert {:ok, %{"contents" => %{kind: "markdown", value: v}}} =
             Hover.hover(text, line, char, fake_dir())

    assert String.starts_with?(
             v,
             "> StreamData.integer()  [view on hexdocs](https://hexdocs.pm/stream_data/StreamData.html#integer/0)"
           )
  end

  test "Import function hover" do
    text = """
    defmodule MyModule do
      import Task.Supervisor

      def hello() do
        start_link()
      end
    end
    """

    {line, char} = {4, 5}

    assert {:ok, %{"contents" => %{kind: "markdown", value: v}}} =
             Hover.hover(text, line, char, fake_dir())

    assert String.starts_with?(
             v,
             "> Task.Supervisor.start_link(options \\\\\\\\ [])  [view on hexdocs](https://hexdocs.pm/elixir/Task.Supervisor.html#start_link/1)"
           )
  end

  test "Alias module function hover" do
    text = """
    defmodule MyModule do
      alias Task.Supervisor

      def hello() do
        Supervisor.start_link()
      end
    end
    """

    {line, char} = {4, 15}

    assert {:ok, %{"contents" => %{kind: "markdown", value: v}}} =
             Hover.hover(text, line, char, fake_dir())

    assert String.starts_with?(
             v,
             "> Task.Supervisor.start_link(options \\\\\\\\ [])  [view on hexdocs](https://hexdocs.pm/elixir/Task.Supervisor.html#start_link/1)"
           )
  end

  test "Erlang module hover is not support now" do
    text = """
    defmodule MyModule do
      def hello() do
        :timer.sleep(1000)
      end
    end
    """

    {line, char} = {2, 10}

    assert {:ok, %{"contents" => %{kind: "markdown", value: v}}} =
             Hover.hover(text, line, char, fake_dir())

    assert not String.contains?(
             v,
             "[view on hexdocs]"
           )
  end
end
