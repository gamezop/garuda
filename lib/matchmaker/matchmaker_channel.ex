defmodule Garuda.MatchMakerChannel do
  @moduledoc false
  use Phoenix.Channel
  alias Garuda.MatchMaker.Matcher
  require Logger

  def join("garuda_matchmaker:lobby", match_details, socket) do
    Logger.info("Player #{match_details["player_id"]} joining MatchMakerChannel")
    match_resp = Matcher.join_or_create(match_details)
    socket = assign(socket, :mm_player_id, match_details["player_id"])

    if Map.has_key?(match_resp, "match_id") do
      socket = assign(socket, :mm_match_id, match_resp["match_id"])
      {:ok, match_resp, socket}
    else
      {:error, match_resp}
    end
  end

  def terminate(_reason, socket) do
    Logger.info("Terminating MatchMakerChannel for #{socket.assigns.mm_player_id} in #{socket.assigns.mm_match_id}")
    Matcher.remove_player(socket.assigns.mm_match_id, socket.assigns.mm_player_id) |> IO.inspect()
    socket
  end
end
