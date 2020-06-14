defmodule AvatarTest do
  use ExUnit.Case
  doctest Avatar

  test "greets the world" do
    assert Avatar.hello() == :world
  end
end
