defmodule Garuda.GameManager do
  @moduledoc """
  The root supervisor for all Garuda components.

  Basically we have to add this supervisor module to the `application.ex` of
  a Phoenix project as a child inside the start function, to get Garuda running/flying.

  ## Options
    * `:max_sup` - Maximum Dynamic supervisors that should be created, default 5.

  ## Usage
  Add like below, if we dont want to pass extra options.
      Garuda.GameManager
  or, we have to add GameManager like,
      {Garuda.GameManager, max_sup: 10}
  """
  alias Garuda.Matchmaker.MatchmakerSupervisor
  alias Garuda.RoomManager

  use Supervisor

  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(opts) do
    children = [
      Supervisor.child_spec({RoomManager, opts}, type: :supervisor),
      Supervisor.child_spec(MatchmakerSupervisor, type: :supervisor),
      {Registry, keys: :unique, name: GarudaRegistry}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
