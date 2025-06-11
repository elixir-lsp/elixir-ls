defmodule ElixirLS.LanguageServer.Plugins.Ecto.QueryBindingsTest do
  use ExUnit.Case

  alias ElixirLS.LanguageServer.Plugins.Ecto.Query
  alias ElixirSense.Core.{Source, Parser, Metadata, Binding}

  defp cursor(text) do
    {_, cursors} =
      Source.walk_text(text, {false, []}, fn
        "#", rest, _, _, {_comment?, cursors} -> {rest, {true, cursors}}
        "\n", rest, _, _, {_comment?, cursors} -> {rest, {false, cursors}}
        "^", rest, line, col, {true, cursors} -> {rest, {true, [%{line: line - 1, col: col} | cursors]}}
        _, rest, _, _, acc -> {rest, acc}
      end)

    List.first(Enum.reverse(cursors))
  end

  defp env_and_meta(buffer, {line, col}) do
    metadata = Parser.parse_string(buffer, true, false, {line, col})
    {prefix, suffix} = Source.prefix_suffix(buffer, line, col)

    surround =
      case {prefix, suffix} do
        {"", ""} -> nil
        _ -> {{line, col - String.length(prefix)}, {line, col + String.length(suffix)}}
      end

    env = Metadata.get_cursor_env(metadata, {line, col}, surround)
    {env, metadata}
  end

  defp extract_bindings(buffer) do
    cur = cursor(buffer)
    {env, meta} = env_and_meta(buffer, {cur.line, cur.col})
    prefix = Source.text_before(buffer, cur.line, cur.col)
    binding_env = Binding.from_env(env, meta, {cur.line, cur.col})
    func_info = Source.which_func(prefix, binding_env)
    Query.extract_bindings(prefix, func_info, env, meta)
  end

  test "extract binding from from clause" do
    buffer = """
    import Ecto.Query
    alias ElixirLS.LanguageServer.Plugins.Ecto.FakeSchemas.Post

    from p in Post,
      where: true
      #       ^
    """

    assert %{"p" => %{type: ElixirLS.LanguageServer.Plugins.Ecto.FakeSchemas.Post}} =
             extract_bindings(buffer)
  end

  test "extract bindings from join clauses" do
    buffer = """
    import Ecto.Query
    alias ElixirLS.LanguageServer.Plugins.Ecto.FakeSchemas.Post
    alias ElixirLS.LanguageServer.Plugins.Ecto.FakeSchemas.Comment
    alias ElixirLS.LanguageServer.Plugins.Ecto.FakeSchemas.User

    from(
      p in Post,
      join: c in Comment,
      left_join: u in assoc(p, :user),
      where: true
      #       ^
    )
    """

    result = extract_bindings(buffer)

    assert %{
             "p" => %{type: ElixirLS.LanguageServer.Plugins.Ecto.FakeSchemas.Post},
             "c" => %{type: ElixirLS.LanguageServer.Plugins.Ecto.FakeSchemas.Comment},
             "u" => %{type: ElixirLS.LanguageServer.Plugins.Ecto.FakeSchemas.User}
           } = result
  end
end
