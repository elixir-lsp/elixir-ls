defmodule ElixirLS.LanguageServer.Providers.LocatorUtils do
  @moduledoc """
  Helper for providers resolving symbols at a given cursor position.
  """

  alias ElixirSense.Core.{Binding, Metadata, Parser, SurroundContext}
  alias ElixirSense.Core.Normalized.Code, as: NormalizedCode

  @type t :: %{
          context: map(),
          env: Metadata.t(),
          metadata: Metadata.t(),
          binding_env: any(),
          type: any()
        }

  @spec build(String.t(), pos_integer, pos_integer, keyword()) :: t | nil
  def build(code, line, column, options \\ []) do
    case NormalizedCode.Fragment.surround_context(code, {line, column}) do
      :none ->
        nil

      context ->
        metadata =
          Keyword.get_lazy(options, :metadata, fn ->
            Parser.parse_string(code, true, false, {line, column})
          end)

        env = Metadata.get_cursor_env(metadata, {line, column}, {context.begin, context.end})

        %{
          context: context,
          env: env,
          metadata: metadata,
          binding_env: Binding.from_env(env, metadata, context.begin),
          type: SurroundContext.to_binding(context.context, env.module)
        }
    end
  end
end
