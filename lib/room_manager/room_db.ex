defmodule Garuda.RoomManager.RoomDb do
  @moduledoc """
  Stores the info of all the game-rooms and functions to manage those data.

  Orwell uses data from RoomDb, for rendering the live interactive dashboard
  """
  alias Garuda.MatchMaker.Matcher
  alias Garuda.RoomManager.Records
  use GenServer

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
    GenServer.call(__MODULE__, :get_stats)
  end

  @spec get_room_state(String.t()) :: map()
  @doc """
  Returns the state of a given `room_id`

    * `room_id` - Unique combination of room_name + ":" + room_id., ex ("tictactoe:ACFBEBW")
  """
  def get_room_state(room_id) do
    GenServer.call(__MODULE__, {:get_room_state, room_id})
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
    {:ok, %{"rooms" => %{}, "channels" => %{}}}
  end

  @impl true
  def handle_call({"delete_room", room_pid}, _from, state) do
    room_name = state["rooms"][room_pid]["room_name"]
    match_id = state["rooms"][room_pid]["match_id"]
    # IO.puts("#{room_name}:#{match_id}")
    room_id = "#{room_name}:#{match_id}"
    Matcher.delete_room(room_id)
    {popped_val, state} = pop_in(state["rooms"][room_pid])
    {:reply, popped_val, state}
  end

  @impl true
  def handle_call({"save_room", {room_pid, info}}, _from, state) do
    state = put_in(state["rooms"][room_pid], info)
    {:reply, "ok", state}
  end

  @impl true
  def handle_call({"channel_leave", channel_pid}, _from, state) do
    {popped_val, state} = pop_in(state["channels"][channel_pid])
    {:reply, popped_val, state}
  end

  @impl true
  def handle_call({"channel_join", {channel_pid, _info}}, _from, state) do
    state = put_in(state["channels"][channel_pid], %{})
    {:reply, "ok", state}
  end

  @impl true
  def handle_call(:get_stats, _from, state) do
    stats = %{
      "channel_count" => Map.keys(state["channels"]) |> Enum.count(),
      "room_count" => Map.keys(state["rooms"]) |> Enum.count(),
      "rooms" => state["rooms"]
    }

    {:reply, stats, state}
  end

  @impl true
  def handle_call({"get_channel_name", room_pid}, _from, state) do
    room_name = state["rooms"][room_pid]["room_name"]
    match_id = state["rooms"][room_pid]["match_id"]
    {:reply, "room_" <> room_name <> ":" <> match_id, state}
  end

  @impl true
  def handle_call({:get_room_state, room_id}, _from, state) do
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

    {status, state} = add_to_room(state["rooms"][room_pid], player_id, room_pid, state)

    {:reply, status, state}
  end

  @impl true
  def handle_call({"room_left", room_pid, player_id}, _from, state) do
    {popped_val, state} = pop_in(state["rooms"][room_pid]["players"][player_id])
    room_name = state["rooms"][room_pid]["room_name"]
    match_id = state["rooms"][room_pid]["match_id"]
    room_id = room_name <> ":" <> match_id
    Matcher.remove_player(room_id, player_id)
    state = manage_room_deletion(room_pid, state)
    # Disposing the game-room, if no player in roomDb's room
    # Or call on_leave on game-room.
    {:reply, popped_val, state}
  end

  @impl true
  def handle_call({"update_timer_ref", room_pid, player_id, ref}, _from, state) do
    state =
      case ref do
        ref when is_reference(ref) ->
          put_in(state["rooms"][room_pid]["players"][player_id]["recon_ref"], ref)

        _ ->
          put_in(state["rooms"][room_pid]["players"][player_id], %{
            "recon_ref" => ref,
            "rejoin" => false
          })
      end

    {:reply, "updated", state}
  end

  @impl true
  def handle_call({"get_timer_ref", room_pid, player_id}, _from, state) do
    ref = state["rooms"][room_pid]["players"][player_id]["recon_ref"]
    {:reply, ref, state}
  end

  @impl true
  def handle_call({"has_rejoined", room_pid, player_id}, _from, state) do
    status = state["rooms"][room_pid]["players"][player_id]["rejoin"]
    {:reply, status, state}
  end

  ## helper
  defp add_to_room(nil, _player_id, _room_pid, state), do: {"error", state}

  defp add_to_room(_players, player_id, room_pid, state) do
    case state["rooms"][room_pid]["players"][player_id] do
      nil ->
        state =
          put_in(state["rooms"][room_pid]["players"][player_id], %{
            "recon_ref" => true,
            "rejoin" => false
          })

        {"ok", state}

      _ ->
        state = put_in(state["rooms"][room_pid]["players"][player_id]["rejoin"], true)
        {"already_exists", state}
    end
  end

  def manage_room_deletion(room_pid, state) do
    player_count =
      state["rooms"][room_pid]["players"]
      |> Enum.count()

    case player_count do
      0 ->
        {_popped_val, state} = pop_in(state["rooms"][room_pid])
        state

      _ ->
        state
    end
  end
end
