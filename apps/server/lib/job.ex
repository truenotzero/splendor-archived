defmodule Server.Job do
  use Task, restart: :temporary
end

defmodule Server.JobDispatcher do
  use Server.Named

  def start_link(name) do
    Task.Supervisor.start_link(name: via(name))
  end

  def child_spec(name) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [name]},
    }
  end

  def fire(packet, name) do
    name
    |> pid()
    |> Task.Supervisor.start_child(Server.Job, :run, packet, restart: :temporary)

    :ok
  end
end
