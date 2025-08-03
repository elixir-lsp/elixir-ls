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
        # Try as builtin type
        if arity == nil or arity == 0 do
          # TODO: doesn't work for types with arity > 0
          case BuiltinTypes.get_builtin_type_doc(function) do
            doc when doc != "" ->
              {:ok,
               %{
                 type: "#{function}()",
                 documentation: doc
               }}

            _ ->
              # Check if it's a builtin function or try other modules
              case BuiltinFunctions.get_docs({function, arity}) do
                "" ->
                  {:error, "Local call #{function}/#{arity || "?"} - no documentation found"}

                builtin_docs when is_binary(builtin_docs) ->
                  {
                    :ok,
                    %{
                      function: Atom.to_string(function),
                      arity: arity,
                      documentation: builtin_docs
                    }
                  }
              end
          end
        else
          {:error, "Local call #{function}/#{arity || "?"} - no documentation found"}
        end
    end
  end

  defp get_documentation(:remote_call, {module, function, arity}) do
      # Try function/macro documentation first
      case aggregate_function_docs(module, function, arity) do
        list = [_ | _] ->
          {:ok,
           %{
             module: inspect(module),
             function: Atom.to_string(function),
             arity: arity,
             documentation: doc
           }}

        _ ->
          # Try as callback second
          case aggregate_callback_docs(module, function, arity) do
            list = [_ | _] ->
              {:ok,
               %{
                 module: inspect(module),
                 callback: Atom.to_string(function),
                 arity: arity,
                 documentation: doc
               }}

            _ ->
              # Try as type third
              case aggregate_type_docs(module, function, arity) do
                list = [_ | _] ->
                  {:ok,
                   %{
                     module: inspect(module),
                     type: Atom.to_string(function),
                     arity: arity,
                     documentation: doc
                   }}

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
              signature: "#{function}/#{doc_arity}",
              doc: extract_doc(doc),
              metadata: metadata,
              specs: specs[{name, doc_arity}] || [],
            }
          end)
  end

  defp aggregate_type_docs(module, type, arity) do
    ensure_loaded(module)

    # Get type documentation
    type_docs =
      case NormalizedCode.get_docs(module, :type_docs) do
        docs when is_list(docs) ->
          Enum.find(docs, fn
            {{^type, type_arity}, _, _, _, _} ->
              arity == nil or type_arity == arity
            _ -> false
          end)

        _ ->
          nil
      end

    # Get type spec
    type_specs_by_name_arity = get_type_specs(module, type, arity)

    Enum.map(type_docs, fn {{name, arity}, _, _, doc, metadata} ->
      doc_content = extract_doc(doc)
      %{
      type: Atom.to_string(type),
      arity: arity,
      spec: type_specs[{name, arity}] || [],
      documentation: doc_content,
      metadata: type_metadata
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
        # TODO: wtf? why call it again here?
        specs = get_function_specs(module, name, arity)

        %{
          function: Atom.to_string(name),
          arity: arity,
          kind: kind,
          signature: format_function_signature(module, name, arity, metadata),
          doc: extract_doc(doc),
          specs: specs,
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

    # Find the specific callback by name and arity
    callback_infos =
      Enum.find(callback_docs, fn
        %{name: ^callback, arity: callback_arity} -> 
          arity == nil or callback_arity == arity
        _ -> false
      end)

    Enum.map(callback_infos, fn
      %{doc: doc, callback: spec, kind: kind, metadata: callback_metadata} ->
        %{
          callback: Atom.to_string(callback),
          arity: arity,
          spec: spec,
          kind: kind,
          documentation: extract_doc(doc),
          metadata: callback_metadata
        }
    end)
  end

  defp get_function_specs(module, function, arity) do
    # Get all specs for the module using TypeInfo.get_module_specs to match llm_type_info.ex
    module_specs = TypeInfo.get_module_specs(module)

    # TODO: macro specs?
    # Filter specs for the function/arity
    filtered_specs =
      module_specs
      |> Enum.filter(fn
        {{^function, spec_arity}, _} ->
          arity == nil or spec_arity == arity

        _ ->
          false
      end)

    # Group by function/arity and format each group
    filtered_specs
    |> Enum.group_by(fn {{name, spec_arity}, _} -> {name, spec_arity} end)
    |> Map.new(fn {{name, spec_arity}, specs} ->
      # Collect all spec ASTs for this function/arity
      formatted_asts = Enum.map(specs, fn {_, {{_, _}, spec_ast}} ->
        formatted = try do
          Introspection.spec_to_string({{name, spec_arity}, flattened_spec_asts}, :spec)
        catch
        _kind, _error ->
          nil
        end

        {{name, spec_arity}, formatted}
      end)
      |> Enum.reject(& is_nil(elem(&1, 1)))
    end)
  end

  defp get_type_specs(module, type, arity) do
    Typespec.get_types(module)
    |> Enum.filter(fn
      {kind, {^type, _, args}} when kind in [:type, :opaque] ->
        arity == nil or length(args) == arity

      _ ->
        false
    end)
    |> Enum.map(fn {kind, {name, _, args}} = spec_ast ->
      spec =
      try do
        TypeInfo.format_type_spec(typedef, line_length: 75)
      catch
        _ -> "@#{kind} #{name}/#{arity}"
      end

      {{name, length(args)}, spec}
    end)
    |> Map.new
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

  defp format_function_sections(sections) do
    sections
    |> Enum.map(fn section ->
      doc_part = if section.doc, do: "\n\n#{section.doc}", else: ""

      spec_part =
        if section[:specs] && section.specs != [],
          do:
            "\n\n**Specs:**\n#{Enum.map_join(section.specs, "\n", fn s -> "```elixir\n@spec #{s}\n```" end)}",
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

end
