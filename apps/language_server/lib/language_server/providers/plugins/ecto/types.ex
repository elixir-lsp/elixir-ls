defmodule ElixirLS.LanguageServer.Plugins.Ecto.Types do
  @moduledoc false

  alias ElixirSense.Core.Introspection
  alias ElixirLS.LanguageServer.Plugins.Util
  alias ElixirLS.Utils.Matcher

  # We'll keep these values hard-coded until Ecto provides the same information
  # using docs' metadata.

  @ecto_types [
    {":string", "string UTF-8 encoded", "\"hello\"", nil},
    {":boolean", "boolean", "true, false", nil},
    {":integer", "integer", "1, 2, 3", nil},
    {":float", "float", "1.0, 2.0, 3.0", nil},
    {":decimal", "Decimal", nil, nil},
    {":id", "integer", "1, 2, 3", nil},
    {":date", "Date", nil, nil},
    {":time", "Time", nil, nil},
    {":time_usec", "Time", nil, nil},
    {":naive_datetime", "NaiveDateTime", nil, nil},
    {":naive_datetime_usec", "NaiveDateTime", nil, nil},
    {":utc_datetime", "DateTime", nil, nil},
    {":utc_datetime_usec", "DateTime", nil, nil},
    {"{:array, inner_type}", "list", "[value, value, ...]", "{:array, ${1:inner_type}}"},
    {":map", "map", nil, nil},
    {"{:map, inner_type}", "map", nil, "{:map, ${1:inner_type}}"},
    {":binary_id", "binary", "<<int, int, int, ...>>", nil},
    {":binary", "binary", "<<int, int, int, ...>>", nil}
  ]

  def find_builtin_types(hint, cursor_context) do
    text_before = cursor_context.text_before
    text_after = cursor_context.text_after

    actual_hint =
      if String.ends_with?(text_before, "{" <> hint) do
        "{" <> hint
      else
        hint
      end

    for {name, _, _, _} = type <- @ecto_types,
        Matcher.match?(name, actual_hint) do
      buitin_type_to_suggestion(type, actual_hint, text_after)
    end
  end

  def find_custom_types(hint, module_store) do
    for module <- Map.get(module_store.by_behaviour, Ecto.Type, []),
        type_str = inspect(module),
        Util.match_module?(type_str, hint) do
      custom_type_to_suggestion(module, hint)
    end
  end

  defp buitin_type_to_suggestion({type, elixir_type, literal_syntax, snippet}, hint, text_after) do
    [_, hint_prefix] = Regex.run(~r/(.*?)[\w0-9\._!\?\->]*$/u, hint)

    insert_text = String.replace_prefix(type, hint_prefix, "")
    snippet = snippet && String.replace_prefix(snippet, hint_prefix, "")

    {insert_text, snippet} =
      if String.starts_with?(text_after, "}") do
        snippet = snippet && String.replace_suffix(snippet, "}", "")
        insert_text = String.replace_suffix(insert_text, "}", "")
        {insert_text, snippet}
      else
        {insert_text, snippet}
      end

    literal_syntax_info =
      if literal_syntax, do: "* **Literal syntax:** `#{literal_syntax}`", else: ""

    doc = """
    Built-in Ecto type.

    * **Elixir type:** `#{elixir_type}`
    #{literal_syntax_info}\
    """

    %{
      type: :generic,
      kind: :type_parameter,
      label: type,
      insert_text: insert_text,
      snippet: snippet,
      detail: "Ecto type",
      documentation: doc,
      priority: 0
    }
  end

  defp custom_type_to_suggestion(type, hint) do
    type_str = inspect(type)
    {doc, _} = Introspection.get_module_docs_summary(type)

    %{
      type: :generic,
      kind: :type_parameter,
      label: type_str,
      insert_text: Util.trim_leading_for_insertion(hint, type_str),
      detail: "Ecto custom type",
      documentation: doc,
      priority: 1
    }
  end
end
