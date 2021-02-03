defmodule Garuda.RoomManager.RoomDb do
  @moduledoc """
  Stores the info of all the game-rooms and functions to manage those data.

  Orwell uses data from RoomDb, for rendering the live interactive dashboard
  """
  alias Garuda.MatchMaker.Matcher
  alias Garuda.RoomManager.Records
  use GenServer

  @room_db_name :room_db
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @spec save_init_room_state(pid(), map()) :: any()
  @doc """
  Saves the specific game-room info with its pid as key

    * `room_pid` - pid of the particular game-room
    * `info` - A map of game-room info
  """
  def save_init_room_state(room_pid, info) do
    GenServer.call(__MODULE__, {"save_room", {room_pid, info}})
  end

  @doc """
  Adds a new player details to the room. (Expecting room is already created)
    * `room_pid` - pid of the game-room
    * `opts` - A keyword-list of player-info
  """
  @spec on_room_join(pid(), Keyword.t()) :: String.t()
  def on_room_join(room_pid, opts) do
    GenServer.call(__MODULE__, {"room_join", room_pid, opts})
  end

  @doc """
  Updates a game-room's info.

  Use cases are usually to update the live info regarding the no:of
  players in a game-room.
  """
  @spec update_room_state(pid(), map()) :: :ok
  def update_room_state(room_pid, update_info) do
    GenServer.cast(__MODULE__, {:update_room, room_pid, update_info})
  end

  @doc """
  Returns the game-channel name associated with the game-room's pid.
    * pid - game-room pid.
  This function is mostly used by game-rooms to get the game-channel name, so
  that they can send messages to the channel.
  corresponding game-channels.
  """
  @spec get_channel_name(pid()) :: String.t()
  def get_channel_name(pid) do
    GenServer.call(__MODULE__, {"get_channel_name", pid})
  end

  @spec delete_room(pid()) :: any()
  @doc """
  Deletes a game-room info with a pid.
  """
  def delete_room(room_pid) do
    GenServer.call(__MODULE__, {"delete_room", room_pid})
  end

  @doc """
  Saves the game-channel info with its pid as key.

  As of now this is mainly used for getting the actual no:of connections on the server.
  """
  @spec on_channel_connection(pid(), map()) :: any()
  def on_channel_connection(channel_pid, info) do
    GenServer.call(__MODULE__, {"channel_join", {channel_pid, info}})
  end

  @spec on_channel_terminate(pid()) :: any()
  @doc """
  Deletes a game-channel's info with give channel pid
  """
  def on_channel_terminate(channel_pid) do
    GenServer.call(__MODULE__, {"channel_leave", channel_pid})
  end

  @spec get_stats :: map()
  @doc """
    Returns overall game server info, required for Monitoring
  """
  def get_stats do
    GenServer.call(__MODULE__, "get_stats")
  end

  @spec get_room_state(String.t()) :: map()
  @doc """
  Returns the state of a given `room_id`

    * `room_id` - Unique combination of room_name + ":" + room_id., ex ("tictactoe:ACFBEBW")
  """
  def get_room_state(room_id) do
    GenServer.call(__MODULE__, {"get_room_state", room_id})
  end

  @doc """
  Removes the player from RoomDb.
    * room_pid - pid of the game-room
    * player_id - unique_id of player
  """
  @spec on_player_leave(pid(), String.t()) :: any()
  def on_player_leave(room_pid, player_id) do
    GenServer.call(__MODULE__, {"room_left", room_pid, player_id})
  end

  @doc """
  Updates player_id key in the room with reconnection_timer ref
  """
  @spec update_timer_ref(pid(), String.t(), any()) :: any
  def update_timer_ref(room_pid, player_id, ref) do
    GenServer.call(__MODULE__, {"update_timer_ref", room_pid, player_id, ref})
  end

  @doc """
  Returns player_id key in the room with reconnection_timer ref
  """
  @spec get_timer_ref(pid(), String.t()) :: any
  def get_timer_ref(room_pid, player_id) do
    GenServer.call(__MODULE__, {"get_timer_ref", room_pid, player_id})
  end

  @doc """
  Returns rejoin status of player in the room
  """
  @spec has_rejoined(pid(), String.t()) :: any
  def has_rejoined(room_pid, player_id) do
    GenServer.call(__MODULE__, {"has_rejoined", room_pid, player_id})
  end

  @impl true
  def init(_opts) do
    {:ok, %{}}
  end

  @impl true
  def handle_call({"delete_room", room_pid}, _from, state) do
    [{_room_name, details} | _t] = :ets.lookup(@room_db_name, room_pid)
    room_name = details["room_name"]
    match_id = details["match_id"]
    room_id = "#{room_name}:#{match_id}"
    Matcher.delete_room(room_id)
    :ets.delete(@room_db_name, room_pid)
    {:reply, "ok", state}
  end

  @impl true
  def handle_call({"save_room", {room_pid, info}}, _from, state) do
    :ets.insert(@room_db_name, {room_pid, info})
    {:reply, "ok", state}
  end

  @impl true
  def handle_call({"channel_leave", channel_pid}, _from, state) do
    [{_key, details} | _t] = :ets.lookup(@room_db_name, "channels")
    {popped_val, details} = pop_in(details[channel_pid])
    :ets.insert(@room_db_name, {"channels", details})
    {:reply, popped_val, state}
  end

  @impl true
  def handle_call({"channel_join", {channel_pid, _info}}, _from, state) do
    [{_key, details} | _t] = :ets.lookup(@room_db_name, "channels")
    details = put_in(details[channel_pid], %{})
    :ets.insert(@room_db_name, {"channels", details})
    {:reply, "ok", state}
  end

  @impl true
  def handle_call("get_stats", _from, state) do
    [{_key, details} | _t] = :ets.lookup(@room_db_name, "channels")

    # fun = :ets.fun2ms(fn {key, val} when is_pid(key) -> val end)
    # fetching data of those rows, which have pid as keys.
    room_data = :ets.select(@room_db_name, [{{:"$1", :"$2"}, [is_pid: :"$1"], [:"$2"]}])

    stats = %{
      "channel_count" => Map.keys(details) |> Enum.count(),
      "room_count" => Enum.count(room_data),
      "rooms" => room_data
    }

    {:reply, stats, state}
  end

  @impl true
  def handle_call({"get_channel_name", room_pid}, _from, state) do
    [{_room_name, details} | _t] = :ets.lookup(@room_db_name, room_pid)
    room_name = details["room_name"]
    match_id = details["match_id"]
    {:reply, "room_" <> room_name <> ":" <> match_id, state}
  end

  @impl true
  def handle_call({"get_room_state", room_id}, _from, state) do
    room_state =
      case Records.is_process_registered(room_id) do
        true -> :sys.get_state(Records.via_tuple(room_id))
        false -> %{}
      end

    {:reply, room_state, state}
  end

  @impl true
  def handle_call({"room_join", room_pid, opts}, _from, state) do
    player_id = Keyword.get(opts, :player_id)

    status = add_to_room(:ets.lookup(@room_db_name, room_pid), player_id)

    {:reply, status, state}
  end

  @impl true
  def handle_call({"room_left", room_pid, player_id}, _from, state) do
    [{_room_name, details} | _t] = :ets.lookup(@room_db_name, room_pid)

    {popped_val, details} = pop_in(details["players"][player_id])
    room_name = details["room_name"]
    match_id = details["match_id"]
    room_id = room_name <> ":" <> match_id
    Matcher.remove_player(room_id, player_id)
    manage_room_deletion(room_pid, details)
    # Disposing the game-room, if no player in roomDb's room
    # Or call on_leave on game-room.
    {:reply, popped_val, state}
  end

  @impl true
  def handle_call({"update_timer_ref", room_pid, player_id, ref}, _from, state) do
    [{_room_name, details} | _t] = :ets.lookup(@room_db_name, room_pid)

    details =
      case ref do
        ref when is_reference(ref) ->
          put_in(details["players"][player_id]["recon_ref"], ref)

        _ ->
          put_in(details["players"][player_id], %{
            "recon_ref" => ref,
            "rejoin" => false
          })
      end

    :ets.insert(@room_db_name, {room_pid, details})
    {:reply, "updated", state}
  end

  @impl true
  def handle_call({"get_timer_ref", room_pid, player_id}, _from, state) do
    [{_room_name, details} | _t] = :ets.lookup(@room_db_name, room_pid)

    ref = details["players"][player_id]["recon_ref"]
    {:reply, ref, state}
  end

  @impl true
  def handle_call({"has_rejoined", room_pid, player_id}, _from, state) do
    [{_room_name, details} | _t] = :ets.lookup(@room_db_name, room_pid)

    status = details["players"][player_id]["rejoin"]
    {:reply, status, state}
  end

  ## helper
  defp add_to_room([], _player_id), do: "error"

  defp add_to_room([{room_name, details} | _t], player_id) do
    case details["players"][player_id] do
      nil ->
        details =
          put_in(details["players"][player_id], %{
            "recon_ref" => true,
            "rejoin" => false
          })

        :ets.insert(@room_db_name, {room_name, details})
        "ok"

      _ ->
        details = put_in(details["players"][player_id]["rejoin"], true)
        :ets.insert(@room_db_name, {room_name, details})
        "already_exists"
    end
  end

  defp manage_room_deletion(room_pid, details) do
    player_count =
      details["players"]
      |> Enum.count()

    case player_count do
      0 ->
        GenServer.call(self(), {"delete_room", room_pid})

      _ ->
        details
    end
  end
end
