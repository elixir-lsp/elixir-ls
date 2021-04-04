defmodule ElixirLS.LanguageServer.Providers.ExecuteCommand do
  @moduledoc """
  Adds a @spec annotation to the document when the user clicks on a code lens.
  """

  @callback execute([any], %ElixirLS.LanguageServer.Server{}) ::
              {:ok, any} | {:error, atom, String.t()}

  def execute(command, args, state) do
    handler =
      case command do
        "spec:" <> _ ->
          ElixirLS.LanguageServer.Providers.ExecuteCommand.ApplySpec

        "expandMacro:" <> _ ->
          ElixirLS.LanguageServer.Providers.ExecuteCommand.ExpandMacro

        "manipulatePipes:" <> _ ->
          ElixirLS.LanguageServer.Providers.ExecuteCommand.ManipulatePipes

        _ ->
          nil
      end

    if handler do
      handler.execute(args, state)
    else
      {:error, :invalid_request, nil}
    end
  end
end
