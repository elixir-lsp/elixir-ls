defmodule ElixirLS.LanguageServer.Providers.Completion do
  @moduledoc """
  Auto-complete provider utilizing Elixir Sense

  We use Elixir Sense to retrieve auto-complete suggestions based on the source file text and cursor
  position, and then perform some additional processing on those suggestions to make them compatible
  with the Language Server Protocol. We also attempt to determine the context based on the line
  text before the cursor so we can filter out suggestions that are not relevant.
  """
  alias ElixirLS.LanguageServer.SourceFile

  @enforce_keys [:label, :kind, :insert_text, :priority, :tags]
  defstruct [
    :label,
    :kind,
    :detail,
    :documentation,
    :insert_text,
    :filter_text,
    # Lower priority is shown higher in the result list
    :priority,
    :tags,
    :command
  ]

  @func_snippets %{
    {"Kernel.SpecialForms", "case"} => "case $1 do\n\t$2 ->\n\t\t$0\nend",
    {"Kernel.SpecialForms", "with"} => "with $2 <- $1 do\n\t$0\nend",
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
    {"Kernel", "defdelegate"} => "defdelegate $1, to: $0",
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
    {"ExUnit.Callbacks", "setup_all"} => "setup_all ${1:%{$2\\}} do\n\t$3\nend",
    {"ExUnit.Case", "test"} => "test $1 do\n\t$0\nend",
    {"ExUnit.Case", "describe"} => "describe \"$1\" do\n\t$0\nend"
  }

  @use_name_only MapSet.new([
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

  def trigger_characters do
    # VS Code's 24x7 autocompletion triggers automatically on alphanumeric characters. We add these
    # for "SomeModule." calls, @module_attrs, function capture, variable pinning, erlang module calls
    [".", "@", "&", "%", "^", ":", "!"]
  end

  def completion(text, line, character, options) do
    line_text =
      text
      |> SourceFile.lines()
      |> Enum.at(line)

    text_before_cursor = String.slice(line_text, 0, character)
    text_after_cursor = String.slice(line_text, character..-1)

    prefix = get_prefix(text_before_cursor)

    # TODO: Don't call into here directly
    # Can we use ElixirSense.Providers.Suggestion? ElixirSense.suggestions/3
    env =
      ElixirSense.Core.Parser.parse_string(text, true, true, line + 1)
      |> ElixirSense.Core.Metadata.get_env(line + 1)

    scope =
      case env.scope do
        scope when scope in [Elixir, nil] -> :file
        module when is_atom(module) -> :module
        {_, _} -> :function
      end

    def_before =
      cond do
        Regex.match?(Regex.recompile!(~r/(defdelegate|defp?)\s*#{prefix}$/), text_before_cursor) ->
          :def

        Regex.match?(
          Regex.recompile!(~r/(defguardp?|defmacrop?)\s*#{prefix}$/),
          text_before_cursor
        ) ->
          :defmacro

        true ->
          nil
      end

    context = %{
      text_before_cursor: text_before_cursor,
      text_after_cursor: text_after_cursor,
      prefix: prefix,
      def_before: def_before,
      pipe_before?: Regex.match?(Regex.recompile!(~r/\|>\s*#{prefix}$/), text_before_cursor),
      capture_before?: Regex.match?(Regex.recompile!(~r/&#{prefix}$/), text_before_cursor),
      scope: scope,
      module: env.module
    }

    items =
      ElixirSense.suggestions(text, line + 1, character + 1)
      |> maybe_reject_derived_functions(context, options)
      |> Enum.map(&from_completion_item(&1, context, options))

    items_json =
      items
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq_by(&{&1.detail, &1.documentation, &1.insert_text})
      |> sort_items()
      |> items_to_json(options)

    {:ok, %{"isIncomplete" => is_incomplete(items_json), "items" => items_json}}
  end

  ## Helpers

  defp is_incomplete(items) do
    if Enum.empty?(items) do
      false
    else
      # By returning isIncomplete = true we tell the client that it should
      # always fetch more results, this lets us control the ordering of
      # completions accurately
      true
    end
  end

  defp maybe_reject_derived_functions(suggestions, context, options) do
    locals_without_parens = Keyword.get(options, :locals_without_parens)
    signature_help_supported = Keyword.get(options, :signature_help_supported, false)
    capture_before? = context.capture_before?

    Enum.reject(suggestions, fn s ->
      s.type in [:function, :macro] and
        !capture_before? and
        s.arity < s.def_arity and
        signature_help_supported and
        function_name_with_parens?(s.name, s.arity, locals_without_parens) ==
          function_name_with_parens?(s.name, s.def_arity, locals_without_parens)
    end)
  end

  defp from_completion_item(
         %{type: :attribute, name: name},
         %{
           prefix: prefix,
           def_before: nil,
           capture_before?: false,
           pipe_before?: false
         },
         _options
       ) do
    name_only = String.trim_leading(name, "@")
    insert_text = if String.starts_with?(prefix, "@"), do: name_only, else: name

    if name == prefix do
      nil
    else
      %__MODULE__{
        label: name,
        kind: :variable,
        detail: "module attribute",
        insert_text: insert_text,
        filter_text: name_only,
        priority: 14,
        tags: []
      }
    end
  end

  defp from_completion_item(
         %{type: :variable, name: name},
         %{
           def_before: nil,
           pipe_before?: false,
           capture_before?: false
         },
         _options
       ) do
    %__MODULE__{
      label: to_string(name),
      kind: :variable,
      detail: "variable",
      insert_text: name,
      priority: 13,
      tags: []
    }
  end

  defp from_completion_item(
         %{type: :return, description: description, spec: spec, snippet: snippet},
         %{def_before: nil, capture_before?: false, pipe_before?: false},
         _options
       ) do
    snippet = Regex.replace(Regex.recompile!(~r/"\$\{(.*)\}\$"/U), snippet, "${\\1}")

    %__MODULE__{
      label: description,
      kind: :value,
      detail: "return value",
      documentation: spec,
      insert_text: snippet,
      priority: 15,
      tags: []
    }
  end

  defp from_completion_item(
         %{type: :module, name: name, summary: summary, subtype: subtype, metadata: metadata},
         %{def_before: nil},
         _options
       ) do
    detail =
      if subtype do
        Atom.to_string(subtype)
      else
        "module"
      end

    kind =
      case subtype do
        :behaviour -> :interface
        :protocol -> :interface
        :exception -> :struct
        :struct -> :struct
        _ -> :module
      end

    label =
      if subtype do
        "#{name} (#{subtype})"
      else
        name
      end

    %__MODULE__{
      label: label,
      kind: kind,
      detail: detail,
      documentation: summary,
      insert_text: name,
      filter_text: name,
      priority: 14,
      tags: metadata_to_tags(metadata)
    }
  end

  defp from_completion_item(
         %{
           type: :callback,
           subtype: subtype,
           args: args,
           name: name,
           summary: summary,
           arity: arity,
           origin: origin,
           metadata: metadata
         },
         context,
         options
       ) do
    if (context[:def_before] == :def && subtype == :macrocallback) ||
         (context[:def_before] == :defmacro && subtype == :callback) do
      nil
    else
      def_str =
        if context[:def_before] == nil do
          if subtype == :macrocallback do
            "defmacro "
          else
            "def "
          end
        end

      opts = Keyword.put(options, :with_parens?, true)
      insert_text = def_snippet(def_str, name, args, arity, opts)
      label = "#{def_str}#{name}/#{arity}"

      filter_text =
        if def_str do
          "#{def_str}#{name}"
        else
          name
        end

      %__MODULE__{
        label: label,
        kind: :interface,
        detail: "#{origin} #{subtype}",
        documentation: summary,
        insert_text: insert_text,
        priority: 12,
        filter_text: filter_text,
        tags: metadata_to_tags(metadata)
      }
    end
  end

  defp from_completion_item(
         %{
           type: :protocol_function,
           args: args,
           spec: _spec,
           name: name,
           summary: summary,
           arity: arity,
           origin: origin,
           metadata: metadata
         },
         context,
         options
       ) do
    unless context[:def_before] == :defmacro do
      def_str = if(context[:def_before] == nil, do: "def ")

      opts = Keyword.put(options, :with_parens?, true)
      insert_text = def_snippet(def_str, name, args, arity, opts)
      label = "#{def_str}#{name}/#{arity}"

      %__MODULE__{
        label: label,
        kind: :interface,
        detail: "#{origin} protocol function",
        documentation: summary,
        insert_text: insert_text,
        priority: 12,
        filter_text: name,
        tags: metadata_to_tags(metadata)
      }
    end
  end

  defp from_completion_item(
         %{type: :field, subtype: subtype, name: name, origin: origin, call?: call?},
         _context,
         _options
       ) do
    detail =
      case {subtype, origin} do
        {:map_key, _} -> "map key"
        {:struct_field, nil} -> "struct field"
        {:struct_field, module_name} -> "#{module_name} struct field"
      end

    %__MODULE__{
      label: to_string(name),
      detail: detail,
      insert_text: if(call?, do: name, else: "#{name}: "),
      priority: 10,
      kind: :field,
      tags: []
    }
  end

  defp from_completion_item(%{type: :param_option} = suggestion, _context, _options) do
    %{name: name, origin: _origin, doc: doc, type_spec: type_spec, expanded_spec: expanded_spec} =
      suggestion

    formatted_spec =
      if expanded_spec != "" do
        "\n\n```\n#{expanded_spec}\n```\n"
      else
        ""
      end

    %__MODULE__{
      label: to_string(name),
      detail: "#{type_spec}",
      documentation: "#{doc}#{formatted_spec}",
      insert_text: "#{name}: ",
      priority: 10,
      kind: :field,
      tags: []
    }
  end

  defp from_completion_item(
         %{type: :type_spec, metadata: metadata} = suggestion,
         _context,
         _options
       ) do
    %{name: name, arity: arity, origin: _origin, doc: doc, signature: signature, spec: spec} =
      suggestion

    formatted_spec =
      if spec != "" do
        "\n\n```\n#{spec}\n```\n"
      else
        ""
      end

    snippet =
      if arity > 0 do
        "#{name}($0)"
      else
        "#{name}()"
      end

    %__MODULE__{
      label: signature,
      detail: "typespec #{signature}",
      documentation: "#{doc}#{formatted_spec}",
      insert_text: snippet,
      priority: 10,
      kind: :class,
      tags: metadata_to_tags(metadata)
    }
  end

  defp from_completion_item(%{type: :generic, kind: kind, label: label} = suggestion, _ctx, opts) do
    insert_text =
      cond do
        suggestion[:snippet] && Keyword.get(opts, :snippets_supported, false) ->
          suggestion[:snippet]

        insert_text = suggestion[:insert_text] ->
          insert_text

        true ->
          label
      end

    %__MODULE__{
      label: label,
      detail: suggestion[:detail] || "",
      documentation: suggestion[:documentation] || "",
      insert_text: insert_text,
      filter_text: suggestion[:filter_text],
      priority: suggestion[:priority] || 0,
      kind: kind,
      command: suggestion[:command],
      tags: []
    }
  end

  defp from_completion_item(
         %{name: name, origin: origin} = item,
         %{def_before: nil} = context,
         options
       ) do
    completion = function_completion(item, context, options)

    completion =
      if origin == "Kernel" || origin == "Kernel.SpecialForms" do
        %{completion | kind: :keyword, priority: 18}
      else
        completion
      end

    if snippet = Map.get(@func_snippets, {origin, name}) do
      %{completion | insert_text: snippet, kind: :snippet, label: name}
    else
      completion
    end
  end

  defp from_completion_item(_suggestion, _context, _options) do
    nil
  end

  defp def_snippet(def_str, name, args, arity, opts) do
    if Keyword.get(opts, :snippets_supported, false) do
      "#{def_str}#{function_snippet(name, args, arity, opts)} do\n\t$0\nend"
    else
      "#{def_str}#{name}"
    end
  end

  defp function_snippet(name, args, arity, opts) do
    snippets_supported? = Keyword.get(opts, :snippets_supported, false)
    trigger_signature? = Keyword.get(opts, :trigger_signature?, false)
    capture_before? = Keyword.get(opts, :capture_before?, false)
    pipe_before? = Keyword.get(opts, :pipe_before?, false)
    with_parens? = Keyword.get(opts, :with_parens?, false)
    snippet = Keyword.get(opts, :snippet)

    cond do
      snippet && snippets_supported? && !pipe_before? && !capture_before? ->
        snippet

      capture_before? ->
        function_snippet_with_capture_before(name, arity, snippets_supported?)

      trigger_signature? ->
        text_after_cursor = Keyword.get(opts, :text_after_cursor, "")

        function_snippet_with_signature(
          name,
          text_after_cursor,
          snippets_supported?,
          with_parens?
        )

      has_text_after_cursor?(opts) ->
        name

      snippets_supported? ->
        function_snippet_with_args(name, arity, args, pipe_before?, with_parens?)

      true ->
        name
    end
  end

  defp function_snippet_with_args(name, arity, args, pipe_before?, with_parens?) do
    args_list =
      if args && args != "" do
        split_args_for_snippet(args, arity)
      else
        for i <- Enum.slice(0..arity, 1..-1), do: "arg#{i}"
      end

    args_list =
      if pipe_before? do
        Enum.slice(args_list, 1..-1)
      else
        args_list
      end

    tabstops =
      args_list
      |> Enum.with_index()
      |> Enum.map(fn {arg, i} -> "${#{i + 1}:#{arg}}" end)

    {before_args, after_args} =
      if with_parens? do
        {"(", ")"}
      else
        {" ", ""}
      end

    Enum.join([name, before_args, Enum.join(tabstops, ", "), after_args])
  end

  defp function_snippet_with_signature(name, text_after_cursor, snippets_supported?, with_parens?) do
    cond do
      !with_parens? ->
        if String.starts_with?(text_after_cursor, " "), do: name, else: "#{name} "

      # Don't add the closing parenthesis to the snippet if the cursor is
      # immediately before a valid argument. This usually happens when we
      # want to wrap an existing variable or literal, e.g. using IO.inspect/2.
      !snippets_supported? || Regex.match?(~r/^[a-zA-Z0-9_:"'%<@\[\{]/, text_after_cursor) ->
        "#{name}("

      true ->
        "#{name}($1)$0"
    end
  end

  defp function_snippet_with_capture_before(name, 0, _snippets_supported?) do
    "#{name}/0"
  end

  defp function_snippet_with_capture_before(name, arity, snippets_supported?) do
    if snippets_supported? do
      "#{name}${1:/#{arity}}$0"
    else
      "#{name}/#{arity}"
    end
  end

  defp has_text_after_cursor?(opts) do
    text =
      opts
      |> Keyword.get(:text_after_cursor, "")
      |> String.trim()

    text != ""
  end

  # LSP CompletionItemKind enumeration
  defp completion_kind(kind) do
    case kind do
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
      :folder -> 19
      :enum_member -> 20
      :constant -> 21
      :struct -> 22
      :event -> 23
      :operator -> 24
      :type_parameter -> 25
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

  defp split_args_for_snippet(args, arity) do
    args
    |> String.replace("\\", "\\\\")
    |> String.replace("$", "\\$")
    |> String.replace("}", "\\}")
    |> String.split(",")
    |> remove_unused_default_args(arity)
  end

  defp remove_unused_default_args(args, arity) do
    reversed_args = Enum.reverse(args)
    acc = {[], length(args) - arity}

    {result, _} =
      Enum.reduce(reversed_args, acc, fn arg, {result, remove_count} ->
        parts = String.split(arg, "\\\\\\\\")
        var = Enum.at(parts, 0) |> String.trim()
        default_value = Enum.at(parts, 1)

        if remove_count > 0 && default_value do
          {result, remove_count - 1}
        else
          {[var | result], remove_count}
        end
      end)

    result
  end

  defp function_completion(info, context, options) do
    %{
      type: type,
      args: args,
      name: name,
      summary: summary,
      arity: arity,
      spec: spec,
      origin: origin,
      metadata: metadata
    } = info

    # ElixirSense now returns types as an atom
    type = to_string(type)

    %{
      pipe_before?: pipe_before?,
      capture_before?: capture_before?,
      text_after_cursor: text_after_cursor,
      module: module
    } = context

    locals_without_parens = Keyword.get(options, :locals_without_parens)
    signature_help_supported? = Keyword.get(options, :signature_help_supported, false)
    signature_after_complete? = Keyword.get(options, :signature_after_complete, true)
    with_parens? = function_name_with_parens?(name, arity, locals_without_parens)

    trigger_signature? = signature_help_supported? && ((arity == 1 && !pipe_before?) || arity > 1)

    {label, insert_text} =
      cond do
        match?("sigil_" <> _, name) ->
          "sigil_" <> sigil_name = name
          text = "~#{sigil_name}"
          {text, text}

        use_name_only?(origin, name) or String.starts_with?(text_after_cursor, "(") ->
          {name, name}

        true ->
          label = "#{name}/#{arity}"

          insert_text =
            function_snippet(
              name,
              args,
              arity,
              Keyword.merge(
                options,
                pipe_before?: pipe_before?,
                capture_before?: capture_before?,
                pipe_before?: pipe_before?,
                trigger_signature?: trigger_signature?,
                locals_without_parens: locals_without_parens,
                text_after_cursor: text_after_cursor,
                with_parens?: with_parens?,
                snippet: info[:snippet]
              )
            )

          {label, insert_text}
      end

    detail_prefix =
      if inspect(module) == origin do
        "(#{type}) "
      else
        "(#{type}) #{origin}."
      end

    detail = Enum.join([detail_prefix, name, "(", args, ")"])

    footer = SourceFile.format_spec(spec, line_length: 30)

    command =
      if trigger_signature? && signature_after_complete? && !capture_before? do
        %{
          "title" => "Trigger Parameter Hint",
          "command" => "editor.action.triggerParameterHints"
        }
      end

    %__MODULE__{
      label: label,
      kind: :function,
      detail: detail,
      documentation: summary <> footer,
      insert_text: insert_text,
      priority: 17,
      tags: metadata_to_tags(metadata),
      command: command
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

  defp items_to_json(items, options) do
    snippets_supported = Keyword.get(options, :snippets_supported, false)

    items =
      Enum.reject(items, fn item ->
        not snippets_supported and snippet?(item)
      end)

    for {item, idx} <- Enum.with_index(items) do
      item_to_json(item, idx, options)
    end
  end

  defp item_to_json(item, idx, options) do
    json = %{
      "label" => item.label,
      "kind" => completion_kind(item.kind),
      "detail" => item.detail,
      "documentation" => %{"value" => item.documentation || "", kind: "markdown"},
      "filterText" => item.filter_text,
      "sortText" => String.pad_leading(to_string(idx), 8, "0"),
      "insertText" => item.insert_text,
      "command" => item.command,
      "insertTextFormat" =>
        if Keyword.get(options, :snippets_supported, false) do
          insert_text_format(:snippet)
        else
          insert_text_format(:plain_text)
        end
    }

    # deprecated as of Language Server Protocol Specification - 3.15
    json =
      if Keyword.get(options, :deprecated_supported, false) do
        Map.merge(json, %{
          "deprecated" => item.tags |> Enum.any?(&(&1 == :deprecated))
        })
      else
        json
      end

    tags_supported = options |> Keyword.get(:tags_supported, [])

    json =
      if tags_supported != [] do
        Map.merge(json, %{
          "tags" => item.tags |> Enum.map(&tag_to_code/1) |> Enum.filter(&(&1 in tags_supported))
        })
      else
        json
      end

    for {k, v} <- json, not is_nil(v), into: %{}, do: {k, v}
  end

  defp snippet?(item) do
    item.kind == :snippet || String.match?(item.insert_text, ~r/\${?\d/)
  end

  # As defined by CompletionItemTag in https://microsoft.github.io/language-server-protocol/specifications/specification-current/
  defp tag_to_code(:deprecated), do: 1

  defp metadata_to_tags(metadata) do
    # As of Language Server Protocol Specification - 3.15 only one tag is supported
    case metadata[:deprecated] do
      nil -> []
      _ -> [:deprecated]
    end
  end

  defp function_name_with_parens?(name, arity, locals_without_parens) do
    (locals_without_parens || MapSet.new())
    |> MapSet.member?({String.to_atom(name), arity})
    |> Kernel.not()
  end
end
