defmodule Garuda.Matchmaker.MatchmakerSupervisor do
  @moduledoc """
    Supervises the core room components

    Core room components are dynamic game supervisors, roomSheduler and roomDb.

    RoomSupervisor creates and supervises all the dynamic supervisors, which in turn
    supervises the actual game rooms.
  """

  use Supervisor
  alias Garuda.Matchmaker.MatchmakerFunction
  alias Garuda.NeoMatcher.Matcher

  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    children = [
      MatchmakerFunction,
      Matcher
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
