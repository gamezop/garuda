defmodule Garuda.Matchmaker.MatchmakerChannel do
  use Phoenix.Channel
  require Logger
  # use GobletWeb, :channel
  alias Garuda.Matchmaker.MatchFunction

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
      "room_name:match_id:player_count" -> -> %{player_count: , match_id: "" }
  """
  def join("garuda_matchmaker:" <> _room_id, player_details, socket) do
    player_details = Map.put(player_details, "pid", self())
    socket = assign(socket, :player_id, player_details["player_id"])
    MatchFunction.send_to_queue(player_details)
    {:ok, socket}
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

    if should_send_match_info?(socket, player_list) do
      Logger.info("matchmaker_data: #{inspect(match_details)}")
      push(socket, "match_maker_event", match_details)
    end
  end

  defp should_send_match_info?(socket, player_list) do
    Enum.any?(player_list, fn player_id ->
      player_id === socket.assigns.player_id
    end)
  end

  defp handle_on_terminate(socket) do
    Logger.info("----terminating channel")
    MatchFunction.remove_player(socket.assigns.player_id)
  end
end
