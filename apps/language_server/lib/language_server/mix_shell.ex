defmodule ElixirLS.LanguageServer.MixShell do
  @moduledoc """
  Some Mix tasks such as Hex will use the `yes?/1` function to
  prompt the user. This module turns those prompts into JSON RPC
  requests that will show a prompt in the IDE.
  """
  alias ElixirLS.LanguageServer.JsonRpc
  alias ElixirLS.Utils.WireProtocol

  @behaviour Mix.Shell

  defdelegate(print_app, to: Mix.Shell.IO)
  defdelegate(cmd(command, opts \\ []), to: Mix.Shell.IO)
  defdelegate(info(message), to: Mix.Shell.IO)
  defdelegate(error(message), to: Mix.Shell.IO)
  defdelegate(write(message), to: Mix.Shell.IO)

  def prompt(message) do
    if WireProtocol.io_intercepted?() do
      IO.puts(message)

      error(
        "[ElixirLS] Mix cannot prompt for command-line " <>
          "input in ElixirLS. Assuming blank response."
      )

      ""
    else
      Mix.Shell.IO.prompt(message)
    end
  end

  def yes?(message) do
    if WireProtocol.io_intercepted?() do
      response =
        JsonRpc.show_message_request(:info, message, [
          %{"title" => "No", "result" => false},
          %{"title" => "Yes", "result" => true}
        ])

      case response do
        {:ok, %{"result" => result}} -> result
        _ -> false
      end
    else
      Mix.Shell.IO.yes?(message)
    end
  end
end
