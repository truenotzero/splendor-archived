defmodule Server.Session.Socket do
  import Kernel, except: [send: 2]
  require Logger
  use Server.Named
  @behaviour :gen_statem

  @header_size 4
  defstruct name: nil,
            socket: nil,
            queue: nil,
            size: @header_size,
            buffer: <<>>,
            send_iv: <<>>,
            recv_iv: <<>>

  @typedoc """
  TOOD
  """
  @type t :: pid

  ## Public API

  def start_link(arg) do
    :gen_statem.start_link(__MODULE__, arg, [])
  end

  @doc """
  TODO
  """
  @spec send(binary, t) :: :ok
  def send(packet, socket) do
    :gen_statem.cast(socket, {:send, packet})
  end

  ## Callbacks ##

  @impl :gen_statem
  def init([queue, name, socket]) do
    {:ok, :setup, %__MODULE__{name: name, socket: socket, queue: queue}}
  end

  @impl :gen_statem
  def callback_mode do
    [:handle_event_function, :state_enter]
  end

  # old_state = new_state means that this state_enter handler handles
  # the initial state being entered
  @impl :gen_statem
  def handle_event(:enter, :setup, :setup, data) do
    Server.Session.Queue.link(data.queue)
    recv_iv = Server.Cipher.new()
    send_iv = Server.Cipher.new()

    packet = <<
      95, 0,
      1, 0, ?1>> <>
      recv_iv <>
      send_iv <>
      <<8>>

    # :ok = :gen_tcp.send(data.socket, packet)
    packet |> send(self())
    setup_end()
    {:keep_state, %{data | send_iv: send_iv, recv_iv: recv_iv}}
  end

  @impl :gen_statem
  def handle_event(:cast, :end, :setup, data) do
    {:next_state, :header, data}
  end

  @impl :gen_statem
  def handle_event(:enter, _old_state, state, data = %{size: size, buffer: buffer}) do
    buffer = if state != :queue do
      check_buffer(buffer, size)
    else
      buffer
    end
    {:keep_state, %{data | buffer: buffer}}
  end

  @impl :gen_statem
  def handle_event(:cast, {:send, packet}, state, %{send_iv: iv, socket: socket}) do
    version_major = Application.fetch_env!(:server, :version_major)
    packet_size = byte_size(packet)
    header = case state do
      :setup ->
        <<packet_size::little-16>>
       _other ->
        packet_size |> Server.Cipher.encode_header(iv, version_major)
    end

    target = header <> packet
    :ok = :gen_tcp.send(socket, target)
    Logger.debug("Sending: #{inspect target}")
    :keep_state_and_data
  end

  @impl :gen_statem
  def handle_event(:info, {:tcp, socket, payload}, _state, data = %{size: size, buffer: buffer}) do
    buffer = buffer <> payload
    buffer = check_buffer(buffer, size)

    :inet.setopts(socket, active: :once)
    {:keep_state, %{data | buffer: buffer}}
  end

  @impl :gen_statem
  def handle_event(:cast, {:process, payload}, :header, data) do
    Logger.debug("Processing header data")
    version_major = Application.fetch_env!(:server, :version_major)
    case payload |> Server.Cipher.decode_header(data.recv_iv, version_major) do
      {:ok, size} ->
        Logger.debug("Expecting body of #{size} bytes")
        {:next_state, :body, %{data | size: size}}
      {:error, reason} ->
        Logger.warn("Stopping with reason: #{reason}")
        {:stop, reason}
    end
  end

  @impl :gen_statem
  def handle_event(:cast, {:process, packet}, :body, data = %{recv_iv: iv}) do
    Logger.debug("Processing body data")
    key = Application.fetch_env!(:server, :key)
    packet
    |> Server.Cipher.decrypt(iv, key)
    |> Server.Session.Queue.add(data.queue)
    {:next_state, :wait_queue, %{data | size: @header_size, recv_iv: iv |> Server.Cipher.next()} }
  end

  @impl :gen_statem
  def handle_event(:info, {:queue, result}, :wait_queue, data) do
    case result do
      :ok ->
        {:next_state, :header, data}
      {:error, error} ->
        Logger.warn("Connection Queue error: #{error}")
        {:stop, error}
    end
  end

  @impl :gen_statem
  def handle_event(:info, {:tcp_closed, _socket}, _state, _data) do
    Logger.info("Session closed")
    {:stop, :tcp_closed}
  end

  @impl :gen_statem
  def handle_event(type, content, state, data) do
    Logger.warn("unknown event/state")
    IO.inspect(type, label: "type")
    IO.inspect(content, label: "content")
    IO.inspect(state, label: "state")
    IO.inspect(data, label: "data")

    {:keep_state, data}
  end

  ## Private, helper functions ##

  defp check_buffer(buffer, size) do
    if byte_size(buffer) >= size do
      <<payload::binary-size(size), buffer::binary>> = buffer
      :gen_statem.cast(self(), {:process, payload})
      buffer
    else
      buffer
    end
  end

  defp setup_end do
    self() |> :gen_statem.cast(:end)
  end
end
