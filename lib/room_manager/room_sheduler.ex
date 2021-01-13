defmodule Garuda.RoomManager.RoomSheduler do
  @moduledoc """
  Monitors game-rooms and orchestrates communication between other room components, game-channels etc.

  Main RoomSheduler tasks
    * Monitor all the game-rooms that are created by the dynamic supervisors.
    * Load-balancing the dynamic supervisors.
    * Interface between monitor dashboard and RoomDb, (See `Garuda.RoomManager.RoomDb`).
    * Interface between game-rooms and RoomDb.

  Basically RoomSheduler is the bridge between the game rooms and other core components
  such as Monitor(`Garuda.Monitor`), Matchmaker(`Garuda.Matchmaker`) and RoomDb.
  """

  use GenServer
  alias Garuda.RoomManager
  alias Garuda.RoomManager.Records
  alias Garuda.RoomManager.RoomDb

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Assign an available dynamic supervisor to create and supervise the given game-room.
    * room_module - The game-room module handler.
    * room_id     - Unique id of the game-room.
    * opts        - Extra options for the game-room.
  """
  def create_room(room_module, room_id, opts) do
    GenServer.call(__MODULE__, {"create_room", room_module, room_id, opts})
  end

  # BREAKING => dispose room now accepts room_name instead of room_pid, this will break
  # the orwell dashboard's dispose room functionality.
  @doc """
  Dispose a game-room, with a given room_name.
    * room_name - unique game-room name, that should be disposed.
  """
  def dispose_room(room_name) do
    GenServer.call(__MODULE__, {"dispose_room", room_name})
  end

  @impl true
  def init(_opts) do
    state = generate_sheduler_state()
    {:ok, state, {:continue, :initialize}}
  end

  @impl true
  def handle_continue(:initialize, state) do
    {:noreply, run_init_sheduler(state)}
  end

  @impl true
  def handle_call({"create_room", room_module, room_id, opts}, _from, state) do
    {status, state} = create_game_room(room_module, room_id, opts, state)
    {:reply, status, state}
  end

  @impl true
  def handle_call({"dispose_room", room_name}, _from, state) do
    room_pid = Records.via_tuple(room_name)

    if Records.is_process_registered(room_pid) do
      GenServer.call(room_pid, "dispose_room")
    end

    {:reply, "ok", state}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, object, _reason}, state) do
    # Handles the termination of a game room, by deleting it from RoomDb.
    # object is pid
    RoomDb.delete_room(object)
    {:noreply, state}
  end

  # Creates an initial state for sheduler
  defp generate_sheduler_state do
    %{
      # available for load-balancing next time.
      available_supervisors: [],
      # current load limit per supervisor
      load_limit: 5,
      # All supervisor info list
      supervisors: []
    }
  end

  # Filter out the other worker children from the children list of RoomManager,
  # and returns on;y supervisors as list

  defp get_supervisor_list do
    Supervisor.which_children(RoomManager)
    |> Enum.filter(fn {_name, _pid, type, _module} -> type == :supervisor end)
    |> Enum.map(fn {name, _pid, _type, _module} -> name end)
  end

  # Prepare the active supervisor list for load-balancing
  defp run_init_sheduler(state) do
    supervisors = get_supervisor_list()
    %{state | supervisors: supervisors, available_supervisors: supervisors}
  end

  # Returns {avaialble_supervisor, current_sheduler_state}
  defp get_available_supervisor(state) do
    # load balancing
    state = shedule_supervisor(state.available_supervisors, state)
    {List.first(state.available_supervisors), state}
  end

  # Returns the sheduler state with updated load and available supervisor list.
  defp shedule_supervisor([], %{load_limit: load_limit} = state) do
    # Reset with static supervisor list, with increased load.
    supervisors = state.supervisors
    %{state | available_supervisors: supervisors, load_limit: load_limit + 5}
  end

  defp shedule_supervisor([h | t] = available_supervisors, state) do
    %{active: child_count} = DynamicSupervisor.count_children(h)

    if child_count < state.load_limit do
      %{state | available_supervisors: available_supervisors}
    else
      shedule_supervisor(t, state)
    end
  end

  # Finds an available dynamic supervisor and assign delegate that to create the given game-room.
  defp create_game_room(room_module, room_id, opts, state) do
    {supervisor, state} = get_available_supervisor(state)

    result =
      DynamicSupervisor.start_child(
        supervisor,
        {room_module, name: Records.via_tuple(room_id), opts: opts}
      )

    entry_status =
      case result do
        {:ok, child} ->
          on_game_room_start(child, opts)

        {:error, {:already_started, child}} ->
          RoomDb.on_room_join(child, opts)

        {:error, error} ->
          IO.puts("Room creation Failed due to #{inspect(error)}")
          "error"

        _ ->
          IO.puts("Error")
          "error"
      end

    {entry_status, state}
  end

  defp on_game_room_start(pid, opts) do
    # Handles the creation of a game room
    room_id = Keyword.get(opts, :room_id)
    player_id = Keyword.get(opts, :player_id)
    [room_name, match_id] = String.split(room_id, ":")
    add_room_to_state(pid, room_name, match_id, player_id)
    "ok"
  end

  # Monitors the game room and send the room-state to RoomDb.
  defp add_room_to_state(room_pid, room_name, match_id, player_id) do
    ref = Process.monitor(room_pid)

    _resp =
      RoomDb.save_init_room_state(room_pid, %{
        "ref" => ref,
        "room_name" => room_name,
        "match_id" => match_id,
        "players" => %{player_id => true},
        "time" => :os.system_time(:milli_seconds)
      })
  end
end
