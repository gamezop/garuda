defmodule Garuda.RoomManager.RoomSheduler do
  @moduledoc """
    Manages all the game rooms that are created by the dynamic supervisors.

    RoomSheduler is the bridge between the game rooms and other core components
    such as Monitor, Matchmaker and RoomDb.

    Its also does the load-balancing between the dynamic supervisors that manages the
    game room.
  """

  use GenServer
  alias Garuda.RoomManager.Records
  alias Garuda.RoomManager.RoomDb

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
    Creates the room and attach it to available dynamic supervisor
  """
  def create_room(room_module, room_name, opts) do
    GenServer.call(__MODULE__, {:create_room, room_module, room_name, opts})
  end

  def dispose_room(room_pid) do
    GenServer.cast(__MODULE__, {:dispose_room, room_pid})
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
  def handle_call({:create_room, module, room_name, opts}, _from, state) do
    state = create_game_room(module, room_name, opts, state)
    {:reply, state, state}
  end

  # TODO => Remove comments.
  @impl true
  def handle_info({:DOWN, ref, :process, object, reason}, state) do
    IO.puts("#{inspect(ref)}")
    IO.puts("#{inspect(object)}")
    IO.puts("#{inspect(reason)}")
    # Handles the termination of a game room, by deleting it from RoomDb.
    RoomDb.delete_room(object)
    {:noreply, state}
  end

  @impl true
  def handle_info({:room_started, pid, opts}, state) do
    IO.puts("room started #{inspect(pid)}")
    # Handles the creation of a game room, by adding it to the RoomDb.
    game_room_id = Keyword.get(opts, :game_room_id)
    [room_name, room_id] = String.split(game_room_id, ":")
    add_room_to_state(pid, room_name, room_id)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:dispose_room, room_pid}, state) do
    IO.puts("DISPOSING ROOM..")
    GenServer.cast(room_pid, :dispose_room)
    {:noreply, state}
  end

  # @impl true
  # def handle_info({:room_join, pid, opts}, state) do
  #   IO.puts("joined room #{inspect pid}")
  #   # Handles the creation of a game room, by adding it to the RoomDb.
  #   game_room_id = Keyword.get(opts, :game_room_id)
  #   [room_name, room_id] = String.split(game_room_id, ":")
  #   add_room_to_state(pid, room_name, room_id)
  #   {:noreply, state}
  # end

  # Creates an initial state for sheduler
  defp generate_sheduler_state() do
    %{
      # available for load-balancing next time.
      available_supervisors: [],
      # current load limit per supervisor
      load_limit: 5,
      # All supervisor info list
      supervisors: [],
      # Info about all the game rooms created , with pid as key
      rooms: %{}
    }
  end

  # Filter out the other worker children from the children list of RoomSupervisor,
  # and returns on;y supervisors as list

  defp get_supervisor_list() do
    Supervisor.which_children(Garuda.RoomManager.RoomSupervisor)
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

  # Creates the game room and add it to the supervisor.
  # TODO => Remove the comments after testing.
  # TODO => Has to revisit after doing the game room abstractions
  defp create_game_room(module, name, opts, state) do
    {supervisor, state} = get_available_supervisor(state)
    DynamicSupervisor.start_child(supervisor, {module, name: Records.via_tuple(name), opts: opts})
    state
  end

  # Monitors the game room and save the room state to RoomDb.
  defp add_room_to_state(room_pid, room_name, room_id) do
    ref = Process.monitor(room_pid)

    RoomDb.save_room_state(room_pid, %{
      "ref" => ref,
      "room_name" => room_name,
      "room_id" => room_id,
      "time" => :os.system_time(:milli_seconds)
    })
  end

  # defp update_room(room_pid) do
  #   RoomDb.
  # end
end
