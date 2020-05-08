defmodule PresenceTest do
  use ExUnit.Case
  doctest Presence

  test "greets the world" do
    assert Presence.hello() == :world
  end
end
