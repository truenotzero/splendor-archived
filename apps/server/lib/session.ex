defmodule Server.Session do
  def new(args = [name, _]) do
    case Server.Session.Queue.start(name) do
      {:ok, queue} ->
        Server.Session.Socket.start_link([queue | args])
      default -> default
    end
  end

  def child_spec(arg) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :new, [arg]},
      restart: :temporary,
    }
  end
end

defmodule Server.Sessions do
  use DynamicSupervisor
  use Server.Named, simple: true

  @moduledoc """
  The pool of all client connections
  """

  def start_link(name) do
    DynamicSupervisor.start_link(__MODULE__, [], name: via(name))
  end

  def start_child(name, socket) do
    DynamicSupervisor.start_child(via(name), {Server.Session, [name, socket]})
  end

  @impl DynamicSupervisor
  def init(_) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
