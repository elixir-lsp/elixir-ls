defmodule ElixirLS.LanguageServer.MCP.RequestHandler do
  @moduledoc """
  Handles MCP (Model Context Protocol) requests.
  Extracted from TCPServer for better testability.
  """

  require Logger
  alias JasonV

  alias ElixirLS.LanguageServer.Providers.ExecuteCommand.{
    LlmDocsAggregator,
    LlmTypeInfo,
    LlmDefinition,
    LlmImplementationFinder,
    LlmModuleDependencies
  }

  @doc """
  Handles an MCP request and returns the appropriate response.
  Returns nil for notifications (which don't require a response).
  """
  def handle_request(request) do
    case request do
      %{"method" => "initialize", "id" => id} ->
        handle_initialize(id)

      %{"method" => "tools/list", "id" => id} ->
        handle_tools_list(id)

      %{"method" => "tools/call", "params" => params, "id" => id} ->
        handle_tool_call(params, id)

      %{"method" => "notifications/cancelled", "params" => params} ->
        handle_notification_cancelled(params)

      %{"method" => method, "id" => id} ->
        %{
          "jsonrpc" => "2.0",
          "error" => %{
            "code" => -32601,
            "message" => "Method not found: #{method}"
          },
          "id" => id
        }

      _ ->
        %{
          "jsonrpc" => "2.0",
          "error" => %{
            "code" => -32600,
            "message" => "Invalid request"
          },
          "id" => nil
        }
    end
  end

  defp handle_initialize(id) do
    %{
      "jsonrpc" => "2.0",
      "result" => %{
        "protocolVersion" => "2024-11-05",
        "capabilities" => %{
          "tools" => %{}
        },
        "serverInfo" => %{
          "name" => "ElixirLS MCP Server",
          "version" => "1.0.0"
        }
      },
      "id" => id
    }
  end

  defp handle_tools_list(id) do
    %{
      "jsonrpc" => "2.0",
      "result" => %{
        "tools" => [
          %{
            "name" => "find_definition",
            "description" => "Find and retrieve source code definitions",
            "inputSchema" => %{
              "type" => "object",
              "properties" => %{
                "symbol" => %{
                  "type" => "string",
                  "description" => "The symbol to find"
                }
              },
              "required" => ["symbol"]
            }
          },
          %{
            "name" => "get_environment",
            "description" => "Get environment information at a specific location",
            "inputSchema" => %{
              "type" => "object",
              "properties" => %{
                "location" => %{
                  "type" => "string",
                  "description" => "Location in format 'file.ex:line:column' or 'file.ex:line'"
                }
              },
              "required" => ["location"]
            }
          },
          %{
            "name" => "get_docs",
            "description" =>
              "Aggregate and return documentation for multiple Elixir modules or functions",
            "inputSchema" => %{
              "type" => "object",
              "properties" => %{
                "modules" => %{
                  "type" => "array",
                  "description" => "List of module or function names to get documentation for",
                  "items" => %{
                    "type" => "string"
                  }
                }
              },
              "required" => ["modules"]
            }
          },
          %{
            "name" => "get_type_info",
            "description" =>
              "Extract type information from Elixir modules including types, specs, callbacks, and Dialyzer contracts",
            "inputSchema" => %{
              "type" => "object",
              "properties" => %{
                "module" => %{
                  "type" => "string",
                  "description" => "The module name to get type information for"
                }
              },
              "required" => ["module"]
            }
          },
          %{
            "name" => "find_implementations",
            "description" =>
              "Find implementations of behaviours, protocols, and defdelegate targets",
            "inputSchema" => %{
              "type" => "object",
              "properties" => %{
                "symbol" => %{
                  "type" => "string",
                  "description" => "The symbol to find implementations for"
                }
              },
              "required" => ["symbol"]
            }
          },
          %{
            "name" => "get_module_dependencies",
            "description" =>
              "Get module dependency information including direct dependencies, reverse dependencies, and transitive dependencies",
            "inputSchema" => %{
              "type" => "object",
              "properties" => %{
                "module" => %{
                  "type" => "string",
                  "description" => "The module name to get dependencies for"
                }
              },
              "required" => ["module"]
            }
          }
        ]
      },
      "id" => id
    }
  end

  defp handle_tool_call(params, id) do
    case params do
      %{"name" => "find_definition", "arguments" => %{"symbol" => symbol}} ->
        handle_find_definition(symbol, id)

      %{"name" => "get_environment", "arguments" => %{"location" => location}} ->
        handle_get_environment(location, id)

      %{"name" => "get_docs", "arguments" => %{"modules" => modules}} when is_list(modules) ->
        handle_get_docs(modules, id)

      %{"name" => "get_type_info", "arguments" => %{"module" => module}} when is_binary(module) ->
        handle_get_type_info(module, id)

      %{"name" => "find_implementations", "arguments" => %{"symbol" => symbol}}
      when is_binary(symbol) ->
        handle_find_implementations(symbol, id)

      %{"name" => "get_module_dependencies", "arguments" => %{"module" => module}}
      when is_binary(module) ->
        handle_get_module_dependencies(module, id)

      _ ->
        %{
          "jsonrpc" => "2.0",
          "error" => %{
            "code" => -32602,
            "message" => "Invalid params"
          },
          "id" => id
        }
    end
  end

  defp handle_find_definition(symbol, id) do
    case LlmDefinition.execute([symbol], %{}) do
      {:ok, %{definition: definition}} ->
        %{
          "jsonrpc" => "2.0",
          "result" => %{
            "content" => [
              %{
                "type" => "text",
                "text" => definition
              }
            ]
          },
          "id" => id
        }

      {:ok, %{error: error}} ->
        %{
          "jsonrpc" => "2.0",
          "error" => %{
            "code" => -32603,
            "message" => error
          },
          "id" => id
        }

      _ ->
        %{
          "jsonrpc" => "2.0",
          "error" => %{
            "code" => -32603,
            "message" => "Internal error"
          },
          "id" => id
        }
    end
  end

  defp handle_get_environment(location, id) do
    # Placeholder response for now
    text = """
    Environment information for location: #{location}

    Note: This is a placeholder response. The MCP server cannot directly access
    the LanguageServer state. Use the VS Code language tool or the 'llmEnvironment'
    command for actual environment information.
    """

    %{
      "jsonrpc" => "2.0",
      "result" => %{
        "content" => [
          %{
            "type" => "text",
            "text" => text
          }
        ]
      },
      "id" => id
    }
  end

  defp handle_get_docs(modules, id) do
    case LlmDocsAggregator.execute([modules], %{}) do
      {:ok, result} ->
        text = format_docs_result(result)

        %{
          "jsonrpc" => "2.0",
          "result" => %{
            "content" => [
              %{
                "type" => "text",
                "text" => text
              }
            ]
          },
          "id" => id
        }

      _ ->
        %{
          "jsonrpc" => "2.0",
          "error" => %{
            "code" => -32603,
            "message" => "Failed to get documentation"
          },
          "id" => id
        }
    end
  end

  defp handle_get_type_info(module, id) do
    case LlmTypeInfo.execute([module], %{}) do
      {:ok, result} ->
        text = format_type_info_result(result)

        %{
          "jsonrpc" => "2.0",
          "result" => %{
            "content" => [
              %{
                "type" => "text",
                "text" => text
              }
            ]
          },
          "id" => id
        }

      _ ->
        %{
          "jsonrpc" => "2.0",
          "error" => %{
            "code" => -32603,
            "message" => "Failed to get type information"
          },
          "id" => id
        }
    end
  end

  defp handle_find_implementations(symbol, id) do
    case LlmImplementationFinder.execute([symbol], %{}) do
      {:ok, %{implementations: implementations}} ->
        text = format_implementations_result(implementations)

        %{
          "jsonrpc" => "2.0",
          "result" => %{
            "content" => [
              %{
                "type" => "text",
                "text" => text
              }
            ]
          },
          "id" => id
        }

      {:ok, %{error: error}} ->
        %{
          "jsonrpc" => "2.0",
          "error" => %{
            "code" => -32603,
            "message" => error
          },
          "id" => id
        }

      _ ->
        %{
          "jsonrpc" => "2.0",
          "error" => %{
            "code" => -32603,
            "message" => "Failed to find implementations"
          },
          "id" => id
        }
    end
  end

  defp handle_get_module_dependencies(module, id) do
    case LlmModuleDependencies.execute([module], %{}) do
      {:ok, %{error: error}} ->
        %{
          "jsonrpc" => "2.0",
          "error" => %{
            "code" => -32603,
            "message" => error
          },
          "id" => id
        }

      {:ok, result} ->
        text = format_module_dependencies_result(result)

        %{
          "jsonrpc" => "2.0",
          "result" => %{
            "content" => [
              %{
                "type" => "text",
                "text" => text
              }
            ]
          },
          "id" => id
        }

      _ ->
        %{
          "jsonrpc" => "2.0",
          "error" => %{
            "code" => -32603,
            "message" => "Failed to get module dependencies"
          },
          "id" => id
        }
    end
  end

  defp handle_notification_cancelled(%{"requestId" => request_id}) do
    # For now, just log that we received a cancellation
    # In a real implementation, we would cancel the ongoing request with the given ID
    Logger.debug("[MCP] Received cancellation for request #{request_id}")
    # No response is sent for notifications
    nil
  end

  # Formatting functions

  defp format_docs_result(%{error: error}) do
    "Error: #{error}"
  end

  defp format_docs_result(%{results: results}) do
    results
    |> Enum.map(&format_single_doc_result/1)
    |> Enum.join("\n\n---\n\n")
  end

  defp format_docs_result(_), do: "Unknown result format"

  defp format_single_doc_result(result) do
    case result do
      # Module documentation
      %{module: module, moduledoc: _} ->
        parts = ["# Module: #{module}"]

        parts =
          if result[:moduledoc] do
            parts ++ ["\n#{result.moduledoc}"]
          else
            parts
          end

        # Add various sections if they exist
        sections = [
          {:functions, "Functions"},
          {:macros, "Macros"}, 
          {:types, "Types"},
          {:callbacks, "Callbacks"},
          {:macrocallbacks, "Macro Callbacks"},
          {:behaviours, "Behaviours"}
        ]

        parts = Enum.reduce(sections, parts, fn {key, title}, acc ->
          if result[key] && length(result[key]) > 0 do
            items = Enum.map(result[key], &"- #{&1}")
            acc ++ ["\n## #{title}\n"] ++ items
          else
            acc
          end
        end)

        Enum.join(parts, "\n")

      # Function documentation
      %{function: function, module: module, arity: arity, documentation: doc} ->
        title = "# Function: #{module}.#{function}/#{arity}"
        if doc && doc != "" do
          "#{title}\n\n#{doc}"
        else
          "#{title}\n\nNo documentation available."
        end

      # Callback documentation
      %{callback: callback, module: module, arity: arity, documentation: doc} ->
        title = "# Callback: #{module}.#{callback}/#{arity}"
        if doc && doc != "" do
          "#{title}\n\n#{doc}"
        else
          "#{title}\n\nNo documentation available."
        end

      # Type documentation
      %{type: type, module: module, arity: arity, documentation: doc} ->
        title = "# Type: #{module}.#{type}/#{arity}"
        if doc && doc != "" do
          "#{title}\n\n#{doc}"
        else
          "#{title}\n\nNo documentation available."
        end

      # Attribute documentation
      %{attribute: attribute, documentation: doc} ->
        title = "# Attribute: #{attribute}"
        if doc && doc != "" do
          "#{title}\n\n#{doc}"
        else
          "#{title}\n\nNo documentation available."
        end

      # Error case
      %{error: error} ->
        "Error: #{error}"

      # Unknown format
      _ ->
        "Unknown result format: #{inspect(result)}"
    end
  end

  defp format_function_doc(func) when is_binary(func) do
    "- #{func}"
  end

  defp format_function_doc(func) when is_map(func) do
    parts = ["### #{func.function}/#{func.arity}"]

    parts =
      if func[:specs] && length(func.specs) > 0 do
        specs = Enum.join(func.specs, "\n")
        parts ++ ["\n```elixir\n#{specs}\n```"]
      else
        parts
      end

    parts =
      if func[:doc] do
        parts ++ ["\n#{func.doc}"]
      else
        parts
      end

    Enum.join(parts, "\n")
  end

  defp format_type_info_result(%{error: error}) do
    "Error: #{error}"
  end

  defp format_type_info_result(result) do
    header = ["# Type Information for #{result.module}"]

    # Count available information
    has_types = result[:types] && length(result.types) > 0
    has_specs = result[:specs] && length(result.specs) > 0
    has_callbacks = result[:callbacks] && length(result.callbacks) > 0
    has_dialyzer = result[:dialyzer_contracts] && length(result.dialyzer_contracts) > 0

    parts =
      if !has_types && !has_specs && !has_callbacks && !has_dialyzer do
        header ++
          [
            "\nNo type information available for this module.\n\nThis could be because:\n- The module has no explicit type specifications\n- The module is a built-in Erlang module without exposed type information\n- The module hasn't been compiled yet"
          ]
      else
        header
      end

    parts =
      if has_types do
        type_parts =
          Enum.map(result.types, fn type ->
            """
            ### #{type.name}
            Kind: #{type.kind}
            Signature: #{type.signature}
            ```elixir
            #{type.spec}
            ```
            #{if type[:doc], do: type.doc, else: ""}
            """
          end)

        parts ++ ["\n## Types\n"] ++ type_parts
      else
        parts
      end

    parts =
      if has_specs do
        spec_parts =
          Enum.map(result.specs, fn spec ->
            """
            ### #{spec.name}
            ```elixir
            #{spec.specs}
            ```
            #{if spec[:doc], do: spec.doc, else: ""}
            """
          end)

        parts ++ ["\n## Function Specs\n"] ++ spec_parts
      else
        parts
      end

    parts =
      if has_callbacks do
        callback_parts =
          Enum.map(result.callbacks, fn callback ->
            """
            ### #{callback.name}
            ```elixir
            #{callback.specs}
            ```
            #{if callback[:doc], do: callback.doc, else: ""}
            """
          end)

        parts ++ ["\n## Callbacks\n"] ++ callback_parts
      else
        parts
      end

    parts =
      if has_dialyzer do
        contract_parts =
          Enum.map(result.dialyzer_contracts, fn contract ->
            """
            ### #{contract.name} (line #{contract.line})
            ```elixir
            #{contract.contract}
            ```
            """
          end)

        parts ++ ["\n## Dialyzer Contracts\n"] ++ contract_parts
      else
        parts
      end

    Enum.join(parts, "\n")
  end

  defp format_implementations_result(implementations) do
    if Enum.empty?(implementations) do
      "No implementations found."
    else
      header = "# Implementations Found\n\n"

      implementations_text =
        implementations
        |> Enum.map(&format_single_implementation/1)
        |> Enum.join("\n\n")

      header <> implementations_text
    end
  end

  defp format_single_implementation(impl) do
    case impl do
      %{error: error} ->
        "Error: #{error}"

      %{module: module, function: function, arity: arity, file: file, line: line} ->
        """
        ## #{module}.#{function}/#{arity}

        **Location**: #{file}:#{line}
        """

      %{module: module, file: file, line: line} ->
        """
        ## #{module}

        **Location**: #{file}:#{line}
        """

      _ ->
        "Unknown implementation format: #{inspect(impl)}"
    end
  end

  defp format_module_dependencies_result(%{error: error}) do
    "Error: #{error}"
  end

  defp format_module_dependencies_result(result) do
    header = "# Module Dependencies for #{result.module}\n\n"

    parts = [header]

    # Add location if available
    parts =
      if result[:location] do
        parts ++ ["**Location**: #{result.location.uri}\n"]
      else
        parts
      end

    # Direct dependencies
    parts =
      if has_dependencies?(result.direct_dependencies) do
        parts ++
          [
            "## Direct Dependencies\n",
            format_dependency_section(result.direct_dependencies),
            "\n"
          ]
      else
        parts
      end

    # Reverse dependencies
    parts =
      if has_dependencies?(result.reverse_dependencies) do
        parts ++
          [
            "## Reverse Dependencies (Modules that depend on this module)\n",
            format_dependency_section(result.reverse_dependencies),
            "\n"
          ]
      else
        parts
      end

    # Transitive dependencies
    parts =
      if result[:transitive_dependencies] && !Enum.empty?(result.transitive_dependencies) do
        parts ++
          [
            "## Transitive Dependencies\n",
            format_module_list_section(result.transitive_dependencies),
            "\n"
          ]
      else
        parts
      end

    # Reverse transitive dependencies
    parts =
      if result[:reverse_transitive_dependencies] &&
           !Enum.empty?(result.reverse_transitive_dependencies) do
        parts ++
          [
            "## Reverse Transitive Dependencies\n",
            format_module_list_section(result.reverse_transitive_dependencies),
            "\n"
          ]
      else
        parts
      end

    # Show empty state if no dependencies
    if length(parts) == 1 do
      parts ++ ["This module has no tracked dependencies."]
    else
      parts
    end
    |> Enum.join("")
  end

  defp has_dependencies?(deps) do
    case deps do
      %{
        compile_dependencies: compile,
        runtime_dependencies: runtime,
        exports_dependencies: exports
      } ->
        !Enum.empty?(compile) || !Enum.empty?(runtime) || !Enum.empty?(exports)

      _ ->
        false
    end
  end

  defp format_dependency_section(deps) do
    sections = []

    sections =
      if deps.compile_dependencies && !Enum.empty?(deps.compile_dependencies) do
        sections ++
          [
            "### Compile-time Dependencies\n",
            format_module_list_section(deps.compile_dependencies),
            "\n"
          ]
      else
        sections
      end

    sections =
      if deps.runtime_dependencies && !Enum.empty?(deps.runtime_dependencies) do
        sections ++
          [
            "### Runtime Dependencies\n",
            format_module_list_section(deps.runtime_dependencies),
            "\n"
          ]
      else
        sections
      end

    sections =
      if deps.exports_dependencies && !Enum.empty?(deps.exports_dependencies) do
        sections ++
          [
            "### Export Dependencies\n",
            format_module_list_section(deps.exports_dependencies),
            "\n"
          ]
      else
        sections
      end

    sections =
      if deps.imports && !Enum.empty?(deps.imports) do
        sections ++
          [
            "### Imports\n",
            format_function_list_section(deps.imports),
            "\n"
          ]
      else
        sections
      end

    sections =
      if deps.function_calls && !Enum.empty?(deps.function_calls) do
        sections ++
          [
            "### Function Calls\n",
            format_function_list_section(deps.function_calls),
            "\n"
          ]
      else
        sections
      end

    sections =
      if deps.aliases && !Enum.empty?(deps.aliases) do
        sections ++
          [
            "### Aliases\n",
            format_module_list_section(deps.aliases),
            "\n"
          ]
      else
        sections
      end

    sections =
      if deps.requires && !Enum.empty?(deps.requires) do
        sections ++
          [
            "### Requires\n",
            format_module_list_section(deps.requires),
            "\n"
          ]
      else
        sections
      end

    sections =
      if deps.struct_expansions && !Enum.empty?(deps.struct_expansions) do
        sections ++
          [
            "### Struct Expansions\n",
            format_module_list_section(deps.struct_expansions),
            "\n"
          ]
      else
        sections
      end

    Enum.join(sections, "")
  end

  defp format_module_list_section(modules) when is_list(modules) do
    modules
    |> Enum.map(&"- #{&1}")
    |> Enum.join("\n")
  end

  defp format_function_list_section(functions) when is_list(functions) do
    functions
    |> Enum.map(&"- #{&1}")
    |> Enum.join("\n")
  end
end
