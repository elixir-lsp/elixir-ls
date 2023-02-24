defmodule ElixirLS.Experimental.Provider.Handlers.HoverTest do
  use ExUnit.Case, async: true

  alias ElixirLS.LanguageServer.Experimental.Protocol.Requests.Hover
  alias ElixirLS.LanguageServer.Experimental.Provider.Env
  alias ElixirLS.LanguageServer.Experimental.Provider.Handlers
  alias ElixirLS.LanguageServer.Experimental.SourceFile
  alias ElixirLS.LanguageServer.Experimental.SourceFile.Conversions
  alias ElixirLS.LanguageServer.Fixtures.LspProtocol

  import LspProtocol

  import ElixirLS.LanguageServer.Test.PlatformTestHelpers,
    only: [maybe_convert_path_separators: 1]

  setup do
    {:ok, _} = start_supervised(SourceFile.Store)
    :ok
  end

  defp fake_dir() do
    Path.join(__DIR__, "../../../../../..") |> Path.expand() |> maybe_convert_path_separators()
  end

  def build_request(text, line, char) do
    uri =
      fake_dir()
      |> Path.join("hoverable.ex")
      |> Conversions.ensure_uri()

    params = [
      text_document: [uri: uri],
      position: [line: line, character: char]
    ]

    with :ok <- SourceFile.Store.open(uri, text, 1),
         {:ok, req} <- build(Hover, params) do
      Hover.to_elixir(req)
    end
  end

  def handle(request) do
    Handlers.Hover.handle(request, %Env{project_path: fake_dir()})
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
    {:ok, request} = build_request(text, line, char)

    {:reply, response} = handle(request)

    assert %{error: nil, result: nil} = response
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
    {:ok, request} = build_request(text, line, char)

    {:reply, response} = handle(request)

    assert %{result: %{contents: %{kind: "markdown", value: v}, range: range}} = response
    assert String.starts_with?(v, "> IO  [view on hexdocs](https://hexdocs.pm/elixir/IO.html)")

    assert range.start.line == 2
    assert range.start.character == 4
    assert range.end.line == 2
    assert range.end.character == 6
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
    {:ok, request} = build_request(text, line, char)

    {:reply, response} = handle(request)

    assert %{result: %{contents: %{kind: "markdown", value: v}, range: range}} = response

    assert String.starts_with?(
             v,
             "> IO.inspect(item, opts \\\\\\\\ [])  [view on hexdocs](https://hexdocs.pm/elixir/IO.html#inspect/2)"
           )

    assert range.start.line == 2
    assert range.start.character == 4
    assert range.end.line == 2
    assert range.end.character == 14
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

    {:ok, request} = build_request(text, line, char)

    {:reply, response} = handle(request)

    assert %{result: %{contents: %{kind: "markdown", value: v}}} = response

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

    {:ok, request} = build_request(text, line, char)

    {:reply, response} = handle(request)

    assert %{result: %{contents: %{kind: "markdown", value: v}}} = response

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

    {:ok, request} = build_request(text, line, char)

    {:reply, response} = handle(request)

    assert %{result: %{contents: %{kind: "markdown", value: v}}} = response

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

    {:ok, request} = build_request(text, line, char)

    {:reply, response} = handle(request)

    assert %{result: %{contents: %{kind: "markdown", value: v}}} = response

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

    {:ok, request} = build_request(text, line, char)

    {:reply, response} = handle(request)

    assert %{result: %{contents: %{kind: "markdown", value: v}}} = response

    assert not String.contains?(
             v,
             "[view on hexdocs]"
           )
  end
end
