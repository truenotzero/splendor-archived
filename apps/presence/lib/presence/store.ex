defmodule Presence.Store do
  @moduledoc """
  Persists the presence of connected users
  """

  use GenServer

  ## Public API

  def start_link do
    GenServer.start_link(__MODULE__, [], name: Presence.Store)
  end

  @doc """
  Get a player's presence from the store
  """
  @spec get(Presence.player_id) :: Presence.t
  def get(player) do
    GenServer.call(__MODULE__, {:get, player})
  end

  @doc """
  Update a player's presence in the store
  """
  @spec set(Presence.player_id, Presence.t) :: :ok
  def set(player, new_presence) do
    GenServer.cast(__MODULE__, {:set, player, new_presence})
  end

  ## Callbacks

  @impl GenServer
  def init(_) do
    :ets.new(__MODULE__, [])
  end

  @impl GenServer
  def handle_call({:get, player}, _from, state) do
    reply = case :ets.lookup(state, player) do
      [{^player, presence}] -> presence
      _ -> :unknown
    end
    {:reply, reply, state}
  end

  @impl GenServer
  def handle_cast({:set, player, new_presence}, state) do
    true = :ets.insert(state, {player, new_presence})
    {:noreply, state}
  end
end
