defmodule Bootstrap do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      {Server, :login}
    ]

    opts = [strategy: :one_for_one, name: Bootstrap.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
