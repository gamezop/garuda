defmodule Garuda.RoomManager.RoomSupervisor do
  @moduledoc """
    Supervises the core room components

    Core room components are dynamic game supervisors, roomSheduler and roomDb.

    RoomSupervisor creates and supervises all the dynamic supervisors, which in turn
    supervises the actual game rooms.
  """

  use Supervisor
  alias Garuda.RoomManager.RoomDb
  alias Garuda.RoomManager.RoomSheduler

  @max_dynamic_supervisors 5

  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    children =
      create_dynamic_supervisors() ++
        [{RoomSheduler, []}] ++
        [{RoomDb, []}]

    Supervisor.init(children, strategy: :one_for_one)
  end

  # Creates dynamic supervisors according to the config
  defp create_dynamic_supervisors do
    for count <- 1..@max_dynamic_supervisors do
      {DynamicSupervisor, strategy: :one_for_one, name: :"dynamic_sup_#{count}"}
    end
  end
end
