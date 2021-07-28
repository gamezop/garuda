defmodule Garuda.Utils.PrivateMethods do
  @moduledoc """
  Some copies of private funtions that are very hard to test with normal flow
  """
  defstruct(
    name: "state_to_string",
    type: "function"
  )

  def t_state_to_string(statemap) when is_struct(statemap) do
    Map.from_struct(statemap)
    |> Jason.encode(pretty: true)
    |> process_encoding()
  end

  def t_state_to_string(statemap) do
    Jason.encode(statemap, pretty: true)
    |> process_encoding()
  end

  defp process_encoding({:ok, state_string}), do: state_string
  defp process_encoding(_error), do: "Encoding Error, use supported state types"
end
