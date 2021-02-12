defmodule Garuda.Monitor.OrwellDashboard do
  @moduledoc false
  use Phoenix.LiveView
  require Logger
  alias Garuda.RoomManager.RoomDb
  alias Garuda.RoomManager.RoomSheduler
  @polling_interval 5_000

  def mount(_params, _session, socket) do
    Process.send_after(self(), "update", @polling_interval)
    stats = RoomDb.get_stats()

    {:ok,
     assign(socket, :connections, stats["channel_count"])
     |> assign(:num_rooms, stats["room_count"])
     |> assign(
       :list_rooms,
       stats["rooms"]
       |> make_list_rooms
     )
     |> assign(:selected_room_id, :none)
     |> assign(:selected_room_name, :none)
     |> assign(:room_state, "")}
  end

  @doc """
  Sets the selected_room value in template and
  returns room state of selected_room
  """
  def handle_event("inspect", params, socket) do
    socket =
      assign_room_selection(
        params["name"],
        params["id"],
        socket.assigns.selected_room_name,
        socket.assigns.selected_room_id,
        socket
      )

    socket =
      assign_room_state(
        socket.assigns.selected_room_name,
        socket.assigns.selected_room_id,
        socket
      )

    {:noreply, socket}
  end

  def handle_event("dispose", params, socket) do
    room_id = params["name"] <> ":" <> params["id"]
    RoomSheduler.dispose_room(room_id)
    {:noreply, socket}
  end

  @doc """
  Polls the roomDb every @polling_interval seconds
  """
  def handle_info("update", socket) do
    Process.send_after(self(), "update", @polling_interval)

    stats = RoomDb.get_stats()

    socket =
      assign_room_state(
        socket.assigns.selected_room_name,
        socket.assigns.selected_room_id,
        socket
      )

    {
      :noreply,
      assign(socket, :connections, stats["channel_count"])
      |> assign(:num_rooms, stats["room_count"])
      |> assign(
        :list_rooms,
        stats["rooms"]
        |> make_list_rooms
      )
    }
  end

  ####### Helper ########

  defp assign_room_selection(new_name, new_id, new_name, new_id, socket) do
    socket = assign(socket, :selected_room_id, :none)
    assign(socket, :selected_room_name, :none)
  end

  defp assign_room_selection(new_name, new_id, _old_name, _old_id, socket) do
    socket = assign(socket, :selected_room_id, new_id)
    assign(socket, :selected_room_name, new_name)
  end

  defp assign_room_state(:none, :none, socket) do
    socket
  end

  defp assign_room_state(name, id, socket) do
    room_id = name <> ":" <> id
    assign(socket, :room_state, RoomDb.get_room_state(room_id) |> state_to_string)
  end

  defp make_list_rooms(room_list) do
    # Map.keys(room_map)
    # |> Enum.map(fn x ->
    #   room_map[x]
    #   |> Map.put("pid", x)
    # end)
    # |>
    room_list
    |> Enum.map(fn data -> time_diff(data) end)
  end

  defp state_to_string(statemap) do
    Jason.encode!(statemap, pretty: true)
  end

  defp time_diff(room_stats) do
    seconds = (:os.system_time(:milli_seconds) - room_stats["time"]) |> div(1000)

    room_stats
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
