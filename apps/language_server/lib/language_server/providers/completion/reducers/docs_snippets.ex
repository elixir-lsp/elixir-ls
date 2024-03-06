defmodule ElixirLS.LanguageServer.Providers.Completion.Reducers.DocsSnippets do
  @moduledoc false

  # TODO change/move this
  alias ElixirSense.Plugins.Util
  alias ElixirLS.Utils.Matcher

  # Format:
  # {label, snippet, documentation, priority}
  @module_attr_snippets [
    {~s(@doc """"""), ~s(@doc """\n$0\n"""), "Documents a function/macro/callback", 13},
    {"@doc false", "@doc false", "Marks this function/macro/callback as internal", 15},
    {~s(@moduledoc """"""), ~s(@moduledoc """\n$0\n"""), "Documents a module", 13},
    {"@moduledoc false", "@moduledoc false", "Marks this module as internal", 15},
    {~s(@typedoc """"""), ~s(@typedoc """\n$0\n"""), "Documents a type specification", 13},
    {"@typedoc false", "@typedoc false", "Marks this type specification as internal", 15}
  ]

  @doc """
  A reducer that adds suggestions for @doc, @moduledoc and @typedoc.
  """
  def add_snippets(hint, _env, _metadata, %{at_module_body?: true}, acc) do
    list =
      for {label, snippet, doc, priority} <- @module_attr_snippets,
          Matcher.match?(label, hint) do
        %{
          type: :generic,
          kind: :snippet,
          label: label,
          snippet: Util.trim_leading_for_insertion(hint, snippet),
          filter_text: String.replace_prefix(label, "@", "") |> String.split(" ") |> List.first(),
          detail: "module attribute snippet",
          documentation: doc,
          priority: priority
        }
      end

    {:cont, %{acc | result: acc.result ++ Enum.sort(list)}}
  end

  def add_snippets(_hint, _env, _metadata, _cursor_context, acc),
    do: {:cont, acc}
end
