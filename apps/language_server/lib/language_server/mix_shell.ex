defmodule ElixirLS.LanguageServer.MixShell do
  @moduledoc """
  Some Mix tasks such as Hex will use the `yes?/1` function to
  prompt the user. This module turns those prompts into JSON RPC
  requests that will show a prompt in the IDE.
  """
  alias ElixirLS.LanguageServer.JsonRpc
  alias ElixirLS.Utils.WireProtocol

  @behaviour Mix.Shell

  @impl Mix.Shell
  defdelegate print_app, to: Mix.Shell.IO

  @impl Mix.Shell
  defdelegate cmd(command, opts \\ []), to: Mix.Shell.IO

  @impl Mix.Shell
  defdelegate info(message), to: Mix.Shell.IO

  @impl Mix.Shell
  defdelegate error(message), to: Mix.Shell.IO

  @impl Mix.Shell
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

  @impl Mix.Shell
  def yes?(message, options \\ []) do
    if WireProtocol.io_intercepted?() do
      response =
        JsonRpc.show_message_request(:info, message, [
          %{"title" => "No", "result" => false},
          %{"title" => "Yes", "result" => true}
        ])

      case response do
        {:ok, %{"result" => result}} ->
          result

        other ->
          error("[ElixirLS] unexpected client response #{inspect(other)}, assuming yes")
          true
      end
    else
      # TODO convert to to normal call when we require elixir 1.13
      if Version.match?(System.version(), "< 1.13.0-rc.0") do
        apply(Mix.Shell.IO, :yes?, [message])
      else
        apply(Mix.Shell.IO, :yes?, [message, options])
      end
    end
  end
end
