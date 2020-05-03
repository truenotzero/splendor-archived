defmodule Server.Session.Queue do
  require Logger
  use GenServer, restart: :temporary
  use Server.Named

  @ticks_per_second Application.compile_env!(:server, :tickrate)
  @max_queue_size @ticks_per_second * 2

  defstruct queue: :queue.new(), size: 0, timer: nil, name: nil

  ## Public API

  def start(name) do
    GenServer.start_link(__MODULE__, name)
  end

  def add(item, queue) do
    Logger.debug("Adding to queue: #{inspect item}")
    GenServer.cast(queue, {:add, item, self()})
  end

  def link(pid \\ self(), queue) do
    GenServer.cast(queue, {:link, pid})
  end

  ## Callbacks

  @impl GenServer
  def init(name) do
    {:ok, timer} = :timer.send_after(1000 |> div(@ticks_per_second), :dispatch)
    {:ok, %__MODULE__{timer: timer, name: name}}
  end

  @impl GenServer
  def handle_cast({:add, item, sender}, state = %{size: size, queue: queue}) do
    if size == @max_queue_size do
      sender |> send({:queue, {:error, :queue_full}})
      {:stop, :queue_full, state}
    else
      sender |> send({:queue, :ok})
      queue = item |> :queue.in(queue)
      {:noreply, %{state | queue: queue, size: size + 1}}
    end
  end

  @impl GenServer
  def handle_cast({:link, pid}, state) do
    Process.link(pid)
    {:noreply, state}
  end

  @impl GenServer
  def handle_info(:dispatch, state = %{size: size, queue: queue}) do
    {queue, size} = case queue |> :queue.out() do
      {{:value, item}, queue} ->
        dispatch(item, state.name)
        {queue, size - 1}
      {:empty, queue} ->
        {queue, size}
    end
    {:noreply, %{state | queue: queue, size: size}}
  end

  ## Private, helper functions

  defp dispatch(item, name) do
    :ok = item
    |> IO.inspect(label: "dispatch")
    |> Server.JobDispatcher.fire(name)
  end
end
