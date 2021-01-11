defmodule Garuda.MatchMakerChannel do
  @moduledoc """
  Prototype channel for neomatcher
  """
  use Phoenix.Channel

  alias Garuda.MatchMaker.Matcher

  def join("garuda_neo_matchmaker:lobby", match_details, socket) do
    IO.puts(inspect(match_details))
    match_id = Matcher.join_or_create(match_details)
    {:ok, match_id, socket}
  end
end
