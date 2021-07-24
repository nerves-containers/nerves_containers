defmodule ContainerManagerTest do
  use ExUnit.Case
  doctest ContainerManager

  test "greets the world" do
    assert ContainerManager.hello() == :world
  end
end
