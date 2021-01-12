defmodule Garuda.Matchmaker.MatchmakerSupervisor do
  @moduledoc """
  Supervises the core matchmaking process
  """

  use Supervisor
  alias Garuda.MatchMaker.Matcher

  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    children = [
      Matcher
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
