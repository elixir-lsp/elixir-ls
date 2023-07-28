defmodule ElixirLS.LanguageServer.Providers.Completion do
  @moduledoc """
  Auto-complete provider utilizing Elixir Sense

  We use Elixir Sense to retrieve auto-complete suggestions based on the source file text and cursor
  position, and then perform some additional processing on those suggestions to make them compatible
  with the Language Server Protocol. We also attempt to determine the context based on the line
  text before the cursor so we can filter out suggestions that are not relevant.
  """
  alias ElixirLS.LanguageServer.Protocol.TextEdit
  alias ElixirLS.LanguageServer.SourceFile
  import ElixirLS.LanguageServer.Protocol, only: [range: 4]

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
    :label_details,
    :tags,
    :command,
    {:preselect, false},
    :additional_text_edit
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
    {"ExUnit.Case", "test"} => "test \"$1\" do\n\t$0\nend",
    {"ExUnit.Case", "describe"} => "describe \"$1\" do\n\t$0\nend"
  }

  # Alternative snippets versions to be preferred when preceded by a pipe
  @pipe_func_snippets %{
    {"Kernel.SpecialForms", "case"} => "case do\n\t$1 ->\n\t\t$0\nend",
    {"Kernel", "if"} => "if do\n\t$0\nend",
    {"Kernel", "unless"} => "unless do\n\t$0\nend"
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
    # for "SomeModule." calls, @module_attrs, function capture, variable pinning, erlang module calls,
    # bitstring options and sigils
    [".", "@", "&", "%", "^", ":", "!", "-", "~"]
  end

  def completion(text, line, character, options) do
    line_text =
      text
      |> SourceFile.lines()
      |> Enum.at(line)

    # convert to 1 based utf8 position
    line = line + 1
    character = SourceFile.lsp_character_to_elixir(line_text, character)

    text_before_cursor = String.slice(line_text, 0, character - 1)
    text_after_cursor = String.slice(line_text, (character - 1)..-1)

    prefix = get_prefix(text_before_cursor)

    # Can we use ElixirSense.Providers.Suggestion? ElixirSense.suggestions/3
    metadata = ElixirSense.Core.Parser.parse_string(text, true, true, line)

    env = ElixirSense.Core.Metadata.get_env(metadata, {line, character})

    scope =
      case env.scope do
        scope when scope in [Elixir, nil] -> :file
        module when is_atom(module) -> :module
        {_, _} -> :function
        {:typespec, _, _} -> :typespec
      end

    def_before =
      cond do
        Regex.match?(~r/(defdelegate|defp?)\s*#{prefix}$/, text_before_cursor) ->
          :def

        Regex.match?(
          ~r/(defguardp?|defmacrop?)\s*#{prefix}$/,
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
      remote_calls?: match?({:dot, _, _}, Code.Fragment.cursor_context(prefix)),
      def_before: def_before,
      pipe_before?: Regex.match?(~r/\|>\s*#{prefix}$/, text_before_cursor),
      capture_before?: Regex.match?(~r/&#{prefix}$/, text_before_cursor),
      scope: scope,
      module: env.module
    }

    position_to_insert_alias =
      ElixirSense.Core.Metadata.get_position_to_insert_alias(metadata, {line, character}) ||
        {line, 1}

    context =
      Map.put(
        context,
        :position_to_insert_alias,
        SourceFile.elixir_position_to_lsp(text, position_to_insert_alias)
      )

    items =
      build_suggestions(text, line, character, options)
      |> maybe_reject_derived_functions(context, options)
      |> Enum.map(&from_completion_item(&1, context, options))
      |> maybe_add_do(context)
      |> maybe_add_end(context)
      |> Enum.reject(&is_nil/1)
      |> sort_items()

    # add trigger signatures to arity 0 if there are higher arity completions that would trigger
    commands =
      items
      |> Enum.filter(&(&1.kind in [:function, :class]))
      |> Enum.group_by(&{&1.kind, &1.label})
      |> Map.new(fn {key, values} ->
        command = Enum.find_value(values, & &1.command)
        {key, command}
      end)

    items =
      items
      |> Enum.map(fn
        %{command: nil, kind: kind} = item when kind in [:function, :class] ->
          command = commands[{kind, item.label}]

          if command do
            %{item | command: command, insert_text: "#{item.label}($1)$0"}
          else
            item
          end

        item ->
          item
      end)

    items_json =
      items
      |> items_to_json(options)

    {:ok, %{"isIncomplete" => is_incomplete(items_json), "items" => items_json}}
  end

  defp build_suggestions(text, line, character, options) do
    required_alias = Keyword.get(options, :auto_insert_required_alias, true)
    ElixirSense.suggestions(text, line, character, required_alias: required_alias)
  end

  defp maybe_add_do(completion_items, context) do
    if String.ends_with?(context.text_before_cursor, " do") && context.text_after_cursor == "" do
      item = %__MODULE__{
        label: "do",
        kind: :keyword,
        detail: "keyword",
        insert_text: "do\n  $0\nend",
        tags: [],
        priority: 0,
        # force selection over other longer not exact completions
        preselect: true
      }

      [item | completion_items]
    else
      completion_items
    end
  end

  defp maybe_add_end(completion_items, context) do
    if String.ends_with?(context.text_before_cursor, "end") && context.text_after_cursor == "" do
      item = %__MODULE__{
        label: "end",
        kind: :keyword,
        detail: "keyword",
        insert_text: "end",
        tags: [],
        priority: 0
      }

      [item | completion_items]
    else
      completion_items
    end
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
         %{type: :attribute, name: name, summary: summary},
         %{
           prefix: prefix,
           def_before: nil,
           capture_before?: false,
           pipe_before?: false
         },
         _options
       ) do
    name_only = String.trim_leading(name, "@")

    insert_text =
      case String.split(prefix, "@") do
        [_ | attribute_prefix] ->
          if String.starts_with?(name_only, attribute_prefix) do
            name_only
          else
            name
          end

        _ ->
          name
      end

    %__MODULE__{
      label: name,
      kind: :variable,
      detail: "module attribute",
      documentation: name <> "\n" <> if(summary, do: summary, else: ""),
      insert_text: insert_text,
      filter_text: name_only,
      priority: 14,
      tags: []
    }
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
    snippet = Regex.replace(~r/"\$\{(.*)\}\$"/U, snippet, "${\\1}")

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
         %{
           type: :module,
           name: name,
           full_name: full_name,
           summary: summary,
           subtype: subtype,
           metadata: metadata,
           required_alias: required_alias
         },
         %{
           def_before: nil,
           position_to_insert_alias: {line_to_insert_alias, column_to_insert_alias}
         },
         options
       )
       when required_alias != nil do
    completion_without_additional_text_edit =
      from_completion_item(
        %{
          type: :module,
          name: name,
          full_name: full_name,
          summary: summary,
          subtype: subtype,
          metadata: metadata
        },
        %{def_before: nil},
        options
      )

    indentation =
      if column_to_insert_alias >= 1,
        do: 1..column_to_insert_alias |> Enum.map_join(fn _ -> " " end),
        else: ""

    alias_edit = indentation <> "alias " <> required_alias <> "\n"

    label_details =
      Map.update!(
        completion_without_additional_text_edit.label_details,
        "description",
        &("alias " <> &1)
      )

    %__MODULE__{
      completion_without_additional_text_edit
      | additional_text_edit: %TextEdit{
          range: range(line_to_insert_alias, 0, line_to_insert_alias, 0),
          newText: alias_edit
        },
        documentation: name <> "\n" <> summary,
        label_details: label_details,
        priority: 24
    }
  end

  defp from_completion_item(
         %{
           type: :module,
           name: name,
           full_name: full_name,
           summary: summary,
           subtype: subtype,
           metadata: metadata
         },
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

    label_details = %{
      "description" => full_name
    }

    label_details =
      if detail != "module", do: Map.put(label_details, "detail", detail), else: label_details

    insert_text =
      case name do
        ":" <> rest -> rest
        other -> other
      end

    priority =
      case subtype do
        :exception ->
          # show exceptions after functions
          18

        _ ->
          14
      end

    %__MODULE__{
      label: name,
      kind: kind,
      detail: detail,
      documentation: summary,
      insert_text: insert_text,
      filter_text: name,
      label_details: label_details,
      priority: priority,
      tags: metadata_to_tags(metadata)
    }
  end

  defp from_completion_item(
         %{
           type: :callback,
           subtype: subtype,
           args_list: args_list,
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
      insert_text = def_snippet(def_str, name, args_list, arity, opts)
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
           args_list: args_list,
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
      insert_text = def_snippet(def_str, name, args_list, arity, opts)
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
         %{
           type: :field,
           subtype: subtype,
           name: name,
           origin: origin,
           call?: call?,
           type_spec: type_spec
         },
         _context,
         _options
       ) do
    detail =
      case {subtype, origin} do
        {:map_key, _} -> "map key"
        {:struct_field, nil} -> "struct field"
        {:struct_field, module_name} -> "#{module_name} struct field"
      end

    formatted_spec =
      if type_spec != "" do
        "```\n#{type_spec}\n```\n"
      else
        ""
      end

    %__MODULE__{
      label: to_string(name),
      detail: detail,
      insert_text: if(call?, do: name, else: "#{name}: "),
      documentation: formatted_spec,
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
         %{type: :bitstring_option, name: name},
         _context,
         options
       ) do
    insert_text =
      case name do
        name when name in ["size", "unit"] ->
          function_snippet(name, ["integer"], 1, options |> Keyword.merge(with_parens?: true))

        other ->
          other
      end

    %__MODULE__{
      label: name,
      detail: "bitstring option",
      insert_text: insert_text,
      priority: 10,
      kind: :type_parameter,
      tags: []
    }
  end

  defp from_completion_item(
         %{type: :type_spec, metadata: metadata} = suggestion,
         _context,
         options
       ) do
    %{
      name: name,
      arity: arity,
      args_list: args_list,
      origin: origin,
      doc: doc,
      signature: signature,
      spec: spec
    } = suggestion

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

    signature_help_supported? = Keyword.get(options, :signature_help_supported, false)
    signature_after_complete? = Keyword.get(options, :signature_after_complete, true)

    trigger_signature? = signature_help_supported? && arity >= 1

    command =
      if trigger_signature? && signature_after_complete? do
        %{
          "title" => "Trigger Parameter Hint",
          "command" => "editor.action.triggerParameterHints"
        }
      end

    %__MODULE__{
      label: name,
      detail: "typespec #{signature}",
      label_details: %{
        "detail" => "(#{Enum.join(args_list, ", ")})",
        "description" => if(origin, do: "#{origin}.#{name}/#{arity}", else: "#{name}/#{arity}")
      },
      documentation: "#{doc}#{formatted_spec}",
      insert_text: snippet,
      priority: 10,
      kind: :class,
      tags: metadata_to_tags(metadata),
      command: command
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
         %{
           arity: 0
         },
         %{
           pipe_before?: true
         },
         _options
       ),
       do: nil

  # import with only or except was used and the completion would need to change it
  # this is not trivial to implement and most likely not wanted so let's skip that
  defp from_completion_item(
         %{needed_import: needed_import},
         _context,
         _options
       )
       when needed_import != nil,
       do: nil

  defp from_completion_item(
         %{name: name, origin: origin} = item,
         %{def_before: nil} = context,
         options
       ) do
    completion = function_completion(item, context, options)

    completion =
      if origin == "Kernel" || origin == "Kernel.SpecialForms" do
        %__MODULE__{completion | kind: :keyword, priority: 18}
      else
        completion
      end

    completion =
      if item.needed_require do
        {line_to_insert_require, column_to_insert_require} = context.position_to_insert_alias

        indentation =
          if column_to_insert_require >= 1,
            do: 1..column_to_insert_require |> Enum.map_join(fn _ -> " " end),
            else: ""

        require_edit = indentation <> "require " <> item.needed_require <> "\n"

        label_details =
          Map.update!(
            completion.label_details,
            "description",
            &("require " <> &1)
          )

        %__MODULE__{
          completion
          | additional_text_edit: %TextEdit{
              range: range(line_to_insert_require, 0, line_to_insert_require, 0),
              newText: require_edit
            },
            label_details: label_details
        }
      else
        completion
      end

    file_path = Keyword.get(options, :file_path)

    if snippet = snippet_for({origin, name}, Map.put(context, :file_path, file_path)) do
      %__MODULE__{completion | insert_text: snippet, kind: :snippet, label: name}
    else
      completion
    end
  end

  defp from_completion_item(_suggestion, _context, _options) do
    nil
  end

  defp snippet_for({"Kernel", "defmodule"}, %{file_path: file_path}) when is_binary(file_path) do
    # In a mix project the file_path can be something like "/some/code/path/project/lib/project/sub_path/my_file.ex"
    # so we'll try to guess the appropriate module name from the path
    "defmodule #{suggest_module_name(file_path)}$1 do\n\t$0\nend"
  end

  defp snippet_for({"Kernel", "defprotocol"}, %{file_path: file_path})
       when is_binary(file_path) do
    "defprotocol #{suggest_module_name(file_path)}$1 do\n\t$0\nend"
  end

  defp snippet_for(key, %{pipe_before?: true}) do
    # Get pipe-friendly version of snippet if available, otherwise fallback to standard
    Map.get(@pipe_func_snippets, key) || Map.get(@func_snippets, key)
  end

  defp snippet_for(key, _context) do
    Map.get(@func_snippets, key)
  end

  defp def_snippet(def_str, name, args, arity, opts) do
    if Keyword.get(opts, :snippets_supported, false) do
      "#{def_str}#{function_snippet(name, args, arity, opts)} do\n\t$0\nend"
    else
      "#{def_str}#{name}"
    end
  end

  def suggest_module_name(file_path) when is_binary(file_path) do
    file_path
    |> Path.split()
    |> Enum.reverse()
    |> do_suggest_module_name()
  end

  defp do_suggest_module_name([]), do: nil

  defp do_suggest_module_name([filename | reversed_path]) do
    filename
    |> String.split(".")
    |> case do
      [file, "ex"] ->
        do_suggest_module_name(reversed_path, [file], topmost_parent: "lib")

      [file, "exs"] ->
        if String.ends_with?(file, "_test") do
          do_suggest_module_name(reversed_path, [file], topmost_parent: "test")
        else
          nil
        end

      _otherwise ->
        nil
    end
  end

  defp do_suggest_module_name([dir | _rest], module_name_acc, topmost_parent: topmost)
       when dir == topmost do
    module_name_acc
    |> Enum.map(&Macro.camelize/1)
    |> Enum.join(".")
  end

  defp do_suggest_module_name(
         [probable_phoenix_dir | [project_web_dir | _] = rest],
         module_name_acc,
         opts
       )
       when probable_phoenix_dir in [
              "controllers",
              "views",
              "channels",
              "plugs",
              "endpoints",
              "sockets",
              "live",
              "components"
            ] do
    if String.ends_with?(project_web_dir, "_web") do
      # by convention Phoenix doesn't use these folders as part of the module names
      # for modules located inside them, so we'll try to do the same
      do_suggest_module_name(rest, module_name_acc, opts)
    else
      # when not directly under the *_web folder however then we should make the folder
      # part of the module's name
      do_suggest_module_name(rest, [probable_phoenix_dir | module_name_acc], opts)
    end
  end

  defp do_suggest_module_name([dir_name | rest], module_name_acc, opts) do
    do_suggest_module_name(rest, [dir_name | module_name_acc], opts)
  end

  defp do_suggest_module_name([], _module_name_acc, _opts) do
    # we went all the way up without ever encountering a 'lib' or a 'test' folder
    # so we ignore the accumulated module name because it's probably wrong/useless
    nil
  end

  def function_snippet(name, args, arity, opts) do
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

  defp function_snippet_with_args(name, arity, args_list, pipe_before?, with_parens?) do
    args_list =
      args_list
      |> Enum.map(&format_arg_for_snippet/1)
      |> remove_unused_default_args(arity)

    args_list =
      if pipe_before? do
        tl(args_list)
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
    regex = ~r/[\w0-9\._!\?\:@\->]+$/

    case Regex.run(regex, text_before_cursor) do
      [prefix] -> prefix
      _ -> ""
    end
  end

  defp format_arg_for_snippet(arg) do
    arg
    |> String.replace("\\", "\\\\")
    |> String.replace("$", "\\$")
    |> String.replace("}", "\\}")
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
      args_list: args_list,
      name: name,
      summary: summary,
      arity: arity,
      spec: spec,
      origin: origin,
      metadata: metadata
    } = info

    %{
      remote_calls?: remote_calls?,
      pipe_before?: pipe_before?,
      capture_before?: capture_before?,
      text_after_cursor: text_after_cursor
    } = context

    locals_without_parens = Keyword.get(options, :locals_without_parens)
    signature_help_supported? = Keyword.get(options, :signature_help_supported, false)
    signature_after_complete? = Keyword.get(options, :signature_after_complete, true)
    with_parens? = remote_calls? || function_name_with_parens?(name, arity, locals_without_parens)

    trigger_signature? = signature_help_supported? && ((arity == 1 && !pipe_before?) || arity > 1)

    {label, insert_text} =
      cond do
        match?("~" <> _, name) ->
          "~" <> sigil_name = name
          {name, sigil_name}

        use_name_only?(origin, name) or String.starts_with?(text_after_cursor, "(") ->
          {name, name}

        true ->
          label = name

          insert_text =
            function_snippet(
              name,
              args_list,
              arity,
              Keyword.merge(
                options,
                pipe_before?: pipe_before?,
                capture_before?: capture_before?,
                trigger_signature?: trigger_signature?,
                locals_without_parens: locals_without_parens,
                text_after_cursor: text_after_cursor,
                with_parens?: with_parens?,
                snippet: info[:snippet]
              )
            )

          {label, insert_text}
      end

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
      detail: to_string(type),
      label_details: %{
        "detail" => "(#{Enum.join(args_list, ", ")})",
        "description" => "#{origin}.#{name}/#{arity}"
      },
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
      function_name =~ ~r/^[^a-zA-Z0-9]+$/
  end

  defp sort_items(items) do
    Enum.sort_by(items, fn %__MODULE__{priority: priority, label: label} = item ->
      # deprioritize deprecated
      priority =
        if item.tags |> Enum.any?(&(&1 == :deprecated)) do
          priority + 30
        else
          priority
        end

      {priority, label =~ ~r/^[^a-zA-Z0-9]/, label}
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
      "labelDetails" => item.label_details,
      "filterText" => item.filter_text,
      "sortText" => String.pad_leading(to_string(idx), 8, "0"),
      "insertText" => item.insert_text,
      "additionalTextEdits" =>
        if item.additional_text_edit do
          [item.additional_text_edit]
        else
          nil
        end,
      "command" => item.command,
      "insertTextFormat" =>
        if Keyword.get(options, :snippets_supported, false) do
          insert_text_format(:snippet)
        else
          insert_text_format(:plain_text)
        end
    }

    json =
      if item.preselect do
        Map.put(json, "preselect", true)
      else
        json
      end

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
