defmodule Garuda.MatchMaker.Matcher do
  @moduledoc false

  # Manages the creation, updation and deletion of match rooms.
  use GenServer
  ##################

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Returns a match id, that can be used to join a game-room from client side.
    * match_details - A map of details required for matchmaking.

  ` %{
  "room_name" => "tictactoe",
  "player_id" => "Pw",
  "match_id" => "EDFXASG",
  "max_players" => 2
  } = match_details`
  """
  @spec join_or_create(map()) :: map()
  def join_or_create(match_details) do
    GenServer.call(__MODULE__, {"join_or_create", match_details})
  end

  @doc """
  Removes a player from the room, and make unlocks the room.
    * room_name - Unique room name.
    * player_id - Unique player id.
  """
  @spec remove_player(String.t(), String.t()) :: String.t()
  def remove_player(room_name, player_id) do
    GenServer.call(__MODULE__, {"remove_player", room_name, player_id})
  end

  @doc """
  Deletes the room, from the matchmaking table
    * room_name - Unique room name
  """
  @spec delete_room(String.t()) :: any
  def delete_room(room_name) do
    GenServer.call(__MODULE__, {"delete_room", room_name})
  end

  ####################
  @impl true
  def init(_opts) do
    create_ets()
    {:ok, %{}}
  end

  @impl true
  def handle_call({"join_or_create", match_details}, _from, state) do
    match_response =
      is_valid_details?(match_details)
      |> handle_join_or_create(match_details)

    {:reply, match_response, state}
  end

  @impl true
  def handle_call({"remove_player", room_name, player_id}, _from, state) do
    case :ets.lookup(:matcher_table, room_name) do
      [{_room_name, details} | _t] ->
        manage_deletion(room_name, details, player_id)
        {:reply, "deleted", state}

      _ ->
        {:reply, "room_not_found", state}
    end
  end

  @impl true
  def handle_call({"delete_room", room_name}, _from, state) do
    :ets.delete(:matcher_table, room_name)
    {:reply, "deleted", state}
  end

  ######################
  defp create_ets do
    :ets.new(:matcher_table, [:named_table])
  end

  defp is_valid_details?(%{"room_name" => name} = _match_details)
       when is_nil(name) or name === "",
       do: false

  defp is_valid_details?(_match_details), do: true

  # Clause for handling public rooms (coming wihtout match_id)
  defp handle_join_or_create(true, %{"match_id" => ""} = match_details) do
    %{
      "room_name" => room_name,
      "player_id" => player_id,
      "match_id" => _match_id,
      "max_players" => max_players
    } = match_details

    case get_available_public_rooms(room_name) do
      [] ->
        new_match_id = UUID.uuid4() |> String.split("-") |> List.first()
        create_new_room(room_name, new_match_id, player_id, max_players, false)

      room_list ->
        [room_name | _t] = List.first(room_list)
        [{_room_name, details} | _t] = :ets.lookup(:matcher_table, room_name)
        add_player_to_room(room_name, player_id, details, false)
    end
  end

  # Clause for handling private rooms (coming match_id)
  defp handle_join_or_create(true, match_details) do
    %{
      "room_name" => room_name,
      "player_id" => player_id,
      "match_id" => match_id,
      "max_players" => max_players
    } = match_details

    case get_available_private_room(room_name, match_id) do
      [] ->
        create_new_room(room_name, match_id, player_id, max_players, true)

      [{room_name, details} | _t] ->
        add_player_to_room(room_name, player_id, details, true)
    end
  end

  defp handle_join_or_create(false, _details), do: %{"error" => "invalid_match_data"}

  defp get_available_public_rooms(room_name) do
    unlocked_rooms =
      :ets.match(:matcher_table, {:"$1", %{"locked" => false, "is_private" => false}})

    Enum.filter(unlocked_rooms, fn [room | _t] ->
      String.split(room, ":") |> List.first() ===
        room_name
    end)
  end

  defp get_available_private_room(room_name, match_id) do
    unique_room_name = room_name <> ":" <> match_id
    :ets.lookup(:matcher_table, unique_room_name)
  end

  defp manage_deletion(room_name, details, player_id) do
    index = Enum.find_index(details["players"], fn id -> id === player_id end)

    # Deletes the room itslef, if this is the last player leaving.
    with true <- index !== nil,
         false <- manage_if_lastplayer(room_name, Enum.count(details["players"])) do
      {_pop, new_list} = List.pop_at(details["players"], index)

      :ets.insert(
        :matcher_table,
        {room_name,
         %{
           "players" => new_list,
           "locked" => true,
           "max_players" => details["max_players"],
           "is_private" => details["is_private"]
         }}
      )
    end
  end

  defp manage_if_lastplayer(room_name, 1) do
    :ets.delete(:matcher_table, room_name)
    true
  end

  defp manage_if_lastplayer(_room_name, _), do: false

  defp create_new_room(room_name, match_id, player_id, max_players, is_private) do
    unique_room_name = room_name <> ":" <> match_id
    is_room_lock = max_players === 1

    :ets.insert(
      :matcher_table,
      {unique_room_name,
       %{
         "players" => [player_id],
         "locked" => is_room_lock,
         "max_players" => max_players,
         "is_private" => is_private
       }}
    )

    %{"match_id" => match_id}
  end

  defp add_player_to_room(_room_name, _player_id, %{"locked" => true} = _details, _is_private) do
    %{"error" => "no_match_found"}
  end

  defp add_player_to_room(room_name, player_id, details, is_private) do
    # update the player list
    updated_player_list = [player_id | details["players"]]
    is_room_lock = Enum.count(updated_player_list) === details["max_players"]

    :ets.insert(
      :matcher_table,
      {room_name,
       %{
         "players" => updated_player_list,
         "locked" => is_room_lock,
         "max_players" => details["max_players"],
         "is_private" => is_private
       }}
    )

    %{"match_id" => room_name |> String.split(":") |> List.last()}
  end
end
