defmodule Garuda.RoomManager do
  @moduledoc """
  Create and supervise the core room components.

  The Core room components are,
    * DynamicSupervisors - Creates and supervises game-rooms. See `DynamicSupervisor`
    * RoomSheduler - Shedules the DynamicSupervisors, monitor the game-rooms etc. See `Garuda.RoomManager.RoomSheduler`
    * RoomDb - Stores the info regarding the game-rooms. See `Garuda.RoomManager.RoomDb`.

  RoomManager creates and supervises all the dynamic supervisors, which in turn
  supervises the actual game rooms.

  No:of dynamic supervisors used in the game server can be configured by
  adding `:max_sup` while starting GameManager. See `Garuda.GameManager`.
  """

  use Supervisor
  alias Garuda.RoomManager.RoomDb
  alias Garuda.RoomManager.RoomSheduler

  @default_dynamic_supervisors 5

  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    children =
      [
        create_dynamic_supervisors(Keyword.get(opts, :max_sup, @default_dynamic_supervisors)),
        {RoomSheduler, []},
        {RoomDb, []}
      ]
      |> List.flatten()

    create_room_ets()
    Supervisor.init(children, strategy: :one_for_one)
  end

  # Creates dynamic supervisors according to the `max_sup` config.
  defp create_dynamic_supervisors(max_dynamic_sup) do
    for count <- 1..max_dynamic_sup do
      {DynamicSupervisor, strategy: :one_for_one, name: :"dynamic_sup_#{count}"}
    end
  end

  defp create_room_ets do
    # public, but apis are through RoomDb module
    :ets.new(:room_db, [:public, :named_table])
    :ets.insert(:room_db, {"channels", %{}})
  end
end
