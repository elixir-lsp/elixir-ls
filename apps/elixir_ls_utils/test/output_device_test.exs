defmodule ElixirLS.Utils.OutputDeviceTest do
  use ExUnit.Case, async: false

  alias ElixirLS.Utils.OutputDevice

  defmodule FakeOutput do
    use GenServer

    def start_link(args) do
      GenServer.start_link(__MODULE__, args, name: __MODULE__)
    end

    def set_responses(responses) do
      GenServer.call(__MODULE__, {:set_responses, responses})
    end

    def get_requests() do
      GenServer.call(__MODULE__, :get_requests)
    end

    @impl GenServer
    def init(_) do
      {:ok, {[], []}}
    end

    @impl GenServer
    def handle_call({:set_responses, responses}, _from, _state) do
      {:reply, :ok, {[], responses}}
    end

    def handle_call(:get_requests, _from, state = {requests, _}) do
      {:reply, requests |> Enum.reverse(), state}
    end

    @impl GenServer
    def handle_info({:io_request, from, reply_as, req}, {requests, [resp | responses]}) do
      send(from, {:io_reply, reply_as, resp})
      {:noreply, {[req | requests], responses}}
    end
  end

  defmodule FakeWireProtocol do
    use GenServer

    def start_link(args) do
      GenServer.start_link(__MODULE__, args, name: __MODULE__)
    end

    def send(msg) do
      GenServer.call(__MODULE__, {:send, msg})
    end

    def get() do
      GenServer.call(__MODULE__, :get)
    end

    @impl GenServer
    def init(_), do: {:ok, []}

    @impl GenServer
    def handle_call({:send, msg}, _from, state) do
      {:reply, :ok, [msg | state]}
    end

    def handle_call(:get, _from, state) do
      {:reply, state |> Enum.reverse(), state}
    end
  end

  setup do
    fake_user = start_supervised!({FakeOutput, []})
    fake_wire_protocol = start_supervised!({FakeWireProtocol, []})

    output_device =
      start_supervised!({OutputDevice, [fake_user, &FakeWireProtocol.send/1]}, id: :output_device)

    output_device_error =
      start_supervised!({OutputDevice, [fake_user, fn _ -> {:error, :emfile} end]},
        id: :output_device_error
      )

    {:ok,
     %{
       output_device: output_device,
       output_device_error: output_device_error,
       fake_wire_protocol: fake_wire_protocol,
       fake_user: fake_user
     }}
  end

  test "passes optional io_request to underlying device", %{
    output_device: output_device
  } do
    FakeOutput.set_responses([{:ok, 77}, {:error, :enotsup}, :ok])

    send(output_device, {:io_request, self(), 123, {:get_geometry, :rows}})
    assert_receive({:io_reply, 123, {:ok, 77}})

    send(output_device, {:io_request, self(), 123, {:get_geometry, :columns}})
    assert_receive({:io_reply, 123, {:error, :enotsup}})

    send(output_device, {:io_request, self(), 123, :some_unknown})
    assert_receive({:io_reply, 123, :ok})

    assert FakeOutput.get_requests() == [
             {:get_geometry, :rows},
             {:get_geometry, :columns},
             :some_unknown
           ]
  end

  describe "handles multi requests" do
    test "all passed, all succeed, last response returned naked `:ok`", %{
      output_device: output_device
    } do
      FakeOutput.set_responses([:ok, {:ok, ""}, :eof, :ok])

      requests = [
        :some,
        :other1,
        :other2,
        :another
      ]

      send(output_device, {:io_request, self(), 123, {:requests, requests}})
      assert_receive({:io_reply, 123, :ok})

      assert FakeOutput.get_requests() == [:some, :other1, :other2, :another]
    end

    test "all passed, all succeed, last response returned wrapped", %{
      output_device: output_device
    } do
      FakeOutput.set_responses([:ok, [:abc]])

      requests = [
        {:other, [:abc]},
        :some
      ]

      send(output_device, {:io_request, self(), 123, {:requests, requests}})
      assert_receive({:io_reply, 123, {:ok, [:abc]}})

      assert FakeOutput.get_requests() == [{:other, [:abc]}, :some]
    end

    test "all passed, error breaks processing, last response returned", %{
      output_device: output_device
    } do
      FakeOutput.set_responses([{:error, :notsup}])

      requests = [
        {:get_geometry, :rows},
        :getopts
      ]

      send(output_device, {:io_request, self(), 123, {:requests, requests}})
      assert_receive({:io_reply, 123, {:error, :notsup}})

      assert FakeOutput.get_requests() == [{:get_geometry, :rows}]
    end
  end

  def get_chars_list("abc"), do: 'some'
  def get_chars_binary("abc"), do: "some"
  def get_chars_invalid("abc"), do: :some
  def get_chars_raise("abc"), do: raise(ArgumentError)
  def get_chars_throw("abc"), do: throw(:foo)

  describe "put_chars mfa" do
    test "mfa list", %{
      output_device: output_device
    } do
      request = {:put_chars, :unicode, __MODULE__, :get_chars_list, ["abc"]}
      send(output_device, {:io_request, self(), 123, request})
      assert_receive({:io_reply, 123, :ok})

      assert FakeWireProtocol.get() == ["some"]
    end

    test "mfa binary", %{
      output_device: output_device
    } do
      request = {:put_chars, :unicode, __MODULE__, :get_chars_binary, ["abc"]}
      send(output_device, {:io_request, self(), 123, request})
      assert_receive({:io_reply, 123, :ok})

      assert FakeWireProtocol.get() == ["some"]
    end

    test "mfa invalid result", %{
      output_device: output_device
    } do
      request = {:put_chars, :unicode, __MODULE__, :get_chars_invalid, ["abc"]}
      send(output_device, {:io_request, self(), 123, request})
      assert_receive({:io_reply, 123, {:error, :put_chars}})

      assert FakeWireProtocol.get() == []
    end

    test "mfa throw", %{
      output_device: output_device
    } do
      request = {:put_chars, :unicode, __MODULE__, :get_chars_throw, ["abc"]}
      send(output_device, {:io_request, self(), 123, request})
      assert_receive({:io_reply, 123, {:error, :put_chars}})

      assert FakeWireProtocol.get() == []
    end

    test "mfa raise", %{
      output_device: output_device
    } do
      request = {:put_chars, :unicode, __MODULE__, :get_chars_raise, ["abc"]}
      send(output_device, {:io_request, self(), 123, request})
      assert_receive({:io_reply, 123, {:error, :put_chars}})

      assert FakeWireProtocol.get() == []
    end
  end

  describe "put_chars" do
    test "returns error from output function", %{
      output_device_error: output_device
    } do
      request = {:put_chars, :unicode, "sąme👨‍👩‍👦"}
      send(output_device, {:io_request, self(), 123, request})
      assert_receive({:io_reply, 123, {:error, :emfile}})
    end

    test "unicode binary", %{
      output_device: output_device
    } do
      request = {:put_chars, :unicode, "sąme👨‍👩‍👦"}
      send(output_device, {:io_request, self(), 123, request})
      assert_receive({:io_reply, 123, :ok})

      assert FakeWireProtocol.get() == ["sąme👨‍👩‍👦"]
    end

    test "unicode list", %{
      output_device: output_device
    } do
      request = {:put_chars, :unicode, 'sąme👨‍👩‍👦'}
      send(output_device, {:io_request, self(), 123, request})
      assert_receive({:io_reply, 123, :ok})

      assert FakeWireProtocol.get() == ["sąme👨‍👩‍👦"]
    end

    test "latin1 binary", %{
      output_device: output_device
    } do
      request = {:put_chars, :latin1, "some"}
      send(output_device, {:io_request, self(), 123, request})
      assert_receive({:io_reply, 123, :ok})

      assert FakeWireProtocol.get() == ["some"]
    end

    test "latin1 list", %{
      output_device: output_device
    } do
      request = {:put_chars, :latin1, 'some'}
      send(output_device, {:io_request, self(), 123, request})
      assert_receive({:io_reply, 123, :ok})

      assert FakeWireProtocol.get() == ["some"]
    end

    test "latin1 list with chars > 255", %{
      output_device: output_device
    } do
      request = {:put_chars, :latin1, 'sąme👨‍👩‍👦'}
      send(output_device, {:io_request, self(), 123, request})
      assert_receive({:io_reply, 123, {:error, :put_chars}})

      assert FakeWireProtocol.get() == []
    end
  end

  describe "opts" do
    test "returns", %{
      output_device: output_device
    } do
      send(output_device, {:io_request, self(), 123, :getopts})
      assert_receive({:io_reply, 123, [binary: true, encoding: :unicode]})
    end

    test "valid can be set", %{
      output_device: output_device
    } do
      send(
        output_device,
        {:io_request, self(), 123, {:setopts, [:binary, {:encoding, :unicode}]}}
      )

      assert_receive({:io_reply, 123, :ok})

      send(
        output_device,
        {:io_request, self(), 123, {:setopts, [{:encoding, :unicode}, {:binary, true}]}}
      )

      assert_receive({:io_reply, 123, :ok})
    end

    test "rejects invalid", %{
      output_device: output_device
    } do
      send(output_device, {:io_request, self(), 123, {:setopts, [:list, {:encoding, :unicode}]}})
      assert_receive({:io_reply, 123, {:error, :enotsup}})

      send(
        output_device,
        {:io_request, self(), 123, {:setopts, [{:encoding, :latin1}, {:binary, true}]}}
      )

      assert_receive({:io_reply, 123, {:error, :enotsup}})

      send(
        output_device,
        {:io_request, self(), 123, {:setopts, [:binary, {:encoding, :unicode}, {:some, :value}]}}
      )

      assert_receive({:io_reply, 123, {:error, :enotsup}})

      send(output_device, {:io_request, self(), 123, {:setopts, [:binary]}})
      assert_receive({:io_reply, 123, {:error, :enotsup}})

      send(output_device, {:io_request, self(), 123, {:setopts, [{:encoding, :unicode}]}})
      assert_receive({:io_reply, 123, {:error, :enotsup}})
    end
  end
end
