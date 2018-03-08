defmodule ElixirLS.LanguageServer.Providers.Completion do
  @moduledoc """
  Auto-complete provider utilizing Elixir Sense

  We use Elixir Sense to retrieve auto-complete suggestions based on the source file text and cursor
  position, and then perform some additional processing on those suggestions to make them compatible
  with the Language Server Protocol. We also attempt to determine the context based on the line
  text before the cursor so we can filter out suggestions that are not relevant.
  """
  alias ElixirSense.Core.{Metadata, Parser}

  @enforce_keys [:label, :kind, :insert_text, :priority]
  defstruct [:label, :kind, :detail, :documentation, :insert_text, :filter_text, :priority]

  @module_attr_snippets [
    {"doc", "doc \"\"\"\n$0\n\"\"\"", "Documents a function"},
    {"moduledoc", "moduledoc \"\"\"\n$0\n\"\"\"", "Documents a module"},
    {"typedoc", "typedoc \"\"\"\n$0\n\"\"\"", "Documents a type specification"}
  ]

  @func_snippets %{
    {"Kernel.SpecialForms", "case"} => "case $1 do\n\t$2 ->\n\t\t$0\nend",
    {"Kernel.SpecialForms", "cond"} => "cond do\n\t$1 ->\n\t\t$0\nend",
    {"Kernel.SpecialForms", "receive"} =>
      "receive do\n\t${1:{${2::message_type}, ${3:value}\\}} ->\n\t\t${0:# code}\nend\n",
    {"Kernel.SpecialForms", "fn"} => "fn $1 -> $0 end",
    {"Kernel.SpecialForms", "for"} => "for $1 <- $2 do\n\t$3\nend",
    {"Kernel.SpecialForms", "super"} => "super($1)",
    {"Kernel.SpecialForms", "quote"} => "quote do\n\t$0\nend",
    {"Kernel.SpecialForms", "try"} => "try do\n\t$0\nend",
    {"Kernel", "if"} => "if $1 do\n\t$0\nend",
    {"Kernel", "unless"} => "unless $1 do\n\t$0\nend",
    {"Kernel", "def"} => "def $1 do\n\t$0\nend",
    {"Kernel", "defp"} => "defp $1 do\n\t$0\nend",
    {"Kernel", "defcallback"} => "defcallback $1 :: $0",
    {"Kernel", "defdelegate"} => "defdelegate $1 to: $0",
    {"Kernel", "defexception"} => "defexception [${1::message}]",
    {"Kernel", "defguard"} => "defguard ${1:guard_name}($2) when $3",
    {"Kernel", "defguardp"} => "defguardp ${1:guard_name}($2) when $3",
    {"Kernel", "defimpl"} => "defimpl $1, for: $2 do\n\t$0\nend",
    {"Kernel", "defmacro"} => "defmacro $1 do\n\t$0\nend",
    {"Kernel", "defmacrocallback"} => "defmacrocallback $1 :: $0",
    {"Kernel", "defmacrop"} => "defmacrop $1 do\n\t$0\nend",
    {"Kernel", "defmodule"} => "defmodule $1 do\n\t$0\nend",
    {"Kernel", "defprotocol"} => "defprotocol $1 do\n\t$0\nend",
    {"Kernel", "defstruct"} => "defstruct $1: $2",
    {"ExUnit.Callbacks", "setup"} => "setup ${1:%{$2\\}} do\n\t$3\nend",
    {"ExUnit.Case", "test"} => "test $1 do\n\t$0\nend",
    {"ExUnit.Case", "describe"} => "describe \"$1\" do\n\t$0\nend"
  }

  @use_name_only MapSet.new([
                   {"Kernel", "require"},
                   {"Kernel", "import"},
                   {"Kernel", "not"},
                   {"Kernel", "use"},
                   {"Kernel", "or"},
                   {"Kernel", "and"},
                   {"Kernel", "raise"},
                   {"Kernel", "reraise"},
                   {"Kernel", "in"},
                   {"Kernel.SpecialForms", "alias"},
                   {"Kernel.SpecialForms", "import"},
                   {"Kernel.SpecialForms", "require"},
                   "ExUnit.Assertions"
                 ])

  @ignore_module_attrs [
    "@moduledoc",
    "@doc",
    "@spec",
    "@behaviour",
    "@impl",
    "@type",
    "@typedoc",
    "@enforce_keys",
    "@callback",
    "@dialyzer"
  ]

  # When ending a line with "else", we don't want to autocomplete it because that's really
  # irritating. We can't make it a snippet because that interferes with the auto-indentation rules.
  # So we blacklist any prefixes that look like the user is about to type "else" instead.
  @prevent_completions_on ["else", "end"]

  def trigger_characters do
    # VS Code's 24x7 autocompletion triggers automatically on alphanumeric characters. We add these
    # for "SomeModule." calls, @module_attrs, and macros like __ENV__
    [".", "@", "_"]
  end

  def completion(text, line, character, snippets_supported) do
    text_before_cursor =
      text
      |> String.split("\n")
      |> Enum.at(line)
      |> String.slice(0..character)

    prefix = get_prefix(text_before_cursor)

    items =
      if blacklisted_prefix?(prefix) do
        []
      else
        try do
          env = Parser.parse_string(text, true, true, line + 1) |> Metadata.get_env(line + 1)

          scope =
            case env.scope do
              Elixir -> :file
              module when is_atom(module) -> :module
              _ -> :function
            end

          def_before =
            cond do
              Regex.match?(Regex.recompile!(~r/def\s*#{prefix}$/), text_before_cursor) ->
                :def

              Regex.match?(Regex.recompile!(~r/defmacro\s*#{prefix}$/), text_before_cursor) ->
                :defmacro

              true ->
                nil
            end

          context = %{
            text_before_cursor: text_before_cursor,
            prefix: prefix,
            def_before: def_before,
            pipe_before?: Regex.match?(Regex.recompile!(~r/\|>\s*#{prefix}$/), text_before_cursor),
            capture_before?: Regex.match?(Regex.recompile!(~r/&#{prefix}$/), text_before_cursor),
            scope: scope
          }

          ElixirSense.suggestions(text, line + 1, character + 1)
          |> Enum.map(&from_completion_item(&1, context))
          |> Enum.concat(module_attr_snippets(context))
        rescue
          err ->
            IO.puts(:standard_error, Exception.format_exit(err))
            []
        end
      end

    # The "do" snippet is special because it's really annoying if it doesn't fire when it should
    items =
      if String.starts_with?("do", prefix) do
        [
          %__MODULE__{
            label: "do",
            insert_text: "do\n\t$0\nend",
            kind: :snippet,
            priority: 0
          }
          | items
        ]
      else
        items
      end

    items_json =
      items
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq_by(& &1.insert_text)
      |> sort_items()
      |> items_to_json(snippets_supported)

    {:ok, %{"isIncomplete" => true, "items" => items_json}}
  end

  ## Helpers

  defp from_completion_item(%{type: :attribute, name: name}, %{
         prefix: prefix,
         def_before: nil,
         capture_before?: false,
         pipe_before?: false
       }) do
    name_only = String.trim_leading(name, "@")
    insert_text = if String.starts_with?(prefix, "@"), do: name_only, else: name

    if name in @ignore_module_attrs or name == prefix do
      nil
    else
      %__MODULE__{
        label: name,
        kind: :variable,
        detail: "module attribute",
        insert_text: insert_text,
        filter_text: name_only,
        priority: 2
      }
    end
  end

  defp from_completion_item(%{type: :variable, name: name}, %{
         def_before: nil,
         pipe_before?: false,
         capture_before?: false
       }) do
    %__MODULE__{
      label: to_string(name),
      kind: :variable,
      detail: "variable",
      insert_text: name,
      priority: 2
    }
  end

  defp from_completion_item(
         %{type: :return, description: description, spec: spec, snippet: snippet},
         %{def_before: nil, capture_before?: false, pipe_before?: false}
       ) do
    snippet = Regex.replace(Regex.recompile!(~r/"\$\{(.*)\}\$"/U), snippet, "${\\1}")

    %__MODULE__{
      label: description,
      kind: :value,
      detail: "return value",
      documentation: spec,
      insert_text: snippet,
      priority: 4
    }
  end

  defp from_completion_item(%{type: :module, name: name, summary: summary, subtype: subtype}, %{
         def_before: nil,
         capture_before?: false,
         pipe_before?: false
       }) do
    %__MODULE__{
      label: to_string(name),
      kind: :module,
      detail: subtype || "module",
      documentation: summary,
      insert_text: name,
      priority: 3
    }
  end

  defp from_completion_item(
         %{
           type: :callback,
           args: args,
           spec: spec,
           name: name,
           summary: summary,
           arity: arity,
           origin: origin
         },
         context
       ) do
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

      full_snippet = "#{def_str}#{snippet(name, args, arity)} do\n\t$0\nend"
      label = "#{def_str}#{function_label(name, args, arity)}"

      %__MODULE__{
        label: label,
        kind: :interface,
        detail: "#{origin} callback",
        documentation: summary,
        insert_text: full_snippet,
        priority: 1,
        filter_text: name
      }
    end
  end

  defp from_completion_item(
         %{name: name, origin: origin} = item,
         %{def_before: nil} = context
       ) do
    completion = function_completion(item, context)

    completion =
      if origin == "Kernel" || origin == "Kernel.SpecialForms" do
        %{completion | kind: :keyword, priority: 8}
      else
        completion
      end

    if snippet = Map.get(@func_snippets, {origin, name}) do
      %{completion | insert_text: snippet, kind: :snippet, label: name}
    else
      completion
    end
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
    if Keyword.get(opts, :capture_before?) && arity <= 1 do
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
        |> Enum.with_index()
        |> Enum.map(fn {arg, i} -> "${#{i + 1}:#{arg}}" end)

      Enum.join([name, "(", Enum.join(tabstops, ", "), ")"])
    end
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
    regex = Regex.recompile!(~r/[\w0-9\._!\?\:@\->]+$/)

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

  defp module_attr_snippets(%{prefix: prefix, scope: :module, def_before: nil}) do
    for {name, snippet, docs} <- @module_attr_snippets,
        label = "@" <> name,
        String.starts_with?(label, prefix) do
      snippet =
        case prefix do
          "@" <> _ -> snippet
          _ -> "@" <> snippet
        end

      %__MODULE__{
        label: label,
        kind: :snippet,
        documentation: docs,
        detail: "module attribute",
        insert_text: snippet,
        filter_text: name,
        priority: 6
      }
    end
  end

  defp module_attr_snippets(_), do: []

  defp function_completion(
         %{
           type: type,
           args: args,
           name: name,
           summary: summary,
           arity: arity,
           spec: spec,
           origin: origin
         },
         %{def_before: nil, pipe_before?: pipe_before?, capture_before?: capture_before?}
       ) do
    {label, snippet} =
      cond do
        match?("sigil_" <> _, name) ->
          "sigil_" <> sigil_name = name
          text = "~#{sigil_name}"
          {text, text}

        use_name_only?(origin, name) ->
          {name, name}

        true ->
          label = function_label(name, args, arity)

          snippet =
            snippet(
              name,
              args,
              arity,
              pipe_before?: pipe_before?,
              capture_before?: capture_before?
            )

          {label, snippet}
      end

    detail =
      cond do
        spec && spec != "" ->
          spec

        String.starts_with?(type, ["private", "public"]) ->
          String.replace(type, "_", " ")

        true ->
          "(#{origin}) #{type}"
      end

    %__MODULE__{
      label: label,
      kind: :function,
      detail: detail,
      documentation: summary,
      insert_text: snippet,
      priority: 7
    }
  end

  defp use_name_only?(module_name, function_name) do
    module_name in @use_name_only or {module_name, function_name} in @use_name_only or
      String.starts_with?(function_name, "__") or
      function_name =~ Regex.recompile!(~r/^[^a-zA-Z0-9]+$/)
  end

  defp sort_items(items) do
    Enum.sort_by(items, fn %__MODULE__{priority: priority, label: label} ->
      {priority, label =~ Regex.recompile!(~r/^[^a-zA-Z0-9]/), label}
    end)
  end

  defp items_to_json(items, snippets_supported) do
    for {item, idx} <- Enum.with_index(items) do
      json = %{
        "label" => item.label,
        "kind" => completion_kind(item.kind),
        "detail" => item.detail,
        "documentation" => item.documentation,
        "filterText" => item.filter_text,
        "sortText" => String.pad_leading(to_string(idx), 8, "0")
      }

      json =
        if snippets_supported do
          Map.merge(json, %{
            "insertText" => item.insert_text,
            "insertTextFormat" => insert_text_format(:snippet)
          })
        else
          regex = Regex.recompile!(~r/\$(\{.*\})|(\$\d+).*$/)
          text = Regex.replace(regex, item.insert_text, "")

          Map.merge(json, %{
            "insertText" => text,
            "insertTextFormat" => insert_text_format(:plain_text)
          })
        end

      for {k, v} <- json, not is_nil(v), into: %{}, do: {k, v}
    end
  end

  # If we're within one letter of a keyword that frequently ends a line (such as "else" or "end"),
  # prevent any completions
  defp blacklisted_prefix?(prefix) do
    blacklisted_prefixes =
      @prevent_completions_on ++ Enum.map(@prevent_completions_on, &String.slice(&1, 0..-2))

    prefix in blacklisted_prefixes
  end
end
