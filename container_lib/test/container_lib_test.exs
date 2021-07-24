defmodule ContainerLibTest do
  use ExUnit.Case
  doctest ContainerLib

  test "greets the world" do
    assert ContainerLib.hello() == :world
  end
end
