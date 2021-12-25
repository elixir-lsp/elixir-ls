defmodule ElixirLS.LanguageServer.Providers.ExecuteCommand do
  @moduledoc """
  Adds a @spec annotation to the document when the user clicks on a code lens.
  """

  alias ElixirLS.LanguageServer.Providers.ExecuteCommand, as: C

  @handlers %{
    "spec" => C.ApplySpec,
    "expandMacro" => C.ExpandMacro,
    "manipulatePipes" => C.ManipulatePipes,
    "restart" => C.Restart
  }

  @callback execute([any], %ElixirLS.LanguageServer.Server{}) ::
              {:ok, any} | {:error, atom, String.t()}

  def execute(command_with_server_id, args, state) do
    with [command, _server_id] <- String.split(command_with_server_id, ":"),
         handler when not is_nil(handler) <- Map.get(@handlers, command) do
      handler.execute(args, state)
    else
      _ ->
        {:error, :invalid_request, nil}
    end
  end

  def get_commands(server_instance_id) do
    for {k, _v} <- @handlers do
      "#{k}:#{server_instance_id}"
    end
  end
end
