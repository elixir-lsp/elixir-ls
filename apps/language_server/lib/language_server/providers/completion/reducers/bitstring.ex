defmodule ElixirLS.LanguageServer.Providers.Completion.Reducers.Bitstring do
  @moduledoc false

  alias ElixirSense.Core.Bitstring
  alias ElixirSense.Core.Source

  @type bitstring_option :: %{
          type: :bitstring_option,
          name: String.t()
        }

  @doc """
  A reducer that adds suggestions of bitstring options.
  """
  def add_bitstring_options(_hint, _env, _buffer_metadata, cursor_context, acc) do
    prefix = cursor_context.text_before

    case Source.bitstring_options(prefix) do
      candidate when not is_nil(candidate) ->
        parsed = Bitstring.parse(candidate)

        list =
          for option <- Bitstring.available_options(parsed),
              candidate_part = candidate |> String.split("-") |> List.last(),
              option_str = option |> Atom.to_string(),
              String.starts_with?(option_str, candidate_part) do
            %{
              name: option_str,
              type: :bitstring_option
            }
          end

        {:cont, %{acc | result: acc.result ++ list}}

      _ ->
        {:cont, acc}
    end
  end
end
