defmodule ElixirLS.LanguageServer.Providers.ExecuteCommand.LLM.SymbolParser do
  @moduledoc """
  Symbol parser V2 using Code.Fragment.cursor_context/2.

  Parses various Elixir symbol formats into structured data:
  - Remote calls: `Module.function`, `Module.function/2`, `:erlang.function/1` → `{:ok, :remote_call, {module, function, arity}}`
  - Local calls: `function`, `function/2` → `{:ok, :local_call, {function, arity}}`
  - Modules: `MyModule`, `MyModule.SubModule` → `{:ok, :module, module}`
  - Erlang modules: `:erlang`, `:lists` → `{:ok, :module, atom}`
  - Operators: `+`, `+/2`, `==`, `!=/2` → `{:ok, :local_call, {operator, arity}}`
  - Attributes: `@moduledoc`, `@doc` → `{:ok, :attribute, atom}`

  Cannot distinguish between function and type - both are parsed as calls.
  """

  alias ElixirSense.Core.Normalized.Code, as: NormalizedCode

  @type symbol_type :: :module | :local_call | :remote_call | :attribute
  @type parsed_module :: module()
  @type parsed_local_call :: {atom(), arity :: non_neg_integer() | nil}
  @type parsed_remote_call :: {module(), atom(), arity :: non_neg_integer() | nil}
  @type parsed_result ::
          {:ok, :module, parsed_module()}
          | {:ok, :local_call, parsed_local_call()}
          | {:ok, :remote_call, parsed_remote_call()}
          | {:ok, :attribute, atom()}
          | {:error, String.t()}

  @doc """
  Parses a symbol string into a structured format using cursor_context.
  """
  @spec parse(String.t()) :: parsed_result()
  def parse(symbol) when is_binary(symbol) do
    # Pre-process to extract arity if present
    {base_symbol, arity} = extract_arity(symbol)

    # For cursor_context, we need to position the cursor at the end of the symbol
    code = String.to_charlist(base_symbol)

    case NormalizedCode.Fragment.cursor_context(code) do
      {:alias, hint} ->
        # Module name like MyModule or MyModule.SubModule
        parse_alias(hint)

      {:dot, path, hint} ->
        # Remote call like Module.function
        parse_dot_call(path, hint, arity)

      {:local_or_var, hint} ->
        # Local call like function_name
        parse_local_call(hint, arity)

      {:operator, hint} ->
        # Operator like +, -, *, etc.
        parse_operator(hint, arity)

      {:unquoted_atom, hint} ->
        # Erlang module like :lists, :erlang, etc.
        parse_erlang_module(hint)

      {:module_attribute, hint} ->
        # Module attribute like @doc, @moduledoc, etc.
        parse_module_attribute(hint)

      :none ->
        # cursor_context doesn't recognize some patterns, try manual parsing
        parse_fallback(base_symbol, arity)

      _ ->
        {:error, "Not recognized"}
    end
  rescue
    _ -> {:error, "Error parsing symbol: #{symbol}"}
  end

  def parse(_), do: {:error, "Symbol must be a string"}

  # Private parsing functions

  defp extract_arity(symbol) do
    case String.split(symbol, "/") do
      [base, arity_str] ->
        try do
          arity = String.to_integer(arity_str)
          {base, arity}
        rescue
          _ -> {symbol, nil}
        end

      _ ->
        {symbol, nil}
    end
  end

  defp parse_alias(hint) do
    try do
      module_str = List.to_string(hint)
      module = Module.concat([module_str])
      {:ok, :module, module}
    rescue
      _ -> {:error, "Invalid module format"}
    end
  end

  defp parse_dot_call(path, hint, arity) do
    with {:ok, module} <- extract_module_from_path(path),
         function_atom <- List.to_atom(hint) do
      {:ok, :remote_call, {module, function_atom, arity}}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp parse_local_call(hint, arity) do
    try do
      function_atom = List.to_atom(hint)
      {:ok, :local_call, {function_atom, arity}}
    rescue
      _ -> {:error, "Invalid function format"}
    end
  end

  defp parse_operator(hint, arity) do
    try do
      operator_atom = List.to_atom(hint)
      {:ok, :local_call, {operator_atom, arity}}
    rescue
      _ -> {:error, "Invalid operator format"}
    end
  end

  defp parse_erlang_module(hint) do
    try do
      module_atom = List.to_atom(hint)
      {:ok, :module, module_atom}
    rescue
      _ -> {:error, "Invalid Erlang module format"}
    end
  end

  defp parse_module_attribute(hint) do
    try do
      attribute_atom = List.to_atom(hint)
      {:ok, :attribute, attribute_atom}
    rescue
      _ -> {:error, "Invalid module attribute format"}
    end
  end

  defp parse_fallback(symbol, arity) do
    # Handle operators and other symbols that cursor_context doesn't recognize
    cond do
      # Common operators that might not be recognized by cursor_context
      symbol in ["/", "..."] ->
        try do
          operator_atom = String.to_atom(symbol)
          {:ok, :local_call, {operator_atom, arity}}
        rescue
          _ -> {:error, "Invalid operator format"}
        end

      true ->
        {:error, "Unrecognized symbol format: #{symbol}"}
    end
  end

  defp extract_module_from_path(path) do
    case path do
      {:alias, module_parts} ->
        # Regular Elixir module
        try do
          module_str = List.to_string(module_parts)
          module = Module.concat([module_str])
          {:ok, module}
        rescue
          _ -> {:error, "Invalid module format"}
        end

      {:unquoted_atom, atom_name} ->
        # Erlang module like :lists
        try do
          module = List.to_atom(atom_name)
          {:ok, module}
        rescue
          _ -> {:error, "Invalid Erlang module format"}
        end

      _ ->
        {:error, "Unsupported module path format"}
    end
  end
end
