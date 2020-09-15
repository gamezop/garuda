defmodule Garuda.Monitor.DashboardData do
  @moduledoc """
    An interface to retrtive data btw RoomDb and Monitor dashboard
  """
  alias Garuda.RoomManager.Records

  def get_room_state(game_room_id) do
    case Records.is_process_registered(game_room_id) do
      [] -> %{}
      _ -> :sys.get_state(Records.via_tuple(game_room_id))
    end
  end
end
