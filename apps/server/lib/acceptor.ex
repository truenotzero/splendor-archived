defmodule Server.Acceptor do
  require Logger
  use Task, restart: :permanent

  @spec start_link(atom) :: {:ok, pid}
  def start_link(name) do
    Task.start_link(__MODULE__, :init, [name])
  end

  @spec init(atom) :: no_return
  def init(name) do
    port = 8484
    options = [
      :binary,
      active: :once,
      reuseaddr: true,

    ]
    {:ok, listen_sock} = :gen_tcp.listen(port, options)
    accept(name, listen_sock)
  end

  @spec accept(atom, :gen_tcp.listenSocket) :: no_return
  def accept(name, listen_sock) do
    case :gen_tcp.accept(listen_sock) do
      {:ok, socket} ->
        Logger.info("Connection accepted")
        case Server.Sessions.start_child(name, socket) do
          {:ok, session} ->
            case :gen_tcp.controlling_process(socket, session) do
              :ok ->
                Logger.info("Session started successfully")
              {:error, error} ->
                Logger.info("Failed to start session: #{error}")
            end

          {:error, _reason} ->
            Logger.error("Failed to create session!")
          end
      {:error, reason} -> Logger.warn("Failed to open connection: #{reason}")
    end

    accept(name, listen_sock)
  end
end
