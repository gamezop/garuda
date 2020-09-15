defmodule Garuda.Monitor.OrwellDashboard do
  @moduledoc """
  This is the module for Orwell LiveView Dashboard
  the Dashboard shows vital information from the Game Server such as,
    Number of Connection
    Number of Rooms
    Number of user per room
    Time elasped per room
    State of each room
  Also provides actions, to inspect and to delete rooms.

  This module use Phoenix Liveview to mount a template.
  Game Data is fetched from the server, and a regular update is done with handle_info callback
  """
  use Phoenix.LiveView
  require Logger
  alias Garuda.Monitor.DashboardData
  alias Garuda.RoomManager.RoomDb
  alias Garuda.RoomManager.RoomSheduler
  alias Garuda.RoomManager.Records
  @polling_interval 5_000
  @doc """
  The Mount function gathers information from Game Server and creates liveview template
  This function also sends an :update event to self, after 10 seconds
  The update is then handled in a handle_info
  """
  def mount(_params, _session, socket) do
    Logger.info("==============Running MOUNT ===================")

    # Sending event to self to poll gameserver data
    Process.send_after(self(), :update, @polling_interval)

    # Get data from Game Manager
    game_manager_data = RoomDb.get_stats()

    # assigning number of room, connections, and a list of room info to socket
    # selected_room to show inspect section
    {:ok,
     assign(socket, :connections, game_manager_data["num_conns"])
     |> assign(:num_rooms, game_manager_data["num_rooms"])
     |> assign(
       :list_rooms,
       game_manager_data["rooms"]
       |> make_list_rooms
     )
     |> assign(:selected_room_id, :none)
     |> assign(:selected_room_name, :none)
     |> assign(:room_state, "")}
  end

  @doc """
  Handles the inspect click events from template
  It sets the selected_room value in template and
  returns room state of selected_room
  """
  def handle_event("inspect", params, socket) do
    Logger.info("=======INSPECT======== #{inspect(params)}")
    Logger.info("#{inspect(socket.assigns)}")

    socket =
      assign_room_selection(
        params["name"],
        params["id"],
        socket.assigns.selected_room_name,
        socket.assigns.selected_room_id,
        socket
      )

    Logger.info("#{inspect(socket.assigns)}")

    ## Also assign the state of that room
    socket =
      assign_room_state(
        socket.assigns.selected_room_name,
        socket.assigns.selected_room_id,
        socket
      )

    Logger.info("#{inspect(socket.assigns)}")

    {:noreply, socket}
  end

  def handle_event("dispose", params, socket) do
    Logger.info("===================DISPOSE================")
    Logger.info("dispose room ..... #{inspect(params["name"])}:#{inspect(params["id"])}")
    # Logger.info "to be done...."
    game_room_id = params["name"] <> ":" <> params["id"]
    RoomSheduler.dispose_room(Records.via_tuple(game_room_id))
    {:noreply, socket}
  end

  @doc """
  This should handle the update event for polling.
  This function gather latest data from gameserver and updates it to template
  and also send a update event to self
  """
  def handle_info(:update, socket) do
    # send event to self, to continously poll the game server data
    Process.send_after(self(), :update, @polling_interval)

    game_manager_data = RoomDb.get_stats()
    Logger.info("=================UPDATE============")
    Logger.info("#{inspect(socket.assigns)}")

    # game_room_id = socket.assigns.selected_room_name <> ":" <> socket.assigns.selected_room_id
    # socket = assign(socket, :room_state, DashboardData.get_room_state(game_room_id) |> state_to_string )
    socket =
      assign_room_state(
        socket.assigns.selected_room_name,
        socket.assigns.selected_room_id,
        socket
      )

    {
      :noreply,
      assign(socket, :connections, game_manager_data["num_conns"])
      |> assign(:num_rooms, game_manager_data["num_rooms"])
      |> assign(
        :list_rooms,
        game_manager_data["rooms"]
        |> make_list_rooms
      )
    }
  end

  ####### PRIVATE

  defp assign_room_selection(new_name, new_id, new_name, new_id, soc) do
    soc = assign(soc, :selected_room_id, :none)
    assign(soc, :selected_room_name, :none)
  end

  defp assign_room_selection(new_name, new_id, _old_name, _old_id, soc) do
    soc = assign(soc, :selected_room_id, new_id)
    assign(soc, :selected_room_name, new_name)
  end

  defp assign_room_state(:none, :none, soc) do
    soc
  end

  defp assign_room_state(name, id, soc) do
    game_room_id = name <> ":" <> id
    assign(soc, :room_state, DashboardData.get_room_state(game_room_id) |> state_to_string)
  end

  defp make_list_rooms(room_map) do
    Map.keys(room_map)
    |> Enum.map(fn x ->
      room_map[x]
      |> Map.put("pid", x)
    end)
    |> Enum.map(fn x -> time_diff(x) end)
  end

  defp state_to_string(statemap) do
    Map.keys(statemap)
    |> Enum.map(fn x -> " #{x} => #{statemap[x]} " end)
    |> Enum.join(" ,\n")
  end

  defp time_diff(param_map) do
    seconds = (:os.system_time(:milli_seconds) - param_map["time"]) |> div(1000)
    Logger.info("#{inspect(seconds)}seconds")

    param_map
    |> Map.update!("time", fn _x ->
      get_time_diff_string(seconds, "*", "seconds")
      |> String.trim_leading("*")
    end)
  end

  defp get_time_diff_string(0, timestr, _units) do
    timestr
  end

  defp get_time_diff_string(diff, timestr, units) do
    case units do
      "seconds" ->
        str =
          String.replace_leading(
            timestr,
            "*",
            "*" <> Integer.to_string(rem(diff, 60)) <> " seconds"
          )

        get_time_diff_string(div(diff, 60), str, "minutes")

      "minutes" ->
        str = "*" <> Integer.to_string(rem(diff, 60)) <> " minute\(s\)"
        get_time_diff_string(div(diff, 60), str, "hours")

      "hours" ->
        str =
          String.replace_leading(
            timestr,
            "*",
            "*" <> Integer.to_string(rem(diff, 24)) <> " hour\(s\), "
          )

        get_time_diff_string(div(diff, 24), str, "days")

      "days" ->
        str = String.replace_leading(timestr, "*", Integer.to_string(diff) <> " day\(s\), ")
        [days | [hours | _minutes]] = String.split(str, ",")
        [days, hours] |> Enum.join(", ")

      _ ->
        IO.puts("not seconds")
    end
  end
end
