defmodule Server do
  use Application

  @impl true
  def start(_type, _args) do
    name = __MODULE__
    children = [
      {Registry, keys: :unique, name: name},
      {Server.JobDispatcher, name},
      {Server.Sessions, name},
      {Server.Acceptor, name},
    ]

    Supervisor.start_link(children, strategy: :rest_for_one)
  end
end
