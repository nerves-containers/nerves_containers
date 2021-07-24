defmodule NervesContainersTest do
  use ExUnit.Case
  doctest NervesContainers

  test "greets the world" do
    assert NervesContainers.hello() == :world
  end
end
