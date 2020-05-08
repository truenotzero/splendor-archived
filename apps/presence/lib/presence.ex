defmodule Presence do
  @moduledoc """
  The Presence core tracks the current affinity a player is connected to
  """

  @type player_id :: non_neg_integer
  @type world :: atom
  @type channel :: non_neg_integer
  @type t :: :lobby | :shop | {world, channel} | :unknown

  @doc """
  Update a player's presence
  """
  @spec update(player_id, t) :: :ok
  def update(player, new_presence) do
    player |> Presence.Store.set(new_presence)
  end

  @doc """
  Gets a player's presence

  Can be one of:
  * `:lobby` - for the Lobby affinity
  * `:shop` - for the Shop affinity
  * `{world, channel}` - for the Game affinity
  """
  @spec where(player_id) :: t
  def where(player) do
    player |> Presence.Store.get()
  end

  @doc """
  Checks if a player is present on any affinity
  """
  @spec present?(player_id) :: boolean
  def present?(player) do
    where(player) != :unknown
  end
end
