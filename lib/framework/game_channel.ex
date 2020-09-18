defmodule Garuda.GameChannel do
  @moduledoc """
    Phoenix Channels abstractions, game specific behaviours and functions
  """
  alias Garuda.RoomManager.Records

  @callback on_join(params :: map, socket :: Phoenix.Socket) :: any()
  @callback authorized?(params :: map()) :: boolean
  @callback on_leave(
              reason :: :normal | :shutdown | {:shutdown, :left | :closed | term()},
              socket :: Phoenix.Socket
            ) :: any()
  defmacro __using__(_opts \\ []) do
    quote do
      @behaviour unquote(__MODULE__)
      import unquote(__MODULE__)
      use Phoenix.Channel
      alias Garuda.RoomManager.RoomDb
      alias Garuda.RoomManager.RoomSheduler

      def join("room_" <> room_id, params, socket) do
        if apply(__MODULE__, :authorized?, [params]) do
          # Process.send_after(self(), {"after_join", params}, 50)
          RoomDb.on_channel_connection(socket.channel_pid, %{})

          socket = apply(unquote(__MODULE__), :setup_socket_state, [room_id, socket])

          RoomSheduler.create_room(
            socket.assigns.game_room_module,
            socket.assigns.garuda_game_room_id,
            game_room_id: socket.assigns.garuda_game_room_id
          )

          apply(__MODULE__, :on_join, [params, socket])
          {:ok, socket}
        else
          {:error, %{reason: "unauthorized"}}
        end
      end

      def handle_info({"after_join", params}, socket) do
        # RoomSheduler.create_room(
        #   socket.assigns.game_room_module,
        #   socket.assigns.garuda_game_room_id,
        #   game_room_id: socket.assigns.garuda_game_room_id
        # )

        # apply(__MODULE__, :on_join, [params, socket])
        {:noreply, socket}
      end

      def terminate(reason, socket) do
        RoomDb.on_channel_terminate(socket.channel_pid)
        apply(__MODULE__, :on_leave, [reason, socket])
      end
    end
  end

  @doc """
    Sets the basic room properties in socket's memory
    Expects the room_id (basically game roomid) in a pattern like "room_name:match_id"
  """
  def setup_socket_state(room_id, socket) do
    [room_name, match_id] = String.split(room_id, ":")

    Phoenix.Socket.assign(socket, :garuda_room_name, room_name)
    |> Phoenix.Socket.assign(:garuda_match_id, match_id)
    |> Phoenix.Socket.assign(:garuda_game_room_id, room_id)
  end

  @doc """
    Returns the via tuple of process from registry
    Expects channel socket
  """
  def id(socket) do
    Records.via_tuple(socket.assigns.garuda_game_room_id)
  end
end
