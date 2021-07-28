defmodule GarudaTest.TestFunctionsTest do
  @moduledoc false
  alias Garuda.Utils.PrivateMethods
  use ExUnit.Case

  @test_map %{
    name: "state_to_string",
    type: "function"
  }

  test "testing normal map state" do
    state = PrivateMethods.t_state_to_string(@test_map)
    assert is_binary(state)
  end

  test "testing struct state" do
    struct_state = PrivateMethods.__struct__()
    state = PrivateMethods.t_state_to_string(struct_state)
    assert is_binary(state)
  end

  test "testing non-supported state types" do
    struct_state = {:a, [1, 2, 3]}
    state = PrivateMethods.t_state_to_string(struct_state)
    assert is_binary(state)
  end
end
