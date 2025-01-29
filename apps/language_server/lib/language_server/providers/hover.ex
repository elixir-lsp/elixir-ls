defmodule ElixirLS.LanguageServer.Providers.Hover do
  alias ElixirLS.LanguageServer.{SourceFile, DocLinks, Parser}
  import ElixirLS.LanguageServer.Protocol
  alias ElixirLS.LanguageServer.MarkdownUtils
  alias ElixirLS.LanguageServer.Providers.Hover.Docs
  require Logger

  @moduledoc """
  textDocument/hover provider utilizing Elixir Sense
  """

  def hover(%Parser.Context{source_file: source_file, metadata: metadata}, line, character) do
    response =
      case Docs.docs(source_file.text, line, character, metadata: metadata) do
        nil ->
          nil

        %{docs: docs, range: es_range} ->
          lines = SourceFile.lines(source_file.text)

          %{
            "contents" => contents(docs),
            "range" => build_range(lines, es_range)
          }
      end

    {:ok, response}
  end

  ## Helpers

  def build_range(lines, %{begin: {begin_line, begin_char}, end: {end_line, end_char}}) do
    range(
      begin_line - 1,
      SourceFile.elixir_character_to_lsp(lines |> Enum.at(begin_line - 1, ""), begin_char),
      end_line - 1,
      SourceFile.elixir_character_to_lsp(lines |> Enum.at(end_line - 1, ""), end_char)
    )
  end

  defp contents(docs) do
    markdown_value =
      docs
      |> Enum.map(&format_doc/1)
      |> MarkdownUtils.join_with_horizontal_rule()

    %{
      kind: "markdown",
      value: markdown_value
    }
  end

  defp build_module_link(module) do
    if ElixirSense.Core.Introspection.elixir_module?(module) do
      url = DocLinks.hex_docs_module_link(module)

      if url do
        "[View on hexdocs](#{url})\n\n"
      else
        ""
      end
    else
      ""
    end
  end

  defp build_function_link(module, function, arity) do
    if ElixirSense.Core.Introspection.elixir_module?(module) do
      url = DocLinks.hex_docs_function_link(module, function, arity)

      if url do
        "[View on hexdocs](#{url})\n\n"
      else
        ""
      end
    else
      ""
    end
  end

  defp build_type_link(module, type, arity) do
    if module != nil and ElixirSense.Core.Introspection.elixir_module?(module) do
      url = DocLinks.hex_docs_type_link(module, type, arity)

      if url do
        "[View on hexdocs](#{url})\n\n"
      else
        ""
      end
    else
      ""
    end
  end

  defp format_doc(info = %{kind: :module}) do
    mod_str = inspect(info.module)

    """
    ```elixir
    #{mod_str}
    ```

    *module* #{build_module_link(info.module)}

    #{MarkdownUtils.get_metadata_md(info.metadata)}

    #{documentation_section(info.docs) |> MarkdownUtils.transform_ex_doc_links(info.module)}
    """
  end

  defp format_doc(info = %{kind: kind}) when kind in [:function, :macro] do
    mod_str = inspect(info.module)
    fun_str = Atom.to_string(info.function)

    spec_text =
      if info.specs != [] do
        joined = Enum.join(info.specs, "\n")

        """
        ### Specs

        ```elixir
        #{joined}
        ```

        """
      else
        ""
      end

    function_name =
      "#{mod_str}.#{fun_str}(#{Enum.join(info.args, ", ")})"
      |> format_header

    """
    ```elixir
    #{function_name}
    ```

    *#{kind}* #{build_function_link(info.module, info.function, info.arity)}

    #{MarkdownUtils.get_metadata_md(info.metadata)}

    #{spec_text}

    #{documentation_section(info.docs) |> MarkdownUtils.transform_ex_doc_links(info.module)}
    """
  end

  defp format_doc(info = %{kind: :type}) do
    formatted_spec = "```elixir\n#{info.spec}\n```"

    mod_formatted =
      case info.module do
        nil -> ""
        atom -> inspect(atom) <> "."
      end

    type_name =
      "#{mod_formatted}#{info.type}(#{Enum.join(info.args, ", ")})"
      |> format_header

    """
    ```elixir
    #{type_name}
    ```

    *type* #{build_type_link(info.module, info.type, info.arity)}

    #{MarkdownUtils.get_metadata_md(info.metadata)}

    ### Definition

    #{formatted_spec}

    #{documentation_section(info.docs) |> MarkdownUtils.transform_ex_doc_links(info.module)}
    """
  end

  defp format_doc(info = %{kind: :variable}) do
    """
    ```elixir
    #{info.name}
    ```

    *variable*
    """
  end

  defp format_doc(info = %{kind: :attribute}) do
    """
    ```elixir
    @#{info.name}
    ```

    *module attribute*

    #{documentation_section(info.docs)}
    """
  end

  defp format_doc(info = %{kind: :keyword}) do
    """
    ```elixir
    #{info.name}
    ```

    *reserved word*

    #{documentation_section(info.docs)}
    """
  end

  defp documentation_section(""), do: ""

  defp documentation_section(docs) do
    if String.valid?(docs) do
      """
      ### Documentation

      #{MarkdownUtils.adjust_headings(docs, 3)}
      """
    else
      # some people have weird docs that are not valid UTF-8
      Logger.warning("Invalid docs for hover: #{inspect(docs)}")
      ""
    end
  end

  defp format_header(text) do
    text
    |> Code.format_string!(line_length: 40)
    |> to_string
  rescue
    _ ->
      # Code.format_string! can raise SyntaxError e.g.
      # for Kernel...(first, last)
      text
  end
end
