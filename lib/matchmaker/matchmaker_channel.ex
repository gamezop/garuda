defmodule Garuda.MatchMakerChannel do
  @moduledoc false
  use Phoenix.Channel
  alias Garuda.MatchMaker.Matcher

  def join("garuda_matchmaker:lobby", match_details, socket) do
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
    Matcher.remove_player(socket.assigns.mm_match_id, socket.assigns.mm_player_id)
    socket
  end
end
