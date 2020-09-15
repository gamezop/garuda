defmodule GarudaTest do
  use ExUnit.Case
  doctest Garuda

  test "greets the world" do
    assert Garuda.hello() == :world
  end
end
