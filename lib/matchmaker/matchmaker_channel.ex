defmodule Garuda.MatchMakerChannel do
  @moduledoc false
  use Phoenix.Channel
  alias Garuda.MatchMaker.Matcher

  def join("garuda_matchmaker:lobby", match_details, socket) do
    match_id = Matcher.join_or_create(match_details)
    {:ok, %{"match_id" => match_id}, socket}
  end
end
