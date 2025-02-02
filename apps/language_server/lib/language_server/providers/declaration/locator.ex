defmodule ElixirLS.LanguageServer.Providers.Declaration.Locator do
  @moduledoc """
  Provides a function to find the declaration of a callback or protocol function,
  that is, the place where a behaviour or protocol defines the callback that is being
  implemented.

  This is effectively the reverse of the "go to implementations" provider.
  """

  alias ElixirSense.Core.Behaviours
  alias ElixirSense.Core.Binding
  alias ElixirSense.Core.Metadata
  alias ElixirSense.Core.Normalized.Code, as: NormalizedCode
  alias ElixirSense.Core.State
  alias ElixirLS.LanguageServer.Location
  alias ElixirSense.Core.Parser

  require ElixirSense.Core.Introspection, as: Introspection

  @doc """
  Finds the declaration (callback or protocol definition) for the function under the cursor.

  It parses the code, determines the environment and then checks if the current function
  is an implementation of any behaviour (or protocol). For each matching behaviour,
  it returns the location where the callback is declared.

  Returns either a single `%Location{}` or a list of locations if multiple declarations are found.
  """
  def declaration(code, line, column, options \\ []) do
    case NormalizedCode.Fragment.surround_context(code, {line, column}) do
      :none ->
        nil

      context ->
        metadata =
          Keyword.get_lazy(options, :metadata, fn ->
            Parser.parse_string(code, true, false, {line, column})
          end)

        env = Metadata.get_cursor_env(metadata, {line, column}, {context.begin, context.end})
        find(context, env, metadata)
    end
  end

  @doc false
  def find(context, %State.Env{module: module} = env, metadata) do
    # Get the binding environment as in the other providers.
    # binding_env = Binding.from_env(env, metadata, context.begin)

    case env.function do
      nil ->
        nil

      {fun, arity} ->
        # Get the behaviours (and possibly protocols) declared for the current module.
        behaviours = Metadata.get_module_behaviours(metadata, env, module)

        # For each behaviour, if the current function is a callback for it,
        # try to find the callback’s declaration.
        locations =
          for behaviour <- behaviours,
              Introspection.is_callback(behaviour, fun, arity, metadata),
              location = get_callback_location(behaviour, fun, arity, metadata),
              location != nil do
            location
          end

        case locations do
          [] -> nil
          [single] -> single
          multiple -> multiple
        end
    end
  end

  # Attempts to find the callback declaration in the behaviour (or protocol) module.
  # First it checks for a callback spec in the metadata; if none is found, it falls back
  # to trying to locate the source code.
  defp get_callback_location(behaviour, fun, arity, metadata) do
    case Enum.find(metadata.specs, fn
           {{^behaviour, ^fun, a}, _spec_info} ->
             Introspection.matches_arity?(a, arity)

           _ ->
             false
         end) do
      nil ->
        # Fallback: try to locate the function in the behaviour module’s source.
        Location.find_callback_source(behaviour, fun, arity)

      {{^behaviour, ^fun, _a}, spec_info} ->
        {{line, column}, {end_line, end_column}} = Location.info_to_range(spec_info)

        %Location{
          file: nil,
          type: :callback,
          line: line,
          column: column,
          end_line: end_line,
          end_column: end_column
        }
    end
  end
end
