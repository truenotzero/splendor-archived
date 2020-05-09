defmodule Presence.Application do
  use Application

  def start(_type, _args) do
    children = [
      Presence.Migration.Store,
      Presence.Player.Store,
    ]

    opts = [strategy: :one_for_one, name: Presence.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
