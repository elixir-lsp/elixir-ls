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

  require Logger

  @behaviour ElixirLS.LanguageServer.Providers.ExecuteCommand

  @impl ElixirLS.LanguageServer.Providers.ExecuteCommand
  def execute([modules], _state) when is_list(modules) do
    try do
      results = Enum.map(modules, fn module_name ->
        case parse_symbol(module_name) do
          {:ok, type, parsed} ->
            case get_documentation(type, parsed) do
              {:ok, docs} ->
                %{
                  name: module_name,
                  module: docs[:module],
                  moduledoc: docs[:moduledoc],
                  functions: docs[:functions] || []
                }

              {:error, reason} ->
                %{name: module_name, error: "Failed to get documentation: #{reason}"}
            end

          {:error, reason} ->
            %{name: module_name, error: "Invalid symbol format: #{reason}"}
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

  # Parse symbol strings like "MyModule", "MyModule.my_function", "MyModule.my_function/2", "@attribute"
  defp parse_symbol(symbol) do
    cond do
      # Attribute format @attribute
      String.starts_with?(symbol, "@") ->
        attribute_name = String.slice(symbol, 1..-1//1) |> String.to_atom()
        {:ok, :attribute, attribute_name}

      # Erlang module format :module (but not invalid patterns like :::invalid:::)
      String.starts_with?(symbol, ":") && !String.starts_with?(symbol, "::") ->
        module_str = String.slice(symbol, 1..-1//1)
        # Validate it's a proper module name
        if String.match?(module_str, ~r/^[a-z][a-z0-9_]*$/) do
          module_atom = String.to_atom(module_str)
          {:ok, :erlang_module, module_atom}
        else
          {:error, "Unrecognized symbol format"}
        end

      # Type with arity: Module.t/1 (check this before function patterns)
      String.match?(symbol, ~r/^[A-Z][A-Za-z0-9_.]*\.t\/\d+$/) ->
        [module_type, arity_str] = String.split(symbol, "/")
        module_str = String.replace_suffix(module_type, ".t", "")

        module = Module.concat(String.split(module_str, "."))
        arity = String.to_integer(arity_str)

        {:ok, :type, {module, :t, arity}}

      # Function with arity: Module.function/arity
      String.match?(symbol, ~r/^[A-Z][A-Za-z0-9_.]*\.[a-z_][a-z0-9_?!]*\/\d+$/) ->
        [module_fun, arity_str] = String.split(symbol, "/")
        [module_str, function_str] = String.split(module_fun, ".", parts: 2)

        module = Module.concat(String.split(module_str, "."))
        function = String.to_atom(function_str)
        arity = String.to_integer(arity_str)

        {:ok, :function, {module, function, arity}}

      # Function without arity: Module.function
      String.match?(symbol, ~r/^[A-Z][A-Za-z0-9_.]*\.[a-z_][a-z0-9_?!]*$/) ->
        [module_str, function_str] = String.split(symbol, ".", parts: 2)

        module = Module.concat(String.split(module_str, "."))
        function = String.to_atom(function_str)

        {:ok, :function, {module, function, nil}}

      # Module only: Module or Module.SubModule
      String.match?(symbol, ~r/^[A-Z][A-Za-z0-9_.]*$/) ->
        module = Module.concat(String.split(symbol, "."))
        {:ok, :module, module}

      # Builtin type: atom(), list(), etc.
      String.match?(symbol, ~r/^[a-z_][a-z0-9_]*\(\)$/) ->
        type_name = String.replace_suffix(symbol, "()", "") |> String.to_atom()
        {:ok, :builtin_type, type_name}

      true ->
        {:error, "Unrecognized symbol format"}
    end
  end

  defp get_documentation(:module, module) do
    docs = aggregate_module_docs(module)
    {:ok, docs}
  end

  defp get_documentation(:erlang_module, module) do
    get_documentation(:module, module)
  end

  defp get_documentation(:function, {module, function, arity}) do
    docs = aggregate_function_docs(module, function, arity)
    {:ok, docs}
  end

  defp get_documentation(:type, {module, type, arity}) do
    docs = aggregate_type_docs(module, type, arity)
    {:ok, docs}
  end

  # TODO: How?
  defp get_documentation(:attribute, attribute) do
    docs = aggregate_attribute_docs(attribute)
    {:ok, docs}
  end

  defp get_documentation(:builtin_type, type) do
    docs = aggregate_builtin_type_docs(type)
    {:ok, docs}
  end

  defp aggregate_module_docs(module) do
    ensure_loaded(module)
    
    sections = []

    # Module documentation
    moduledoc_content = case NormalizedCode.get_docs(module, :moduledoc) do
      {_, doc} when is_binary(doc) ->
        doc
      # Erlang module format
      {_, doc, _metadata} when is_binary(doc) ->
        doc
      _ ->
        nil
    end

    module_doc = if moduledoc_content do
      %{
        type: "moduledoc",
        content: moduledoc_content
      }
    else
      nil
    end

    sections = if module_doc, do: [module_doc | sections], else: sections

    # Get all functions and their docs
    functions = case NormalizedCode.get_docs(module, :docs) do
      docs when is_list(docs) ->
        docs
        |> Enum.map(fn doc -> format_function_doc(module, doc) end)
        |> Enum.reject(&is_nil/1)
      _ ->
        []
    end

    sections = if functions != [], do: [{:functions, functions} | sections], else: sections

    # Get all types and their docs
    types = case NormalizedCode.get_docs(module, :type_docs) do
      docs when is_list(docs) ->
        docs
        |> Enum.map(fn doc -> format_type_doc(module, doc) end)
        |> Enum.reject(&is_nil/1)
      _ ->
        []
    end

    sections = if types != [], do: [{:types, types} | sections], else: sections

    # Get callbacks if it's a behaviour
    callbacks = case NormalizedCode.get_docs(module, :callback_docs) do
      docs when is_list(docs) ->
        docs
        |> Enum.map(fn doc -> format_callback_doc(module, doc) end)
        |> Enum.reject(&is_nil/1)
      _ ->
        []
    end

    sections = if callbacks != [], do: [{:callbacks, callbacks} | sections], else: sections

    # Get behaviour info
    behaviours = get_module_behaviours(module)
    sections = if behaviours != [], do: [{:behaviours, behaviours} | sections], else: sections

    # For Erlang modules like :lists, keep the atom format
    module_name = if is_atom(module) do
      module_str = Atom.to_string(module)
      if String.starts_with?(module_str, "Elixir.") do
        inspect(module)
      else
        ":#{module}"
      end
    else
      inspect(module)
    end
    
    %{
      module: module_name,
      moduledoc: moduledoc_content,
      functions: format_sections_as_list(Enum.reverse(sections))
    }
  end

  defp aggregate_function_docs(module, function, arity) do
    ensure_loaded(module)

    # Try to get function documentation
    function_docs = case NormalizedCode.get_docs(module, :docs) do
      docs when is_list(docs) ->
        find_function_docs(docs, function, arity)
      _ ->
        []
    end

    # Get specs
    specs = get_function_specs(module, function, arity)

    # Check if it's a builtin
    builtin_docs = if module == Kernel or module == Kernel.SpecialForms do
      BuiltinFunctions.get_docs({function, arity})
    else
      nil
    end

    sections = 
      cond do
        function_docs != [] ->
          function_docs
          |> Enum.map(fn doc ->
            {{_kind, name, doc_arity}, _anno, _signatures, doc, metadata} = doc
            # Get specs for this specific arity
            doc_specs = get_function_specs(module, name, doc_arity)
            %{
              type: "function",
              signature: "#{function}/#{doc_arity}",
              doc: extract_doc(doc),
              metadata: metadata,
              specs: doc_specs
            }
          end)

        builtin_docs ->
          [%{
            type: "builtin_function",
            signature: "#{function}/#{arity || "?"}",
            doc: builtin_docs[:docs],
            specs: builtin_docs[:specs] || []
          }]

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
              [%{
                type: "function",
                signature: "#{function}/#{arity}",
                doc: nil,
                specs: specs
              }]
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
    type_doc = case NormalizedCode.get_docs(module, :type_docs) do
      docs when is_list(docs) ->
        Enum.find(docs, fn
          {{:type, ^type, ^arity}, _, _, _, _} -> true
          _ -> false
        end)
      _ ->
        nil
    end

    # Get type spec
    type_spec = get_type_spec(module, type, arity)

    doc_content = case type_doc do
      {{:type, _, _}, _, _, doc, _} -> extract_doc(doc)
      _ -> nil
    end

    %{
      type: Atom.to_string(type),
      arity: arity,
      spec: type_spec,
      documentation: doc_content || "No documentation available for #{type}/#{arity}"
    }
  end

  defp aggregate_attribute_docs(attribute) do
    builtin_doc = BuiltinAttributes.docs(attribute)
    
    %{
      attribute: "@#{attribute}",
      documentation: builtin_doc || "No documentation available for @#{attribute}"
    }
  end

  defp aggregate_builtin_type_docs(type) do
    # Use get_builtin_type_doc which returns the doc string directly
    builtin_doc = BuiltinTypes.get_builtin_type_doc(type)
    
    # get_builtin_type_doc returns empty string when not found
    doc = if builtin_doc == "", do: nil, else: builtin_doc
    
    %{
      type: "#{type}()",
      documentation: doc || "No documentation available for #{type}()"
    }
  end

  defp ensure_loaded(module) do
    Code.ensure_loaded?(module)
  rescue
    _ -> false
  end

  defp format_function_doc(module, doc_entry) do
    case doc_entry do
      # Elixir module format
      {{kind, name, arity}, _anno, _signatures, doc, metadata} when kind in [:function, :macro] ->
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

      # Erlang module format
      {{name, arity}, _line, :function, _signatures, doc, metadata} ->
        specs = get_function_specs(module, name, arity)
        
        %{
          function: Atom.to_string(name),
          arity: arity,
          kind: :function,
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
      {{:type, name, arity}, _anno, _signatures, doc, _metadata} ->
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
      # Handle the actual format returned by NormalizedCode.get_docs for callbacks
      {{name, arity}, _line, :callback, doc, _metadata} ->
        %{
          callback: Atom.to_string(name),
          arity: arity,
          kind: :callback,
          doc: extract_doc(doc)
        }
      {{kind, name, arity}, _anno, _signatures, doc, _metadata} when kind in [:callback, :macrocallback] ->
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
      {{kind, ^function, doc_arity}, _, _, _, _} when kind in [:function, :macro] ->
        arity == nil or doc_arity == arity
      _ ->
        false
    end)
  end

  defp get_function_specs(module, function, arity) do
    # Get all specs for the module
    case Typespec.get_specs(module) do
      specs when is_list(specs) ->
        specs
        |> Enum.filter(fn
          {{^function, spec_arity}, _} ->
            arity == nil or spec_arity == arity
          _ ->
            false
        end)
        |> Enum.map(fn {_, spec} ->
          format_spec(spec)
        end)
      _ ->
        []
    end
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
    Macro.to_string(spec_ast)
  rescue
    _ -> inspect(spec_ast)
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


  defp format_sections_as_list(sections) do
    sections
    |> Enum.flat_map(fn
      %{type: "moduledoc", content: _content} ->
        # Moduledoc is handled separately, not included in functions list
        []

      {:functions, functions} ->
        # Convert each function to a string representation
        Enum.map(functions, fn f ->
          "#{f.function}/#{f.arity}"
        end)

      {:types, _types} ->
        # Types are not part of the functions list
        []

      {:callbacks, _callbacks} ->
        # Callbacks are not part of the functions list
        []

      {:behaviours, _behaviours} ->
        # Behaviours are not part of the functions list
        []
    end)
  end


  defp extract_doc(%{"en" => doc}) when is_binary(doc), do: doc
  defp extract_doc(doc) when is_binary(doc), do: doc
  defp extract_doc(:none), do: nil
  defp extract_doc(_), do: nil

  defp format_function_sections(sections) do
    sections
    |> Enum.map(fn section ->
      doc_part = if section.doc, do: "\n\n#{section.doc}", else: ""
      spec_part = if section[:specs] && section.specs != [], do: "\n\n**Specs:**\n#{Enum.map_join(section.specs, "\n", fn s -> "```elixir\n@spec #{s}\n```" end)}", else: ""
      
      """
      ## #{section.signature}#{doc_part}#{spec_part}
      """
    end)
    |> Enum.join("\n")
  end
end
