defmodule Garuda.NeoMatcher.Matcher do
  @moduledoc """
  Trying a different take on matchmaker, to be flexible
  for all genre of games.
  """

  use GenServer
  require Logger

  ##################

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def join_or_create(match_details) do
    GenServer.call(__MODULE__, {"join_or_create", match_details})
  end

  def get_available_rooms(room_name) do
    GenServer.call(__MODULE__, {"get_avail_rooms", room_name})
  end

  def remove_player(room_name, player_id) do
    GenServer.call(__MODULE__, {"remove_player", room_name, player_id})
  end

  ####################
  @impl true
  def init(_opts) do
    Logger.info("<><><><> Neo Matcher Started <><><><>")
    create_neo_ets()
    {:ok, %{}}
  end

  @impl true
  def handle_call({"join_or_create", match_details}, _from, state) do
    match_id = handle_join_or_create(match_details)
    {:reply, match_id, state}
  end

  @impl true
  def handle_call({"get_avail_rooms", room_name}, _from, state) do
    room_list = get_available_public_rooms(room_name)
    {:reply, room_list, state}
  end

  @impl true
  def handle_call({"remove_player", room_name, player_id}, _from, state) do
    case :ets.lookup(:neo_matcher, room_name) do
      [{_room_name, details} | _t] ->
        manage_deletion(room_name, details, player_id)
        {:reply, "deleted", state}

      _ ->
        {:reply, "room_not_found", state}
    end
  end

  ######################
  defp create_neo_ets do
    :ets.new(:neo_matcher, [:named_table])
    :ets.new(:neo_matcher_private, [:named_table])
  end

  defp handle_join_or_create(%{"match_id" => ""} = match_details) do
    # if match_id is empty, then we have to searc h for public rooms that are unlocked.
    # if no public room available for the "room_name", then we have to create one and
    # return the match_id to the player.
    %{
      "room_name" => room_name,
      "player_id" => player_id,
      "match_id" => _match_id,
      "max_players" => max_players
    } = match_details

    case get_available_public_rooms(room_name) do
      [] ->
        new_match_id = UUID.uuid4() |> String.split("-") |> List.first()
        unique_room_name = room_name <> ":" <> new_match_id
        is_room_lock = max_players === 1

        :ets.insert(
          :neo_matcher,
          {unique_room_name,
           %{"players" => [player_id], "locked" => is_room_lock, "max_players" => max_players}}
        )

        IO.puts("NEW ROOM CREATED => #{unique_room_name}")
        new_match_id

      room_list ->
        [room_name | _t] = List.first(room_list)
        IO.puts("ROOM FOUND => #{room_name}")
        [{_room_name, details} | _t] = :ets.lookup(:neo_matcher, room_name)
        # update the player list
        updated_player_list = [player_id | details["players"]]
        is_room_lock = Enum.count(updated_player_list) === details["max_players"]

        :ets.insert(
          :neo_matcher,
          {room_name,
           %{
             "players" => updated_player_list,
             "locked" => is_room_lock,
             "max_players" => details["max_players"]
           }}
        )

        room_name |> String.split(":") |> List.last()
    end
  end

  defp handle_join_or_create(match_details) do
    # This clause will evoke, if player comes with matchid.
    %{
      "room_name" => room_name,
      "player_id" => player_id,
      "match_id" => match_id,
      "max_players" => max_players
    } = match_details

    case get_available_private_room(room_name, match_id) do
      [] ->
        unique_room_name = room_name <> ":" <> match_id
        is_room_lock = max_players === 1

        :ets.insert(
          :neo_matcher_private,
          {unique_room_name,
           %{"players" => [player_id], "locked" => is_room_lock, "max_players" => max_players}}
        )

        IO.puts("NEW PRIVATE ROOM CREATED => #{unique_room_name}")
        match_id

      [{room_name, details} | _t] ->
        IO.puts("PRIVATE ROOM FOUND => #{room_name}")
        updated_player_list = [player_id | details["players"]]
        is_room_lock = Enum.count(updated_player_list) === details["max_players"]

        :ets.insert(
          :neo_matcher_private,
          {room_name,
           %{
             "players" => updated_player_list,
             "locked" => is_room_lock,
             "max_players" => details["max_players"]
           }}
        )

        room_name |> String.split(":") |> List.last()
    end
  end

  defp get_available_public_rooms(room_name) do
    unlocked_rooms = :ets.match(:neo_matcher, {:"$1", %{"locked" => false}})

    Enum.filter(unlocked_rooms, fn [room | _t] ->
      String.split(room, ":") |> List.first() ===
        room_name
    end)
  end

  defp get_available_private_room(room_name, match_id) do
    unique_room_name = room_name <> ":" <> match_id
    :ets.lookup(:neo_matcher_private, unique_room_name)
  end

  defp manage_deletion(room_name, details, player_id) do
    index = Enum.find_index(details["players"], fn id -> id === player_id end)

    with true <- index !== nil,
         false <- manage_if_lastplayer(room_name, Enum.count(details["players"])) do
      {_pop, new_list} = List.pop_at(details["players"], index)

      :ets.insert(
        :neo_matcher,
        {room_name,
         %{"players" => new_list, "locked" => false, "max_players" => details["max_players"]}}
      )
    end
  end

  defp manage_if_lastplayer(room_name, 1) do
    :ets.delete(:neo_matcher, room_name)
    true
  end

  defp manage_if_lastplayer(_room_name, _), do: false
end
