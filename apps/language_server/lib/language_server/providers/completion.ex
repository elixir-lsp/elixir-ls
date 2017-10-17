defmodule ElixirLS.LanguageServer.Providers.Completion do
  @moduledoc """
  Auto-complete provider utilizing Elixir Sense

  We use Elixir Sense to retrieve auto-complete suggestions based on the source file text and cursor
  position, and then perform some additional processing on those suggestions to make them compatible
  with the Language Server Protocol. We also attempt to determine the context based on the line
  text before the cursor so we can filter out suggestions that are not relevant.
  """

  def completion(text, line, character) do
    text_before_cursor =
      text
      |> String.split("\n")
      |> Enum.at(line)
      |> String.slice(0..character)

    prefix = get_prefix(text_before_cursor)

    def_before =
      cond do
        Regex.match?(~r/def\s*#{prefix}$/, text_before_cursor) -> :def
        Regex.match?(~r/defmacro\s*#{prefix}$/, text_before_cursor) -> :defmacro
        true -> nil
      end

    context = %{
      text_before_cursor: text_before_cursor,
      prefix: prefix,
      def_before: def_before,
      pipe_before?: Regex.match?(~r/\|>\s*#{prefix}$/, text_before_cursor),
      capture_before?: Regex.match?(~r/&#{prefix}$/, text_before_cursor),
    }

    items =
      ElixirSense.suggestions(text, line + 1, character + 1)
      |> Enum.map(&(from_completion_item(&1, context)))
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq

    %{"isIncomplete" => true, "items" => items}
  end

  ## Helpers

  defp from_completion_item(%{type: :attribute, name: name},
                           %{def_before: nil, capture_before?: false, pipe_before?: false}) do

    unless name == "@moduledoc" || name == "@doc" do
      %{"label" => name, "kind" => completion_kind(:variable),
        "sortText" => sort_text(:attribute, name),
        "detail" => "module attribute"}
    end
  end

  defp from_completion_item(%{type: :variable, name: name},
                           %{def_before: nil, pipe_before?: false, capture_before?: false}) do

    %{"label" => to_string(name), "kind" => completion_kind(:variable),
      "sortText" => sort_text(:variable, name), "detail" => "variable"}
  end

  defp from_completion_item(%{type: :return, description: description, spec: spec, snippet: snippet},
                           %{def_before: nil, capture_before?: false, pipe_before?: false}) do

    snippet = Regex.replace(~r/"\$\{(.*)\}\$"/U, snippet, "${\\1}")

    %{"label" => description, "kind" => completion_kind(:value), "detail" => "return",
      "documentation" => spec, "insertText" => snippet,
      "insertTextFormat" => insert_text_format(:snippet),
      "sortText" => sort_text(:return, description)}
  end

  defp from_completion_item(%{type: :module, name: name, summary: summary, subtype: subtype},
                           %{def_before: nil, capture_before?: false, pipe_before?: false}) do

    %{"label" => to_string(name), "kind" => completion_kind(:module), "detail" => subtype || "module",
      "documentation" => summary, "sortText" => sort_text(:module, name)}
  end

  defp from_completion_item(%{type: :callback, args: args, spec: spec, name: name, summary: summary,
                              arity: arity, origin: origin},
                           context) do

    if (context[:def_before] == :def && String.starts_with?(spec, "@macrocallback")) ||
       (context[:def_before] == :defmacro && String.starts_with?(spec, "@callback")) do
      nil
    else
      def_str =
        if context[:def_before] == nil do
          if String.starts_with?(spec, "@macrocallback") do
            "defmacro "
          else
            "def "
          end
        end

      full_snippet = "#{def_str}#{snippet(name, args, arity)} do\n  $0\nend\n"
      label = "#{def_str}#{function_label(name, args, arity)}"

      %{"label" => label, "kind" => completion_kind(:interface), "detail" => origin,
        "documentation" => summary, "insertTextFormat" => insert_text_format(:snippet),
        "insertText" => full_snippet, "sortText" => sort_text(:callback, name)}
    end
  end

  defp from_completion_item(%{type: type, args: args, name: name, summary: summary, arity: arity,
                             spec: spec, origin: origin},
                           %{def_before: nil, pipe_before?: pipe_before?,
                             capture_before?: capture_before?}) do

    label = function_label(name, args, arity)
    snippet =
      snippet(name, args, arity, pipe_before?: pipe_before?, capture_before?: capture_before?)

    detail =
      cond do
        spec && spec != "" ->
          spec
        String.starts_with?(type, ["private", "public"]) ->
          String.replace(type, "_", " ")
        true ->
          "(#{origin}) #{type}"
      end

    kind =
      if origin == "Kernel" || origin == "Kernel.SpecialForms" do
        :keyword
      else
        :function
      end

    %{"label" => label, "kind" => completion_kind(kind), "detail" => detail,
      "documentation" => summary, "insertTextFormat" => insert_text_format(:snippet),
      "insertText" => snippet, "sortText" => sort_text(kind, name)}
  end

  defp from_completion_item(_suggestion, _context) do
    nil
  end

  defp function_label(name, args, arity) do
    if args && args != "" do
      Enum.join([to_string(name), "(", args, ")"])
    else
      Enum.join([to_string(name), "/", arity])
    end
  end

  defp snippet(name, args, arity, opts \\ []) do
    if Keyword.get(opts, :capture_before?) do
      Enum.join([name, "/", arity])
    else
      args_list =
        if args && args != "" do
          split_args(args)
        else
          for i <- Enum.slice(0..arity, 1..-1), do: "arg#{i}"
        end

      args_list =
        if Keyword.get(opts, :pipe_before?) do
          Enum.slice(args_list, 1..-1)
        else
          args_list
        end

      tabstops =
        args_list
        |> Enum.with_index
        |> Enum.map(fn {arg, i} -> "${#{i + 1}:#{arg}}" end)
      Enum.join([name, "(", Enum.join(tabstops, ", "), ")"])
    end
  end

  # We sort the suggestions primarily based on type, rather than purely lexicographically. We do
  # this by giving the "sortText" a prefix based on the type.
  defp sort_text(type, name) do
    priority =
      case type do
        :callback -> 0
        :module -> 1
        :variable -> 2
        :attribute -> 3
        :return -> 4
        :function -> 5
        :keyword -> 6
        _ -> 7
      end

    sub_priority =
      if Regex.match?(~r/^[0-9a-zA-Z]/, to_string(name)) do
        0
      else
        1
      end

    "#{priority}_#{sub_priority}_#{name}"
  end

  defp completion_kind(type) do
    case type do
      :text -> 1
      :method -> 2
      :function -> 3
      :constructor -> 4
      :field -> 5
      :variable -> 6
      :class -> 7
      :interface -> 8
      :module -> 9
      :property -> 10
      :unit -> 11
      :value -> 12
      :enum -> 13
      :keyword -> 14
      :snippet -> 15
      :color -> 16
      :file -> 17
      :reference -> 18
    end
  end

  defp insert_text_format(type) do
    case type do
      :plain_text -> 1
      :snippet -> 2
    end
  end

  defp get_prefix(text_before_cursor) do
    regex = ~r/[\w0-9\._!\?\:@]+$/
    case Regex.run(regex, text_before_cursor) do
      [prefix] -> prefix
      _ -> ""
    end
  end

  defp split_args(args) do
    args
    |> String.replace("\\", "\\\\")
    |> String.replace("$", "\\$")
    |> String.replace("}", "\\}")
    |> String.split(",")
  end
end
