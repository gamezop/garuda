defmodule Garuda.MatchMakerChannel do
  @moduledoc false
  use Phoenix.Channel
  alias Garuda.MatchMaker.Matcher

  def join("garuda_matchmaker:lobby", match_details, socket) do
    match_resp = Matcher.join_or_create(match_details)

    if Map.has_key?(match_resp, "match_id") do
      {:ok, match_resp, socket}
    else
      {:error, match_resp}
    end
  end
end
