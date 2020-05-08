defmodule Server.Session.Socket do
  @moduledoc """
  The network I/O part of a session
  """
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
  Instance representation
  """
  @type t :: pid

  ## Public API

  @doc """
  Start the socket
  Required arguments: [queue, name, socket]
  """
  def start_link(arg) do
    :gen_statem.start_link(__MODULE__, arg, [])
  end

  @doc """
  Send a packet to the client
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
    [
      :handle_event_function,   # states are arbitrary and not necessarily atoms
      :state_enter              # a callback will be invoked every time the state changes
    ]
  end

  # state_change callback
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

    packet |> send(self())
    setup_end() # sends an event to change states since we can't change state in the state_change callback
    {:keep_state, %{data | send_iv: send_iv, recv_iv: recv_iv}}
  end


  # cast callback
  # part two of setup, actually sets the state to :header
  @impl :gen_statem
  def handle_event(:cast, :end, :setup, data) do
    {:next_state, :header, data}
  end

  # state_change callback
  # checks if there's any leftover data in the buffer that needs processing
  @impl :gen_statem
  def handle_event(:enter, _old_state, state, data = %{size: size, buffer: buffer}) do
    buffer = if state != :queue do
      check_buffer(buffer, size)
    else
      buffer
    end
    {:keep_state, %{data | buffer: buffer}}
  end

  # cast callback
  # handles send packet events
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

  # info callback
  # handles incoming data from the raw socket
  @impl :gen_statem
  def handle_event(:info, {:tcp, socket, payload}, _state, data = %{size: size, buffer: buffer}) do
    buffer = buffer <> payload
    buffer = check_buffer(buffer, size)

    :inet.setopts(socket, active: :once)
    {:keep_state, %{data | buffer: buffer}}
  end

  # cast callback
  # parses packet header and awaits matching body
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

  # cast callback
  # processes packet body and sends it off for processing
  @impl :gen_statem
  def handle_event(:cast, {:process, packet}, :body, data = %{recv_iv: iv}) do
    Logger.debug("Processing body data")
    key = Application.fetch_env!(:server, :key)
    packet
    |> Server.Cipher.decrypt(iv, key)
    |> Server.Session.Queue.add(data.queue)
    {:next_state, :wait_queue, %{data | size: @header_size, recv_iv: iv |> Server.Cipher.next()} }
  end

  # info callback
  # awaits packet processing result
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

  # info callback
  # handles raw socket close event
  # usually indicates that the remote client closed the connection
  @impl :gen_statem
  def handle_event(:info, {:tcp_closed, _socket}, _state, _data) do
    Logger.info("Session closed")
    {:stop, :tcp_closed}
  end

  # generic catch-all
  @impl :gen_statem
  def handle_event(type, content, state, data) do
    Logger.warn("""
                unknown event/state:
                type: #{inspect type}
                content: #{inspect content}
                state: #{inspect state}
                data: #{inspect data}

                """)
    {:keep_state, data}
  end

  ## Private, helper functions ##

  # checks if the buffer has enough information to dispatch a process event
  defp check_buffer(buffer, size) do
    if byte_size(buffer) >= size do
      <<payload::binary-size(size), buffer::binary>> = buffer
      :gen_statem.cast(self(), {:process, payload})
      buffer
    else
      buffer
    end
  end

  # fires off the second part of the setup
  # this is needed because the first part
  # of the setup is a state_change handler
  # which doesn't allow us to change state
  defp setup_end do
    self() |> :gen_statem.cast(:end)
  end
end
