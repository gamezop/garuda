defmodule Garuda.RoomManager.RoomDb do
  @moduledoc """
  Stores the info of all the game-rooms and functions to manage those data.

  Orwell uses data from RoomDb, for rendering the live interactive dashboard
  """
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

  This function is mostly used by game-rooms to send messages to their
  corresponding game-channels.
  """
  @spec get_channel_name(pid()) :: String.t()
  def get_channel_name(pid) do
    GenServer.call(__MODULE__, {:get_channel_name, pid})
  end

  @spec delete_room(pid()) :: :ok
  @doc """
  Deletes a game-room info with a pid.
  """
  def delete_room(room_pid) do
    GenServer.cast(__MODULE__, {:delete_room, room_pid})
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

  @impl true
  def init(_opts) do
    {:ok, %{"rooms" => %{}, "channels" => %{}}}
  end

  @impl true
  def handle_cast({:delete_room, room_pid}, state) do
    {_popped_val, state} = pop_in(state["rooms"][room_pid])
    {:noreply, state}
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
  def handle_call({:get_channel_name, room_pid}, _from, state) do
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

    state =
      case state["rooms"][room_pid] do
        nil -> state
        _ -> put_in(state["rooms"][room_pid]["players"][player_id], true)
      end

    {:noreply, state}
  end

  @impl true
  def handle_info({:room_left, room_pid, player_id}, state) do
    {_popped_val, state} = pop_in(state["rooms"][room_pid]["players"][player_id])
    {:noreply, state}
  end

  @impl true
  def handle_info({:room_terminated, room_pid}, state) do
    {_popped_val, state} = pop_in(state["rooms"][room_pid])
    {:noreply, state}
  end
end
