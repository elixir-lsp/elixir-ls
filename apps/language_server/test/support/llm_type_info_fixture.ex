defmodule ElixirLS.Test.LlmTypeInfoFixture do
  @moduledoc """
  Test fixture module with types, specs, and callbacks for testing LlmTypeInfo.
  """

  # Define a behaviour with callbacks
  defmodule TestBehaviour do
    @moduledoc """
    A test behaviour with documented callbacks.
    """

    @doc """
    Initialize the server state.
    
    This callback is called when the server starts.
    """
    @callback init(args :: term()) :: {:ok, state :: term()} | {:error, reason :: term()}

    @doc """
    Handle a synchronous call.
    """
    @callback handle_call(request :: term(), from :: GenServer.from(), state :: term()) ::
                {:reply, reply :: term(), new_state :: term()}
                | {:reply, reply :: term(), new_state :: term(), timeout() | :hibernate}
                | {:noreply, new_state :: term()}
                | {:noreply, new_state :: term(), timeout() | :hibernate}
                | {:stop, reason :: term(), reply :: term(), new_state :: term()}
                | {:stop, reason :: term(), new_state :: term()}

    @doc false
    @callback handle_cast(request :: term(), state :: term()) ::
                {:noreply, new_state :: term()}
                | {:noreply, new_state :: term(), timeout() | :hibernate}
                | {:stop, reason :: term(), new_state :: term()}

    @optional_callbacks handle_cast: 2
  end

  # Module that implements the behaviour
  defmodule Implementation do
    @moduledoc """
    Module with types, specs, and behaviour implementation.
    """

    @behaviour TestBehaviour

    @typedoc """
    A user struct with name and age.
    """
    @type user :: %{
            name: String.t(),
            age: non_neg_integer()
          }

    @typedoc """
    Status of a process.
    """
    @type status :: :active | :inactive | :pending

    @typedoc false
    @type private_type :: atom()

    @opaque token :: binary()

    @doc """
    Creates a new user with the given name and age.
    
    ## Examples
    
        iex> create_user("Alice", 30)
        %{name: "Alice", age: 30}
    """
    @spec create_user(String.t(), non_neg_integer()) :: user()
    def create_user(name, age) when is_binary(name) and is_integer(age) and age >= 0 do
      %{name: name, age: age}
    end

    @doc """
    Gets the status of a user.
    """
    @spec get_status(user()) :: status()
    def get_status(%{age: age}) when age < 18, do: :pending
    def get_status(%{age: age}) when age >= 65, do: :inactive
    def get_status(_), do: :active

    @doc false
    @spec private_fun(atom()) :: atom()
    def private_fun(atom), do: atom

    # Function without spec - for dialyzer contract testing
    def unspecced_fun(x) when is_integer(x) do
      x + 1
    end

    def unspecced_fun(x) when is_binary(x) do
      String.length(x)
    end

    # Behaviour callbacks implementation
    @impl true
    def init(args), do: {:ok, args}

    @impl true
    def handle_call(:get_state, _from, state), do: {:reply, state, state}
    def handle_call({:set_state, new_state}, _from, _state), do: {:reply, :ok, new_state}

    @impl true
    def handle_cast({:update, data}, state), do: {:noreply, Map.merge(state, data)}
  end

  # Simple module with just functions and specs
  defmodule SimpleModule do
    @moduledoc false

    @spec add(number(), number()) :: number()
    def add(a, b), do: a + b

    @spec multiply(number(), number()) :: number()
    def multiply(a, b), do: a * b

    # Function that will get dialyzer contract
    def identity(x), do: x
  end
end