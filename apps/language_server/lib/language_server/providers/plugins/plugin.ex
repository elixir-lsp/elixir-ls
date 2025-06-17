defmodule ElixirLS.LanguageServer.Plugin do
  alias ElixirSense.Core.Metadata
  alias ElixirSense.Core.State
  @type suggestion :: ElixirLS.LanguageServer.Providers.Completion.Suggestion.generic()

  @type context :: term
  @type acc :: %{context: context(), result: list(suggestion())}
  @type cursor_context :: %{
          text_before: String.t(),
          text_after: String.t(),
          at_module_body?: boolean
        }

  @callback reduce(
              hint :: String,
              env :: State.Env.t(),
              buffer_metadata :: Metadata.t(),
              cursor_context,
              acc
            ) :: {:cont, acc} | {:halt, acc}

  @callback setup(context()) :: context()

  @callback decorate(suggestion) :: suggestion

  @optional_callbacks decorate: 1, reduce: 5, setup: 1
end
