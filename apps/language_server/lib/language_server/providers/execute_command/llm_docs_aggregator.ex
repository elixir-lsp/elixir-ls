defmodule ElixirLS.LanguageServer.Providers.ExecuteCommand.LlmDocsAggregator do
  @moduledoc """
  This module implements a custom command for aggregating documentation 
  for modules, functions, types, and callbacks in a format optimized for LLM consumption.

  It uses ElixirSense.Core.Normalized.Code.get_docs which can fetch docs from
  implemented behaviours as well.
  """

  alias ElixirSense.Core.Normalized.Code, as: NormalizedCode
  alias ElixirSense.Core.Normalized.Typespec
  alias ElixirSense.Core.BuiltinFunctions
  alias ElixirSense.Core.BuiltinTypes
  alias ElixirSense.Core.BuiltinAttributes
  alias ElixirSense.Core.TypeInfo
  require ElixirSense.Core.Introspection, as: Introspection
  alias ElixirLS.LanguageServer.Providers.ExecuteCommand.LLM.SymbolParser
  alias ElixirLS.LanguageServer.MarkdownUtils

  require Logger

  @behaviour ElixirLS.LanguageServer.Providers.ExecuteCommand

  @impl ElixirLS.LanguageServer.Providers.ExecuteCommand
  def execute([modules], _state) when is_list(modules) do
    try do
      results =
        Enum.flat_map(modules, fn module_name ->
          case SymbolParser.parse(module_name) do
            {:ok, type, parsed} ->
              case get_documentation(type, parsed) do
                {:ok, docs} when is_list(docs) ->
                  # Multiple results (e.g., for different arities)
                  docs

                {:ok, docs} ->
                  # Single result
                  [docs]

                {:error, _reason} ->
                  # Filter out invalid modules by returning empty list
                  []
              end

            {:error, _reason} ->
              # Filter out invalid modules by returning empty list
              []
          end
        end)

      {:ok, %{results: results}}
    rescue
      error ->
        Logger.error("Error in llmDocsAggregator: #{inspect(error)}")
        {:ok, %{error: "Internal error: #{Exception.message(error)}"}}
    end
  end

  def execute(_args, _state) do
    {:ok, %{error: "Invalid arguments: expected [modules_list]"}}
  end

  defp get_documentation(:module, module) do
    if ensure_loaded(module) do
      docs = aggregate_module_docs(module)
      {:ok, docs}
    else
      {:error, "Module #{inspect(module)} not found"}
    end
  end

  defp get_documentation(:local_call, {function, arity}) do
    # For local calls, try Kernel first, then check if it's a builtin type
    case get_documentation(:remote_call, {Kernel, function, arity}) do
      {:ok, docs} ->
        {:ok, docs}

      _ ->
        # Try as builtin type using the new API that returns a list
        case BuiltinTypes.get_builtin_types_doc(function, arity || :any) do
          [] ->
            # No builtin types found, check if it's a builtin function using the new API
            case BuiltinFunctions.get_builtin_functions_doc(function, arity || :any) do
              [] ->
                {:error, "Local call #{function}/#{arity || "?"} - no documentation found"}

              builtin_functions ->
                # Return all matching builtin functions
                results =
                  Enum.map(builtin_functions, fn {_function_name, func_arity, doc, specs} ->
                    %{
                      function: Atom.to_string(function),
                      arity: func_arity,
                      documentation: format_builtin_function_doc(doc, specs)
                    }
                  end)

                # Return single result if only one match, otherwise return list
                case results do
                  [single_result] -> {:ok, single_result}
                  multiple_results -> {:ok, multiple_results}
                end
            end

          builtin_types ->
            # Return all matching builtin types
            results =
              Enum.map(builtin_types, fn {_type_name, type_arity, doc} ->
                type_name =
                  if type_arity == 0 do
                    "#{function}()"
                  else
                    "#{function}/#{type_arity}"
                  end

                %{
                  type: type_name,
                  documentation: doc
                }
              end)

            # Return single result if only one match, otherwise return list
            case results do
              [single_result] -> {:ok, single_result}
              multiple_results -> {:ok, multiple_results}
            end
        end
    end
  end

  defp get_documentation(:remote_call, {module, function, arity}) do
    # Try function/macro documentation first
    case aggregate_function_docs(module, function, arity) do
      list when is_list(list) and list != [] ->
        # Map the list of function docs to the expected format
        results =
          Enum.map(list, fn section ->
            %{
              module: inspect(module),
              function: Atom.to_string(function),
              arity: section[:arity] || arity,
              documentation: format_function_sections([section])
            }
          end)

        {:ok, results}

      _ ->
        # Try as callback second
        case aggregate_callback_docs(module, function, arity) do
          list when is_list(list) and list != [] ->
            results =
              Enum.map(list, fn callback_info ->
                %{
                  module: inspect(module),
                  callback: Atom.to_string(function),
                  arity: callback_info[:arity] || arity,
                  documentation: callback_info[:documentation] || "",
                  spec: callback_info[:spec],
                  kind: callback_info[:kind],
                  metadata: callback_info[:metadata] || %{}
                }
              end)

            {:ok, results}

          _ ->
            # Try as type third
            case aggregate_type_docs(module, function, arity) do
              list when is_list(list) and list != [] ->
                results =
                  Enum.map(list, fn type_info ->
                    %{
                      module: inspect(module),
                      type: Atom.to_string(function),
                      arity: type_info[:arity] || arity,
                      documentation: type_info[:documentation] || ""
                    }
                  end)

                {:ok, results}

              _ ->
                {:error,
                 "Remote call #{module}.#{function}/#{arity || "?"} - no documentation found"}
            end
        end
    end
  end

  defp get_documentation(:attribute, attribute) do
    docs = aggregate_attribute_docs(attribute)
    {:ok, docs}
  end

  defp aggregate_module_docs(module) do
    ensure_loaded(module)

    sections = []

    # Module documentation
    {moduledoc_content, moduledoc_metadata} =
      case NormalizedCode.get_docs(module, :moduledoc) do
        {_, doc, metadata} when is_binary(doc) ->
          {doc, metadata}

        _ ->
          {nil, %{}}
      end

    module_doc =
      if moduledoc_content do
        %{
          type: "moduledoc",
          content: moduledoc_content,
          metadata: moduledoc_metadata
        }
      else
        nil
      end

    sections = if module_doc, do: [module_doc | sections], else: sections

    # Get all functions and macros and their docs
    {functions, macros} =
      case NormalizedCode.get_docs(module, :docs) do
        docs when is_list(docs) ->
          formatted_docs =
            docs
            |> Enum.map(fn doc -> format_function_doc(module, doc) end)
            |> Enum.reject(&is_nil/1)

          # Separate functions and macros
          functions = Enum.filter(formatted_docs, &(&1.kind == :function))
          macros = Enum.filter(formatted_docs, &(&1.kind == :macro))
          {functions, macros}

        _ ->
          # Even if there are no docs, we should check if there are functions available
          # by inspecting the module's exports
          try do
            exports = module.module_info(:exports)
            # Filter out module_info functions and other special functions
            functions =
              exports
              |> Enum.filter(fn {name, _arity} ->
                name not in [:module_info, :__info__, :behaviour_info] and
                  not String.starts_with?(Atom.to_string(name), "_")
              end)
              |> Enum.map(fn {name, arity} ->
                %{
                  function: Atom.to_string(name),
                  arity: arity,
                  kind: :function,
                  signature: "#{name}/#{arity}",
                  doc: nil,
                  specs: [],
                  metadata: %{}
                }
              end)

            {functions, []}
          rescue
            _ -> {[], []}
          end
      end

    sections = if functions != [], do: [{:functions, functions} | sections], else: sections
    sections = if macros != [], do: [{:macros, macros} | sections], else: sections

    # Get all types and their docs
    types =
      case NormalizedCode.get_docs(module, :type_docs) do
        docs when is_list(docs) ->
          docs
          |> Enum.map(fn doc -> format_type_doc(module, doc) end)
          |> Enum.reject(&is_nil/1)

        _other ->
          []
      end

    sections = if types != [], do: [{:types, types} | sections], else: sections

    # Get callbacks if it's a behaviour
    all_callbacks =
      case NormalizedCode.get_docs(module, :callback_docs) do
        docs when is_list(docs) ->
          docs
          |> Enum.map(fn doc -> format_callback_doc(module, doc) end)
          |> Enum.reject(&is_nil/1)

        _ ->
          []
      end

    # Separate callbacks and macrocallbacks
    callbacks = Enum.filter(all_callbacks, &(&1.kind == :callback))
    macrocallbacks = Enum.filter(all_callbacks, &(&1.kind == :macrocallback))

    sections = if callbacks != [], do: [{:callbacks, callbacks} | sections], else: sections

    sections =
      if macrocallbacks != [], do: [{:macrocallbacks, macrocallbacks} | sections], else: sections

    # Get behaviour info
    behaviours = get_module_behaviours(module)
    sections = if behaviours != [], do: [{:behaviours, behaviours} | sections], else: sections

    module_name = inspect(module)

    # Extract functions and macros lists from sections
    functions_list =
      case Enum.find(sections, fn
             {:functions, _} -> true
             _ -> false
           end) do
        {:functions, functions} -> Enum.map(functions, &"#{&1.function}/#{&1.arity}")
        _ -> []
      end

    macros_list =
      case Enum.find(sections, fn
             {:macros, _} -> true
             _ -> false
           end) do
        {:macros, macros} -> Enum.map(macros, &"#{&1.function}/#{&1.arity}")
        _ -> []
      end

    types_list =
      case Enum.find(sections, fn
             {:types, _} -> true
             _ -> false
           end) do
        {:types, types} -> Enum.map(types, &"#{&1.type}/#{&1.arity}")
        _ -> []
      end

    callbacks_list =
      case Enum.find(sections, fn
             {:callbacks, _} -> true
             _ -> false
           end) do
        {:callbacks, callbacks} -> Enum.map(callbacks, &"#{&1.callback}/#{&1.arity}")
        _ -> []
      end

    macrocallbacks_list =
      case Enum.find(sections, fn
             {:macrocallbacks, _} -> true
             _ -> false
           end) do
        {:macrocallbacks, macrocallbacks} ->
          Enum.map(macrocallbacks, &"#{&1.callback}/#{&1.arity}")

        _ ->
          []
      end

    behaviours_list =
      case Enum.find(sections, fn
             {:behaviours, _} -> true
             _ -> false
           end) do
        {:behaviours, behaviours} -> behaviours
        _ -> []
      end

    %{
      module: module_name,
      moduledoc: moduledoc_content,
      moduledoc_metadata: moduledoc_metadata,
      functions: functions_list,
      macros: macros_list,
      types: types_list,
      callbacks: callbacks_list,
      macrocallbacks: macrocallbacks_list,
      behaviours: behaviours_list
    }
  end

  defp aggregate_function_docs(module, function, arity) do
    ensure_loaded(module)

    # Try to get function documentation
    function_docs =
      case NormalizedCode.get_docs(module, :docs) do
        docs when is_list(docs) ->
          find_function_docs(docs, function, arity)

        _ ->
          []
      end

    # Get specs
    specs = get_function_specs(module, function, arity)

    function_docs
    |> Enum.map(fn {{name, doc_arity}, _anno, kind, _signatures, doc, metadata} ->
      %{
        type: kind,
        arity: doc_arity,
        signature: "#{function}/#{doc_arity}",
        doc: extract_doc(doc),
        metadata: metadata,
        specs: Map.get(specs, {name, doc_arity}, [])
      }
    end)
  end

  defp aggregate_type_docs(module, type, arity) do
    ensure_loaded(module)

    # Get type documentation
    type_docs =
      case NormalizedCode.get_docs(module, :type_docs) do
        docs when is_list(docs) ->
          Enum.filter(docs, fn
            {{^type, type_arity}, _, _, _, _} ->
              arity == nil or type_arity == arity

            _ ->
              false
          end)

        _ ->
          []
      end

    # Get type spec
    type_specs_by_name_arity = get_type_specs(module, type, arity)

    Enum.map(type_docs, fn {{name, doc_arity}, _, _, doc, metadata} ->
      doc_content = extract_doc(doc)

      %{
        type: Atom.to_string(name),
        arity: doc_arity,
        spec: Map.get(type_specs_by_name_arity, {name, doc_arity}),
        documentation: doc_content || "",
        metadata: metadata
      }
    end)
  end

  defp aggregate_attribute_docs(attribute) do
    builtin_doc = BuiltinAttributes.docs(attribute)

    %{
      attribute: "@#{attribute}",
      documentation: builtin_doc || "No documentation available for @#{attribute}"
    }
  end

  defp ensure_loaded(module) do
    Code.ensure_loaded?(module)
  rescue
    _ -> false
  end

  defp format_function_doc(module, doc_entry) do
    case doc_entry do
      {{name, arity}, _line, kind, _signatures, doc, metadata} when kind in [:function, :macro] ->
        %{
          function: Atom.to_string(name),
          arity: arity,
          kind: kind,
          signature: format_function_signature(module, name, arity, metadata),
          doc: extract_doc(doc),
          specs: [],
          metadata: metadata
        }

      _ ->
        nil
    end
  end

  defp format_type_doc(_module, doc_entry) do
    case doc_entry do
      # Pattern: {{name, arity}, line, :type, doc_string, metadata}
      {{name, arity}, _line, :type, doc, metadata} ->
        %{
          type: Atom.to_string(name),
          arity: arity,
          doc: extract_doc(doc),
          metadata: metadata
        }

      _ ->
        nil
    end
  end

  defp format_callback_doc(_module, doc_entry) do
    case doc_entry do
      {{name, arity}, _line, kind, doc, metadata} when kind in [:callback, :macrocallback] ->
        %{
          callback: Atom.to_string(name),
          arity: arity,
          kind: kind,
          doc: extract_doc(doc),
          metadata: metadata
        }

      _ ->
        nil
    end
  end

  defp find_function_docs(docs, function, arity) do
    docs
    |> Enum.filter(fn
      {{^function, doc_arity}, _anno, kind, _spec, _doc, _meta}
      when kind in [:function, :macro] ->
        arity == nil or doc_arity == arity

      _ ->
        false
    end)
    |> Enum.sort_by(fn
      {{_name, doc_arity}, _anno, _kind, _spec, _doc, _meta} ->
        doc_arity
    end)
  end

  defp aggregate_callback_docs(module, callback, arity) do
    ensure_loaded(module)

    # Get callback documentation using Introspection
    callback_docs = Introspection.get_callbacks_with_docs(module)

    # Filter callbacks by name and arity
    callback_infos =
      callback_docs
      |> Enum.filter(fn
        %{name: ^callback, arity: callback_arity} ->
          arity == nil or callback_arity == arity

        _ ->
          false
      end)

    Enum.map(callback_infos, fn callback_info ->
      callback_result = %{
        callback: Atom.to_string(callback),
        arity: callback_info.arity,
        documentation: extract_doc(callback_info.doc),
        spec: callback_info.callback,
        kind: callback_info.kind,
        metadata: callback_info.metadata
      }

      callback_result = Map.put(callback_result, :metadata, callback_info.metadata)

      callback_result
    end)
  end

  defp get_function_specs(module, function, arity) do
    # Get all specs for the module using TypeInfo.get_module_specs to match llm_type_info.ex
    module_specs = TypeInfo.get_module_specs(module)

    # Filter specs for the function/arity, including macro specs
    filtered_specs =
      module_specs
      |> Enum.filter(fn
        {{spec_name, spec_arity}, _} ->
          # Check if it's a regular function match
          regular_match = spec_name == function and (arity == nil or spec_arity == arity)

          # Check if it's a macro match (MACRO-name/arity+1)
          macro_name = String.to_atom("MACRO-#{function}")

          macro_match =
            if arity == nil do
              spec_name == macro_name
            else
              spec_name == macro_name and spec_arity == arity + 1
            end

          regular_match or macro_match

        _ ->
          false
      end)

    # Format each spec and return as a list for compatibility with format_function_sections
    filtered_specs
    |> Map.new(fn {_key, {{name, spec_arity}, specs}} ->
      formatted_spec = Introspection.spec_to_string({{name, spec_arity}, specs}, :spec)

      # Normalize macro names for the result key
      {display_name, display_arity} = normalize_macro_name_and_arity(name, spec_arity)
      normalized_key = {String.to_atom(display_name), display_arity}

      # Return as a list containing the single spec for compatibility with Enum.map_join
      {normalized_key, [formatted_spec]}
    end)
  end

  defp get_type_specs(module, type, arity) do
    case Typespec.get_types(module) do
      types when is_list(types) ->
        types
        |> Enum.filter(fn
          {kind, {^type, _, args}} when kind in [:type, :opaque] ->
            arity == nil or length(args) == arity

          _ ->
            false
        end)
        |> Enum.map(fn {kind, {name, _, args}} = typedef ->
          spec =
            try do
              TypeInfo.format_type_spec(typedef, line_length: 75)
            catch
              _ -> "@#{kind} #{name}/#{length(args)}"
            end

          {{name, length(args)}, spec}
        end)
        |> Map.new()

      _ ->
        %{}
    end
  end

  defp format_function_signature(module, name, arity, metadata) do
    args =
      try do
        Map.get(metadata, :signature, List.duplicate("arg", arity || 0))
      rescue
        _ -> List.duplicate("arg", arity || 0)
      end

    try do
      "#{inspect(module)}.#{name}(#{Enum.join(args, ", ")})"
    rescue
      _ -> "#{inspect(module)}.#{name}/#{arity || 0}"
    end
  end

  defp get_module_behaviours(module) do
    module.module_info(:attributes)
    |> Keyword.get(:behaviour, [])
    |> Enum.map(&inspect/1)
  rescue
    _ -> []
  end

  defp extract_doc(%{"en" => doc}) when is_binary(doc), do: doc
  defp extract_doc(doc) when is_binary(doc), do: doc
  defp extract_doc(:none), do: nil
  defp extract_doc(_), do: nil

  defp format_builtin_function_doc(doc, specs) do
    spec_part =
      if specs != [] do
        "\n\n**Specs:**\n#{Enum.map_join(specs, "\n", fn s -> "```elixir\n#{s}\n```" end)}"
      else
        ""
      end

    "#{doc}#{spec_part}"
  end

  defp format_function_sections(sections) do
    sections
    |> Enum.map(fn section ->
      doc_part = if section.doc, do: "\n\n#{section.doc}", else: ""

      spec_part =
        if section[:specs] && section.specs != [],
          do:
            "\n\n**Specs:**\n#{Enum.map_join(section.specs, "\n", fn s -> "```elixir\n#{s}\n```" end)}",
          else: ""

      metadata_part = format_metadata_section(section[:metadata])

      """
      ## #{section.signature}#{doc_part}#{spec_part}#{metadata_part}
      """
    end)
    |> Enum.join("\n")
  end

  defp format_metadata_section(metadata) when is_map(metadata) and metadata != %{} do
    metadata_md = MarkdownUtils.get_metadata_md(metadata)
    if metadata_md != "", do: "\n\n" <> metadata_md, else: ""
  end

  defp format_metadata_section(_), do: ""

  defp normalize_macro_name_and_arity(name, arity) do
    name_str = to_string(name)

    if String.starts_with?(name_str, "MACRO-") do
      # Remove "MACRO-" prefix and subtract 1 from arity
      display_name = String.replace_prefix(name_str, "MACRO-", "")
      display_arity = arity - 1
      {display_name, display_arity}
    else
      # Regular function, no transformation needed
      {name_str, arity}
    end
  end
end
