defmodule ElixirLS.LanguageServer.MarkdownUtils do
  @hash_match ~r/(?<!\\)(?<!\w)(#+)(?=\s)/u
  # Find the lowest heading level in the fragment
  defp lowest_heading_level(fragment) do
    case Regex.scan(@hash_match, fragment) do
      [] ->
        nil

      matches ->
        matches
        |> Enum.map(fn [_, heading] -> String.length(heading) end)
        |> Enum.min()
    end
  end

  # Adjust heading levels of an embedded markdown fragment
  def adjust_headings(fragment, base_level) do
    min_level = lowest_heading_level(fragment)

    if min_level do
      level_difference = base_level + 1 - min_level

      Regex.replace(@hash_match, fragment, fn _, capture ->
        adjusted_level = String.length(capture) + level_difference
        String.duplicate("#", adjusted_level)
      end)
    else
      fragment
    end
  end

  def join_with_horizontal_rule(list) do
    Enum.map_join(list, "\n\n---\n\n", fn lines ->
      lines
      |> String.replace_leading("\r\n", "")
      |> String.replace_leading("\n", "")
      |> String.replace_trailing("\r\n", "")
      |> String.replace_trailing("\n", "")
    end) <> "\n"
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

  defp get_metadata_entry_md({:implementing_module_app, app}) do
    "**Behaviour defined in application** #{inspect(app)}"
  end

  defp get_metadata_entry_md({:optional, true}) do
    "**Optional**"
  end

  defp get_metadata_entry_md({:optional, false}), do: nil

  defp get_metadata_entry_md({:overridable, true}) do
    "**Overridable**"
  end

  defp get_metadata_entry_md({:overridable, false}), do: nil

  defp get_metadata_entry_md({:opaque, true}) do
    "**Opaque**"
  end

  defp get_metadata_entry_md({:defaults, _}), do: nil

  defp get_metadata_entry_md({:delegate_to, {m, f, a}}) do
    "**Delegates to** #{inspect(m)}.#{f}/#{a}"
  end

  defp get_metadata_entry_md({key, value}) do
    "**#{key}** #{inspect(value)}"
  end
end
