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
    if arity == nil do
      # When arity is nil, we need to return separate results for each arity
      get_documentation_for_all_arities(module, function)
    else
      # Try function/macro documentation first
      case aggregate_function_docs(module, function, arity) do
        %{documentation: doc} when doc != "" ->
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
            %{documentation: doc} when doc != "" ->
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
                %{documentation: doc} when doc != "" ->
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
  end

  defp get_documentation(:attribute, attribute) do
    docs = aggregate_attribute_docs(attribute)
    {:ok, docs}
  end

  defp get_documentation_for_all_arities(module, function) do
    ensure_loaded(module)

    # Get all documented arities from function docs
    documented_arities =
      case NormalizedCode.get_docs(module, :docs) do
        docs when is_list(docs) ->
          docs
          |> Enum.filter(fn
            {{^function, _arity}, _anno, kind, _signatures, _doc, _metadata}
            when kind in [:function, :macro] ->
              true

            _ ->
              false
          end)
          |> Enum.map(fn {{_name, arity}, _, _, _, _, _} -> arity end)
          |> Enum.uniq()

        _ ->
          []
      end

    # Also get arities from function specs
    spec_arities =
      case Typespec.get_specs(module) do
        specs when is_list(specs) ->
          specs
          |> Enum.filter(fn
            {{^function, _arity}, _} -> true
            _ -> false
          end)
          |> Enum.map(fn {{_name, arity}, _} -> arity end)
          |> Enum.uniq()

        _ ->
          []
      end

    # Get arities from type docs
    type_doc_arities =
      case NormalizedCode.get_docs(module, :type_docs) do
        docs when is_list(docs) ->
          docs
          |> Enum.filter(fn
            {{^function, _arity}, _, _, _, _} -> true
            _ -> false
          end)
          |> Enum.map(fn {{_name, arity}, _, _, _, _} -> arity end)
          |> Enum.uniq()

        _ ->
          []
      end

    # Get arities from type specs
    type_spec_arities =
      case Typespec.get_types(module) do
        types when is_list(types) ->
          types
          |> Enum.filter(fn
            {kind, {^function, _, _args}} when kind in [:type, :typep, :opaque] ->
              true

            _ ->
              false
          end)
          |> Enum.map(fn {_kind, {_name, _, args}} -> length(args) end)
          |> Enum.uniq()

        _ ->
          []
      end

    # Get arities from callbacks
    callback_arities =
      Introspection.get_callbacks_with_docs(module)
      |> Enum.filter(fn %{name: name} -> name == function end)
      |> Enum.map(fn %{arity: arity} -> arity end)
      |> Enum.uniq()

    # Combine and get unique arities
    all_arities =
      (documented_arities ++
         spec_arities ++ type_doc_arities ++ type_spec_arities ++ callback_arities)
      |> Enum.uniq()
      |> Enum.sort()

    if all_arities == [] do
      {:error, "Remote call #{module}.#{function} - no documentation found"}
    else
      # Get documentation for each arity
      results =
        all_arities
        |> Enum.map(fn arity ->
          case aggregate_function_docs(module, function, arity) do
            %{documentation: doc} when doc != "" ->
              %{
                module: inspect(module),
                function: Atom.to_string(function),
                arity: arity,
                documentation: doc
              }

            _ ->
              # Try as callback second
              case aggregate_callback_docs(module, function, arity) do
                %{documentation: doc} when doc != "" ->
                  %{
                    module: inspect(module),
                    callback: Atom.to_string(function),
                    arity: arity,
                    documentation: doc
                  }

                _ ->
                  # Try as type third
                  case aggregate_type_docs(module, function, arity) do
                    %{documentation: doc} when doc != "" ->
                      %{
                        module: inspect(module),
                        type: Atom.to_string(function),
                        arity: arity,
                        documentation: doc
                      }

                    _ ->
                      # If no documentation found, but we know this arity exists,
                      # return a result with "No documentation available"
                      function_str = Atom.to_string(function)

                      %{
                        module: inspect(module),
                        type: function_str,
                        arity: arity,
                        documentation: "No documentation available for #{function_str}/#{arity}"
                      }
                  end
              end
          end
        end)

      if results == [] do
        {:error, "Remote call #{module}.#{function} - no documentation found"}
      else
        {:ok, results}
      end
    end
  end

  defp aggregate_module_docs(module) do
    ensure_loaded(module)

    sections = []

    # Module documentation
    moduledoc_content =
      case NormalizedCode.get_docs(module, :moduledoc) do
        {_, doc, _metadata} when is_binary(doc) ->
          doc

        _ ->
          nil
      end

    module_doc =
      if moduledoc_content do
        %{
          type: "moduledoc",
          content: moduledoc_content
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

    sections =
      cond do
        function_docs != [] ->
          function_docs
          |> Enum.map(fn {{name, doc_arity}, _anno, kind, _signatures, doc, metadata} ->
            # Get specs for this specific arity
            doc_specs = get_function_specs(module, name, doc_arity)

            %{
              type: kind,
              signature: "#{function}/#{doc_arity}",
              doc: extract_doc(doc),
              metadata: metadata,
              specs: doc_specs
            }
          end)

        true ->
          # No docs found, but still return specs if available
          if specs != [] do
            # When arity is nil, we need to get raw specs to group by arity
            if arity == nil do
              # Get raw specs directly
              case Typespec.get_specs(module) do
                raw_specs when is_list(raw_specs) ->
                  raw_specs
                  |> Enum.filter(fn
                    {{^function, _}, _} -> true
                    _ -> false
                  end)
                  |> Enum.group_by(fn {{_, spec_arity}, _} -> spec_arity end)
                  |> Enum.map(fn {spec_arity, arity_specs} ->
                    %{
                      type: "function",
                      signature: "#{function}/#{spec_arity}",
                      doc: nil,
                      specs: Enum.map(arity_specs, fn {_, spec} -> format_spec(spec) end)
                    }
                  end)

                _ ->
                  []
              end
            else
              [
                %{
                  type: "function",
                  signature: "#{function}/#{arity}",
                  doc: nil,
                  specs: specs
                }
              ]
            end
          else
            []
          end
      end

    %{
      module: inspect(module),
      function: Atom.to_string(function),
      arity: arity,
      documentation: format_function_sections(sections)
    }
  end

  defp aggregate_type_docs(module, type, arity) do
    ensure_loaded(module)

    # Get type documentation
    type_doc =
      case NormalizedCode.get_docs(module, :type_docs) do
        docs when is_list(docs) ->
          Enum.find(docs, fn
            {{^type, ^arity}, _, _, _, _} -> true
            _ -> false
          end)

        _ ->
          nil
      end

    # Get type spec
    type_spec = get_type_spec(module, type, arity)

    doc_content =
      case type_doc do
        {{_, _}, _, _, doc, _} -> extract_doc(doc)
        _ -> nil
      end

    %{
      type: Atom.to_string(type),
      arity: arity,
      spec: type_spec,
      documentation: doc_content || ""
    }
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
      {{name, arity}, _line, :type, doc, _metadata} ->
        %{
          type: Atom.to_string(name),
          arity: arity,
          doc: extract_doc(doc)
        }

      _ ->
        nil
    end
  end

  defp format_callback_doc(_module, doc_entry) do
    case doc_entry do
      {{name, arity}, _line, kind, doc, _metadata} when kind in [:callback, :macrocallback] ->
        %{
          callback: Atom.to_string(name),
          arity: arity,
          kind: kind,
          doc: extract_doc(doc)
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
  end

  defp aggregate_callback_docs(module, callback, arity) do
    ensure_loaded(module)

    # Get callback documentation using Introspection
    callback_docs = Introspection.get_callbacks_with_docs(module)

    # Find the specific callback by name and arity
    callback_info =
      Enum.find(callback_docs, fn
        %{name: ^callback, arity: ^arity} -> true
        _ -> false
      end)

    case callback_info do
      %{doc: doc, callback: spec, kind: kind} ->
        %{
          callback: Atom.to_string(callback),
          arity: arity,
          spec: spec,
          kind: kind,
          documentation: extract_doc(doc)
        }

      _ ->
        %{
          callback: Atom.to_string(callback),
          arity: arity,
          spec: nil,
          kind: :callback,
          documentation: ""
        }
    end
  end

  defp get_function_specs(module, function, arity) do
    # Get all specs for the module using TypeInfo.get_module_specs to match llm_type_info.ex
    module_specs = TypeInfo.get_module_specs(module)

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
    |> Enum.flat_map(fn {{name, spec_arity}, specs} ->
      # Collect all spec ASTs for this function/arity
      spec_asts = Enum.map(specs, fn {_, {{_, _}, spec_ast}} -> spec_ast end)

      # Flatten the spec_asts as they come nested from TypeInfo.get_module_specs
      flattened_spec_asts = List.flatten(spec_asts)

      # Use Introspection.spec_to_string to properly format Erlang specs to Elixir format
      try do
        case Introspection.spec_to_string({{name, spec_arity}, flattened_spec_asts}, :spec) do
          formatted_specs when is_list(formatted_specs) ->
            formatted_specs

          formatted_spec when is_binary(formatted_spec) ->
            [formatted_spec]

          _ ->
            []
        end
      catch
        _kind, _error ->
          []
      end
    end)
  end

  defp get_type_spec(module, type, arity) do
    case Typespec.get_types(module) do
      types when is_list(types) ->
        case Enum.find(types, fn
               {kind, {^type, _, args}} when kind in [:type, :opaque] ->
                 length(args) == arity

               _ ->
                 false
             end) do
          {_, type_ast} -> format_spec(type_ast)
          _ -> nil
        end

      _ ->
        nil
    end
  end

  defp format_spec(spec_ast) do
    # For type specs, try to format them properly
    try do
      Macro.to_string(spec_ast)
    rescue
      _ -> inspect(spec_ast)
    end
  end

  defp format_function_signature(module, name, arity, metadata) do
    args = Map.get(metadata, :signature, List.duplicate("arg", arity || 0))
    "#{inspect(module)}.#{name}(#{Enum.join(args, ", ")})"
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

      """
      ## #{section.signature}#{doc_part}#{spec_part}
      """
    end)
    |> Enum.join("\n")
  end
end
