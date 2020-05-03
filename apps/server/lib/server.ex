defmodule Server do
  use Supervisor
  def start_link(name) do
    Supervisor.start_link(__MODULE__, name)
  end

  @impl true
  def init(name) do
    children = [
      {Registry, keys: :unique, name: name},
      {Server.JobDispatcher, name},
      {Server.Sessions, name},
      {Server.Acceptor, name},
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
