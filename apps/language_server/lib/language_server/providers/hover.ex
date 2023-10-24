defmodule ElixirLS.LanguageServer.Providers.Hover do
  alias ElixirLS.LanguageServer.{SourceFile, DocLinks}
  import ElixirLS.LanguageServer.Protocol
  alias ElixirLS.LanguageServer.MarkdownUtils

  @moduledoc """
  Hover provider utilizing Elixir Sense
  """

  def hover(text, line, character, _project_dir) do
    {line, character} = SourceFile.lsp_position_to_elixir(text, {line, character})

    response =
      case ElixirSense.docs(text, line, character) do
        nil ->
          nil

        %{docs: docs, range: es_range} ->
          lines = SourceFile.lines(text)

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
      SourceFile.elixir_character_to_lsp(lines |> Enum.at(begin_line - 1), begin_char),
      end_line - 1,
      SourceFile.elixir_character_to_lsp(lines |> Enum.at(end_line - 1), end_char)
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

    #{get_metadata_md(info.metadata)}

    #{documentation_section(info.docs)}
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

    #{get_metadata_md(info.metadata)}

    #{spec_text}

    #{documentation_section(info.docs)}
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

    #{get_metadata_md(info.metadata)}

    ### Definition

    #{formatted_spec}

    #{documentation_section(info.docs)}
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
    """
    ### Documentation

    #{MarkdownUtils.adjust_headings(docs, 3)}
    """
  end

  def get_metadata_md(metadata) do
    text =
      metadata
      |> Enum.sort()
      |> Enum.map(&get_metadata_entry_md/1)
      |> Enum.reject(&is_nil/1)
      |> Enum.join("\n\n")

    case text do
      "" -> ""
      not_empty -> not_empty <> "\n\n"
    end
  end

  # erlang name
  defp get_metadata_entry_md({:name, _text}), do: nil

  # erlang signature
  defp get_metadata_entry_md({:signature, _text}), do: nil

  # erlang edit_url
  defp get_metadata_entry_md({:edit_url, _text}), do: nil

  # erlang :otp_doc_vsn
  defp get_metadata_entry_md({:otp_doc_vsn, _text}), do: nil

  # erlang :source
  defp get_metadata_entry_md({:source, _text}), do: nil

  # erlang :types
  defp get_metadata_entry_md({:types, _text}), do: nil

  # erlang :equiv
  defp get_metadata_entry_md({:equiv, {:function, name, arity}}) do
    "**Equivalent** #{name}/#{arity}"
  end

  defp get_metadata_entry_md({:deprecated, text}) do
    "**Deprecated** #{text}"
  end

  defp get_metadata_entry_md({:since, text}) do
    "**Since** #{text}"
  end

  defp get_metadata_entry_md({:group, text}) do
    "**Group** #{text}"
  end

  defp get_metadata_entry_md({:guard, true}) do
    "**Guard**"
  end

  defp get_metadata_entry_md({:hidden, true}) do
    "**Hidden**"
  end

  defp get_metadata_entry_md({:builtin, true}) do
    "**Built-in**"
  end

  defp get_metadata_entry_md({:implementing, module}) do
    "**Implementing behaviour** #{inspect(module)}"
  end

  defp get_metadata_entry_md({:optional, true}) do
    "**Optional**"
  end

  defp get_metadata_entry_md({:optional, false}), do: nil

  defp get_metadata_entry_md({:opaque, true}) do
    "**Opaque**"
  end

  defp get_metadata_entry_md({:defaults, _}), do: nil

  defp get_metadata_entry_md({:delegate_to, {m, f, a}}) do
    "**Delegates to** #{inspect(m)}.#{f}/#{a}"
  end

  defp get_metadata_entry_md({key, value}) do
    "**#{key}** #{value}"
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
