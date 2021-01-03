defmodule Garuda.Matchmaker.MatchmakerFunction do
  @moduledoc """
  Manages the queuing system and state management of matchmaker

  ## Match Making
    For matchmaking we are maintaining a queue with ets. There are 2 categories of queue
    - room collection
    - player collection

    In room collection, we have room_name from client as key of ets entry and a map of player_id to match_id as value
      [{room_name, %{"some_player_id" => %{"match_id" => "some_match_id"}}}]

    In player collection, we have "players" as key of ets entry and a map of player_id to {room_name, channel_pid} as value
      [{"players", %{"some_player_id" => {"some_game_room", channel_pid}}}]

    room_name format
    - default mode -> ```"garuda_matchmaking:{match_id} // "":{game_room}:{max_players}"```
    - create/join mode -> ```"garuda_matchmaking:{match_id}:{game_room}:createjoin"```

    In case of create-join match making,
    - room_name does not have max_players key
    - player creating the room, has a "room_player_count" key in room collection player map
    - rest of the players have -1 as "room_player_count"
    - before addition to room, player with non negative "room_player_count" is searched


  ## Explanation
    Reasons of player collection,
    - when a player leaves matchmaker channel, we can easily find game_room of the player and remove that player from the room collection
    - it also easier to fetch channel pid from player collection, instead of querying for room_name and player_id

    Less versatile but fast filters
    room_name format ensures players with same match_id and max_players grouped together, hence we wont be needing to check max_players of each players
    while match making. This also gives flexibity to add more filters to match making.
    But players cant be matched with players with different max_player count

    More versatile but slow filters
    filter data can be added to player map in room collection, which can be queried while match making
    leverages over time

  ## Flow
    - A player comes with match_id(optional), game_room and max_players.
    - room_name is constructed with the inputs
    - presence of room name as key in room collections is checked
      if not present,
        player_map is inserted into the map present as its value in  ets
        added to "players" key in player collection
      else,
        it is checked if max_players will be reached on addition of player,
        if yes,
        required number of players are popped from player map in room collection and match is made.
        that players entry is deleted from player collection
        else,
        player added to map in room collection
        player added to player collection


  """
  use GenServer
  require Logger
  import Garuda.Matchmaker.MatchmakerConstants

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

  def room_open?(room_id) do
    GenServer.call(__MODULE__, {"room_open", room_id})
  end

  def game_rooms(_room_name) do
    GenServer.call(__MODULE__, "game_rooms")
  end

  #################

  @impl true
  def init(:ok) do
    Logger.info("----...MatchMaker Started...")
    create_ets()
    {:ok, []}
  end

  @impl true
  def handle_call({"room_open", room_id}, _from, state) do
    is_room_open = room_id |> is_room_open?()
    {:reply, is_room_open, state}
  end

  @impl true
  def handle_call("game_rooms", _from, state) do
    open_game_rooms_list = show_open_game_rooms()
    {:reply, open_game_rooms_list, state}
  end

  @impl true
  def handle_cast({"send_to_queue", player_details}, state) do
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
  end

  defp show_open_game_rooms do
    :ets.match(:match_table, {:"$1", :"$2"})
  end

  defp is_room_open?(room_name) do
    room_population = room_name |> getmap_players_in_room()

    case Enum.count(room_population) do
      0 -> false
      _ -> true
    end
  end

  # handling entry into game_room row in ets
  # gets the player map againt the room_name
  # tries pushing the player into the player map
  defp handle_room_entry(player_details) do
    pid = player_details["pid"]
    player_id = player_details["player_id"]
    room_name = player_details["room_name"]

    Process.send_after(self(), {"no_match", room_name, pid, player_id}, 60_000)

    room_name
    |> getmap_players_in_room()
    |> put_player_in_room(player_details, player_details["mode"])
  end

  # returns the current players in the room in a
  # map -> %{player_id => {room_name, channel_pid}}
  # or []
  defp getmap_players_in_room(room_name) do
    case :ets.lookup(:match_table, room_name) do
      [{_room_name_key, map_players_in_room}] ->
        map_players_in_room

      _rest ->
        []
    end
  end

  # puts the first player in the players map
  defp put_player_in_room([], player_details, m_default()) do
    player_id = player_details["player_id"]
    game_room = player_details["room_name"]
    match_id = player_details["match_id"] || ""
    pid = player_details["pid"]
    # player_count = player_details["player_count"]

    map_first_player_in_room = %{player_id => %{"match_id" => match_id}}

    update_player_map(player_id, game_room, pid)
    ets_insert_into_room_collection(map_first_player_in_room, game_room)
  end

  # tries to put player in players map after checking
  # - is player already in map ?
  # - will map reach its population limit if player is added ?
  defp put_player_in_room(map_players_in_room, player_details, m_default()) do
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

  # puts the first player in the players map
  defp put_player_in_room(_player_map, player_details, m_create()) do
    player_id = player_details["player_id"]
    game_room = player_details["room_name"]
    match_id = player_details["match_id"] || ""
    pid = player_details["pid"]
    player_count = player_details["player_count"]

    map_first_player_in_room = %{
      player_id => %{"match_id" => match_id, "room_player_count" => player_count}
    }

    update_player_map(player_id, game_room, pid)
    ets_insert_into_room_collection(map_first_player_in_room, game_room)
  end

  # tries to put player in players map after checking
  # - is player already in map ?
  # - will map reach its population limit if player is added ?
  defp put_player_in_room(map_players_in_room, player_details, m_join()) do
    player_id = player_details["player_id"]
    # search for player with non-negative player count

    player_count =
      map_players_in_room
      |> Enum.filter(fn {_k, v} ->
        v["room_player_count"] != nil and v["room_player_count"] > 0
      end)
      |> Enum.reduce(0, fn {_k, v}, acc -> acc + v["room_player_count"] end)

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

  defp put_player_in_room(_map_players_in_room, _player_details, _mode) do
    nil
  end

  defp put_player_in_room(
         map_players_in_room,
         player_details,
         player_in_room?,
         sufficient_players?
       )

  # player not in room and adding the player to map will fulfil player_count criteria hence we,
  # - fetch player_ids of player_count - 1 number of players from the player map
  # - delete those players from the players map and make a new map with remaining players
  # - add current player_id to the player_list
  # - insert new map into ets against the game_room
  # - make a match_id for player list made above
  defp put_player_in_room(map_players_in_room, player_details, false, true) do
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

  # player not in room but adding the player to map will still not fulfil player_count criteria hence we,
  # - add current player to player map
  # - insert map into ets
  defp put_player_in_room(map_players_in_room, player_details, false, false) do
    game_room = player_details["room_name"]
    player_id = player_details["player_id"]

    match_id = player_details["match_id"] || ""

    player_map = %{
      "match_id" => match_id
    }

    map_players_in_room = map_players_in_room |> Map.put(player_id, player_map)
    ets_insert_into_room_collection(map_players_in_room, game_room)
  end

  # player already in room hence we do nothing,
  defp put_player_in_room(_map_players_in_room, _player_details, true, _sufficient_players?) do
    nil
  end

  # called when sufficient players are got to be matched
  # a match_id is generated
  # match details is broadcasted to all players in players list
  # all players removed from the "players" key from ets that is kept for keeping player_id-game_room map
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

  # inserts player map into :match_table, key -> game_room(room_name) value -> %players_map{}, used in core matchmaking
  defp ets_insert_into_room_collection(player_map, game_room) do
    :ets.insert(:match_table, {game_room, player_map})
  end

  # inserts player map into :match_table, key -> "players" value -> %players_map{} // clarification needed
  defp ets_insert_into_player_lobby_map(players_map) do
    :ets.insert(:match_table, {"players", players_map})
  end

  # updates player map before inserting into "players" key to ets
  defp update_player_map(player_id, game_room, pid) do
    getmap_players_in_lobby()
    |> update_player_map(player_id, game_room, pid)
    |> ets_insert_into_player_lobby_map
  end

  # player map kept in "players" key in ets maps player_id to {game_room, channel_pid}
  # first entry
  defp update_player_map([], player_id, game_room, pid) do
    %{player_id => {game_room, pid}}
  end

  # player map kept in "players" key in ets maps player_id to {game_room, channel_pid}
  # adds entry
  defp update_player_map(player_map, player_id, game_room, pid) do
    Map.put(player_map, player_id, {game_room, pid})
  end

  # gets player data {game_room, pid} from "players" in ets
  # removes the player entry, post successful match making or disconnection from matchmaking channel
  defp ets_remove_player_data(player_id) do
    getmap_players_in_lobby()
    |> remove_player_entry(player_id)
  end

  # no players on "players" in ets. do nothing
  defp remove_player_entry([], _player_id), do: nil

  # some entry in "players", check if player_id present
  defp remove_player_entry(player_map, player_id) do
    remove_player_entry(player_map, player_id, Map.has_key?(player_map, player_id))
  end

  defp remove_player_entry(player_map, player_id, player_in_player_lobby_map?)

  # player id present in "players"
  # delete player details against player_id in "players" in ets
  # get game_room, "players" has a playermap where key -> player_id, value -> {game_room, channel_pid}
  # with game_room available,
  # - fetch game_room details from :match_table key room_name, contains players_map
  # - delete player_id from map
  # - insert new map to :match_table, key room_name
  defp remove_player_entry(player_map, player_id, true) do
    game_room = player_map[player_id] |> get_game_room
    player_map |> Map.delete(player_id) |> ets_insert_into_player_lobby_map

    game_room
    |> getmap_players_in_room()
    |> Map.delete(player_id)
    |> ets_insert_into_room_collection(game_room)
  end

  # player id not present in "players"
  defp remove_player_entry(_player_map, _player_id, false), do: nil

  # get player map from "players" key in ets
  defp getmap_players_in_lobby do
    case :ets.lookup(:match_table, "players") do
      [{_room_name_key, map_players_in_lobby}] ->
        map_players_in_lobby

      _ ->
        []
    end
  end

  # broadcast match details to all players in players_list
  # for that we fetch total players_map from "players" and send them to broacast function with players_list
  # for each player_id in player_list, we
  # - fetch the channel pid from players_map
  # - broadcast to the channel
  defp broadcast_to_all_players(match_details) do
    player_list = match_details["players"]
    player_map = getmap_players_in_lobby()
    broadcast_to_all_players(player_map, player_list, match_details)
  end

  defp broadcast_to_all_players([], _player_list, _match_details), do: nil

  defp broadcast_to_all_players(player_map, player_list, match_details) do
    player_list
    |> Enum.each(fn player_id ->
      player_map[player_id] |> get_pid |> broadcast_to_player(match_details)
    end)
  end

  # broadcasts to each players channel
  defp broadcast_to_player(pid, match_details) do
    send(pid, {"match_maker_result", match_details})
  end

  defp get_pid({_game_room, pid}), do: pid
  defp get_game_room({game_room, _pid}), do: game_room

  # remove each player from "players" post successfull match made
  defp remove_players_from_players_map(player_list) do
    player_list
    |> Enum.each(fn player_id -> ets_remove_player_data(player_id) end)
  end
end
