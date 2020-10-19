defmodule Garuda.Matchmaker.MatchmakerChannel do
  use Phoenix.Channel
  require Logger
  alias Garuda.Matchmaker.MatchmakerFunction
  import Garuda.Matchmaker.MatchmakerConstants

  @moduledoc """
  This is the Goblet channel module that handles matchmaking for Garuda.
  """

  @doc """
    player_details :
    - player_id
    - room_name
    - player_count
    - match_id (if any)

    - pid (after joining)

      "rtt_name:player_count" -> %{player_count: }
      or
      "room_name:match_id:player_count" -> %{player_count: , match_id: "" }
  """
  def join("garuda_matchmaker:" <> _room_id, player_details, socket) do
    with player_details <- add_pid(player_details),
         player_details <- add_player_id(player_details, socket),
         {:ok, reply} <- handle_matchmaking_mode(player_details) do
      IO.puts("MATCHMAKING REPLY  =>  #{inspect(reply)}")
      {:ok, socket}
    else
      {:error, reply} ->
        IO.puts("MATCHMAKING REPLY  =>  #{inspect(reply)}")
        {:error, %{reason: reply}}
    end
  end

  def handle_in("get_open_rooms", message, socket) do
    send_open_game_rooms_list(message["room_name"], socket)
    {:noreply, socket}
  end

  def handle_info({"match_maker_result", match_details}, socket) do
    send_matchdata(match_details, socket)
    {:noreply, socket}
  end

  def terminate(_reason, socket) do
    handle_on_terminate(socket)
    {:ok, socket}
  end

  ##################

  defp send_matchdata(match_details, socket) do
    player_list = match_details["players"]

    Logger.info("matchmaker_socket: #{inspect(socket)}")
    Logger.info("matchmaker_data: #{inspect(match_details)}")

    if should_send_match_info?(socket, player_list) do
      push(socket, "match_maker_event", match_details)
    end
  end

  defp should_send_match_info?(socket, player_list) do
    Enum.any?(player_list, fn player_id ->
      player_id === socket.assigns.player_id
    end)
  end

  defp send_open_game_rooms_list(room_name, socket) do
    game_rooms = MatchmakerFunction.game_rooms(room_name)
    IO.puts("game rooms #{inspect(game_rooms)}")
    push(socket, "open_rooms", game_rooms)
  end

  defp handle_on_terminate(socket) do
    Logger.info("----terminating channel")
    MatchmakerFunction.remove_player(socket.assigns.player_id)
  end

  defp add_pid(player_details), do: Map.put(player_details, "pid", self())

  defp add_player_id(player_details, socket),
    do: Map.put(player_details, "player_id", socket.assigns.player_id)

  defp handle_matchmaking_mode(player_details) do
    handle_matchmaking_mode(player_details, player_details["mode"])
  end

  defp handle_matchmaking_mode(player_details, m_default()) do
    MatchmakerFunction.send_to_queue(player_details)
    {:ok, "player_added"}
  end

  defp handle_matchmaking_mode(player_details, m_create()) do
    if MatchmakerFunction.room_open?(player_details["room_name"]) do
      {:error, "room busy"}
    else
      MatchmakerFunction.send_to_queue(player_details)
      {:ok, "room opened"}
    end
  end

  defp handle_matchmaking_mode(player_details, m_join()) do
    if MatchmakerFunction.room_open?(player_details["room_name"]) do
      MatchmakerFunction.send_to_queue(player_details)
      {:ok, "joined room"}
    else
      {:error, "room not present"}
    end
  end
end
