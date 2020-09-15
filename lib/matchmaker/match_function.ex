defmodule Garuda.Matchmaker.MatchFunction do
  @moduledoc """
    Functionalties to manage the queuing system and state of matchmaker
  """
  use GenServer
  require Logger

  ##################

  def start_link([]) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def send_to_queue(player_details) do
    GenServer.cast(__MODULE__, {"send_to_queue", player_details})
  end

  def remove_player(player_id) do
    GenServer.cast(__MODULE__, {"remove_player", player_id})
  end

  #################

  @impl true
  def init(:ok) do
    Logger.info("----...MatchMaker Started...")
    create_ets()
    {:ok, []}
  end

  @impl true
  def handle_cast({"send_to_queue", player_details}, state) do
    Logger.info("----sending to  queue")
    player_details |> handle_room_entry()
    {:noreply, state}
  end

  @impl true
  def handle_cast({"remove_player", player_id}, state) do
    ets_remove_player_data(player_id)
    {:noreply, state}
  end

  @impl true
  def handle_info({"no_match", _room_name, pid, player_id}, state) do
    send(
      pid,
      {"match_maker_result",
       %{
         "match_id" => "",
         "players" => []
       }}
    )

    ets_remove_player_data(player_id)
    {:noreply, state}
  end

  ################

  defp create_ets do
    :ets.new(:match_table, [:named_table])
    Logger.info("----ETS Created")
  end

  ## handling entry into game_room row in ets
  defp handle_room_entry(player_details) do
    Logger.info("----handling room entry")
    pid = player_details["pid"]
    player_id = player_details["player_id"]
    room_name = player_details["room_name"]

    Process.send_after(self(), {"no_match", room_name, pid, player_id}, 60_000)

    room_name
    |> getmap_players_in_room()
    |> put_player_in_room(player_details)
  end

  defp getmap_players_in_room(room_name) do
    case :ets.lookup(:match_table, room_name) do
      [{_room_name_key, map_players_in_room}] ->
        Logger.info("----found players #{inspect(map_players_in_room)}")
        map_players_in_room

      rest ->
        Logger.info("----Not yet inserted anything #{inspect(rest)}")
        []
    end
  end

  defp put_player_in_room([], player_details) do
    Logger.info("----putting player in empty room")
    player_id = player_details["player_id"]
    game_room = player_details["room_name"]
    match_id = player_details["match_id"] || ""
    pid = player_details["pid"]

    map_first_player_in_room = %{player_id => %{"match_id" => match_id}}

    update_player_map(player_id, game_room, pid)
    ets_insert_into_room_collection(map_first_player_in_room, game_room)
  end

  defp put_player_in_room(map_players_in_room, player_details) do
    Logger.info("----putting player in non room")
    player_id = player_details["player_id"]
    player_count = player_details["player_count"]
    players_in_room_count = map_players_in_room |> Map.keys() |> Enum.count()
    game_room = player_details["room_name"]
    pid = player_details["pid"]

    update_player_map(player_id, game_room, pid)

    put_player_in_room(
      map_players_in_room,
      player_details,
      Map.has_key?(map_players_in_room, player_id),
      players_in_room_count + 1 >= player_count
    )
  end

  defp put_player_in_room(
         map_players_in_room,
         player_details,
         player_in_room?,
         sufficient_players?
       )

  defp put_player_in_room(map_players_in_room, player_details, false, true) do
    Logger.info("----not putting player in room suff player count")
    game_room = player_details["room_name"]
    player_id = player_details["player_id"]
    player_count = player_details["player_count"]
    match_id = player_details["match_id"] || ""

    player_ids =
      map_players_in_room
      |> Map.keys()
      |> Enum.take(player_count - 1)

    map_players_in_room =
      player_ids
      |> Enum.reduce(map_players_in_room, fn x, acc -> Map.delete(acc, x) end)

    player_id_list = [player_id | player_ids]
    ets_insert_into_room_collection(map_players_in_room, game_room)

    make_match(game_room, player_id_list, match_id)
  end

  defp put_player_in_room(map_players_in_room, player_details, false, false) do
    Logger.info("----putting player in room as player not in room")
    game_room = player_details["room_name"]
    player_id = player_details["player_id"]

    match_id = player_details["match_id"] || ""

    player_map = %{
      "match_id" => match_id
    }

    map_players_in_room = map_players_in_room |> Map.put(player_id, player_map)
    ets_insert_into_room_collection(map_players_in_room, game_room)
  end

  defp put_player_in_room(map_players_in_room, player_details, true, true) do
    Logger.info("----player in room sufficient player count reached..making match")
    game_room = player_details["room_name"]
    player_id = player_details["player_id"]
    player_count = player_details["player_count"]
    match_id = player_details["match_id"] || ""

    map_players_in_room = Map.delete(map_players_in_room, player_id)

    player_ids =
      map_players_in_room
      |> Map.keys()
      |> Enum.take(player_count - 1)

    map_players_in_room =
      player_ids
      |> Enum.reduce(map_players_in_room, fn x, acc -> Map.delete(acc, x) end)

    player_id_list = [player_id | player_ids]
    ets_insert_into_room_collection(map_players_in_room, game_room)

    make_match(game_room, player_id_list, match_id)
  end

  defp put_player_in_room(_map_players_in_room, _player_details, _player_in_room?, false) do
    Logger.info("----player in room, suff player count not reached  do nothing")
    nil
  end

  defp make_match(_game_room, player_id_list, match_id) do
    match_id =
      case match_id do
        "" -> UUID.uuid4() |> String.split("-") |> List.first()
        _ -> match_id
      end

    match_details = %{
      "players" => player_id_list,
      "match_id" => match_id
    }

    broadcast_to_all_players(match_details)
    remove_players_from_players_map(player_id_list)
  end

  defp ets_insert_into_room_collection(player_map, game_room) do
    Logger.info("XXXXXXXXXXX #{game_room} #{inspect(player_map)}")
    :ets.insert(:match_table, {game_room, player_map})
  end

  defp ets_insert_into_player_lobby_map(players_map) do
    :ets.insert(:match_table, {"players", players_map})
  end

  defp update_player_map(player_id, game_room, pid) do
    getmap_players_in_lobby()
    |> update_player_map(player_id, game_room, pid)
    |> ets_insert_into_player_lobby_map
  end

  defp update_player_map([], player_id, game_room, pid) do
    %{player_id => {game_room, pid}}
  end

  defp update_player_map(player_map, player_id, game_room, pid) do
    Map.put(player_map, player_id, {game_room, pid})
  end

  defp ets_remove_player_data(player_id) do
    getmap_players_in_lobby()
    |> remove_player_entry(player_id)
  end

  defp remove_player_entry([], _player_id), do: nil

  defp remove_player_entry(player_map, player_id) do
    remove_player_entry(player_map, player_id, Map.has_key?(player_map, player_id))
  end

  defp remove_player_entry(player_map, player_id, player_in_player_lobby_map?)

  defp remove_player_entry(player_map, player_id, true) do
    game_room = player_map[player_id] |> get_game_room
    player_map |> Map.delete(player_id) |> ets_insert_into_player_lobby_map

    game_room
    |> getmap_players_in_room()
    |> Map.delete(player_id)
    |> ets_insert_into_room_collection(game_room)
  end

  defp remove_player_entry(_player_map, _player_id, false), do: nil

  defp getmap_players_in_lobby do
    case :ets.lookup(:match_table, "players") do
      [{_room_name_key, map_players_in_lobby}] ->
        map_players_in_lobby

      _ ->
        Logger.info("----Not yet inserted anything in player_{gameroom_pid} map")
        []
    end
  end

  defp broadcast_to_all_players(match_details) do
    player_list = match_details["players"]
    player_map = getmap_players_in_lobby()
    broadcast_to_all_players(player_map, player_list, match_details)
    # player_list
    # |> Enum.each( fn player_id -> player_map[player_id] |> get_pid |> broadcast_to_player(match_details) end)
  end

  defp broadcast_to_all_players([], _player_list, _match_details), do: nil

  defp broadcast_to_all_players(player_map, player_list, match_details) do
    player_list
    |> Enum.each(fn player_id ->
      player_map[player_id] |> get_pid |> broadcast_to_player(match_details)
    end)
  end

  defp broadcast_to_player(pid, match_details) do
    send(pid, {"match_maker_result", match_details})
  end

  defp get_pid({_game_room, pid}), do: pid
  defp get_game_room({game_room, _pid}), do: game_room

  defp remove_players_from_players_map(player_list) do
    Logger.info("------matchmker cleaning up room player maps")

    player_list
    |> Enum.each(fn player_id -> ets_remove_player_data(player_id) end)
  end
end
