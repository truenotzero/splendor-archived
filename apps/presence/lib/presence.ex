defmodule Presence do
  @moduledoc """
  The Presence core tracks clients' locations
  """

  @type ip_address :: :inet.ip4_address()
  @type player_id :: non_neg_integer
  @type world :: atom
  @type channel :: non_neg_integer
  @type t :: :lobby | :shop | {world, channel} | :unknown
end
defmodule Presence.Migration do
  @moduledoc """
  Presence.Migration tracks movement across affinities
  """

  @spec migrate(Presence.ip_address, Presence.t) :: :ok
  def migrate(ip, to) do
    ip |> __MODULE__.Store.set(to)
  end

  @doc """
  Gets an IP's migration destination, if it exists
  """
  @spec destination(Presence.ip_address) :: Presence.t
  def destination(ip) do
    ip |> __MODULE__.Store.get()
  end

  @doc """
  Checks if the requested IP is migrating

  Can be one of:
  * `:lobby` - for the Lobby affinity
  * `:shop` - for the Shop affinity
  * `{world, channel}` - for the Game affinity
  * `:unknown` - IP not migrating
  """
  @spec migrating?(Presence.ip_address()) :: boolean
  def migrating?(ip) do
    destination(ip) != :unknown
  end
end

defmodule Presence.Player do
  @moduledoc """
  Presence.Player tracks players
  """

  @doc """
  Update a player's presence
  """
  @spec update(Presence.player_id, Presence.t) :: :ok
  def update(player, new_presence) do
    player |> __MODULE__.Store.set(new_presence)
  end

  @doc """
  Gets a player's presence

  Can be one of:
  * `:lobby` - for the Lobby affinity
  * `:shop` - for the Shop affinity
  * `{world, channel}` - for the Game affinity
  * `:unknown` - player not present
  """
  @spec where(Presence.player_id) :: Presence.t
  def where(player) do
    player |> __MODULE__.Store.get()
  end

  @doc """
  Checks if a player is present on any affinity
  """
  @spec present?(Presence.player_id) :: boolean
  def present?(player) do
    where(player) != :unknown
  end
end
