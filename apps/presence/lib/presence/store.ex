defmodule Presence.Store do
  use GenServer

  defmacro __using__(_) do
    quote do
      def child_spec(arg) do
        %{
          id: __MODULE__,
          start: {GenServer, :start_link, [unquote(__MODULE__), __MODULE__, [name: __MODULE__]]}
        }
      end

      @doc """
      Retrieve a value from the store
      """
      @spec get(key) :: value
      def get(k) do
        GenServer.call(__MODULE__, {:get, k})
      end

      @doc """
      Update a value in the store
      """
      @spec set(key, value) :: :ok
      def set(k, v) do
        GenServer.cast(__MODULE__, {:set, k, v})
      end
    end
  end

  ## Callbacks
  @impl GenServer
  def init(name) do
    {:ok, :ets.new(name, [])}
  end

  @impl GenServer
  def handle_call({:get, key}, _from, state) do
    reply = case :ets.lookup(state, key) do
      [{^key, val}] -> val
      _ -> :unknown
    end
    {:reply, reply, state}
  end

  @impl GenServer
  def handle_cast({:set, key, new_val}, state) do
    true = :ets.insert(state, {key, new_val})
    {:noreply, state}
  end
end

defmodule Presence.Player.Store do
  @type key :: Presence.player_id
  @type value :: Presence.t
  use Presence.Store
end

defmodule Presence.Migration.Store do
  @type key :: Presence.ip_address
  @type value :: Presence.t
  use Presence.Store
end
