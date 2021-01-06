defmodule Garuda.Monitor.DashboardData do
  @moduledoc """
    An interface to retrtive data btw RoomDb and Monitor dashboard
  """
  alias Garuda.RoomManager.Records

  def get_room_state(room_id) do
    case Records.is_process_registered(room_id) do
      false -> %{}
      true -> :sys.get_state(Records.via_tuple(room_id))
    end
  end
end
