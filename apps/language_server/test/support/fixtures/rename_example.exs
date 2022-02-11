defmodule Example.Pipeline do
  use Broadway

  alias Broadway.Message

  def start_link(_) do
    {module, opts} = Application.get_env(:broadway_sqs, :producer_module)

    Broadway.start_link(__MODULE__,
      name: __MODULE__,
      producer: [
        module: {module, opts}
      ],
      processors: [
        default: []
      ],
      batchers: [
        default: [
          batch_size: 10,
          batch_timeout: 2000
        ]
      ]
    )
  end

  def handle_message(_, %Message{data: data} = message, _) do
    info
    |> create_message
    |> handle_error

    message
  end

  def handle_batch(_, messages, _, _) do
    messages
  end

  defp handle_error({:ok, message}), do: message

  defp handle_error({:error, changeset}) do
    raise Example.SqsPipelineException, message: changeset.errors
  end

  defp create_message(data) do
    data
    |> Jason.decode(save_message)
    |> prepare_params
    |> save_message
  end

  defp save_message({:ok, params}) do
    %Collector.Message{}
    |> Collector.Message.changeset(params)
    |> Collector.Repo.insert()
  end

  defp prepare_params({:ok, %{"action" => _, "payload" => _}} = params),
    do: params

  defp prepare_params(_) do
    raise Example.PipelineException, message: "Message does not contain all necessary keys."
  end
end

defmodule Example.PipelineException do
  defexception [:message]
end