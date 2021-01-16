defmodule Garuda.GameChannel do
  @moduledoc """
  Defines specific game behaviours over `Phoenix.Channel`.

  GameChannel extends `Phoenix.Channel` and adds needed macros and functions for defining game-behaviours.

  ## Using GameChannel
      defmodule TictactoePhxWeb.TictactoeChannel do
        use Garuda.GameChannel

        def on_join(_params, _socket) do
          IO.puts("Player Joined")
        end

        @impl true
        def authorized?(_params) do
          # Custom authorization code
          true
        end

        @impl true
        def on_leave(reason, _socket) do
          IO.puts("Leaving tictactoe channel")
        end
      end

  You might have noticed that instead of `use Phoenix.Channel`, we are using `Garuda.GameChannel`.
  """
  alias Garuda.RoomManager.Records

  @callback on_join(params :: map, socket :: Phoenix.Socket) :: any()
  @callback on_rejoin(params :: map, socket :: Phoenix.Socket) :: any()
  @callback authorized?(params :: map()) :: boolean
  defmacro __using__(opts \\ []) do
    quote do
      @behaviour unquote(__MODULE__)
      import unquote(__MODULE__)
      use Phoenix.Channel
      require Logger
      alias Garuda.RoomManager.RoomDb
      alias Garuda.RoomManager.RoomSheduler

      def join("room_" <> room_id, params, socket) do
        if apply(__MODULE__, :authorized?, [params]) do
          _resp = RoomDb.on_channel_connection(socket.channel_pid, %{})

          if Keyword.get(unquote(opts), :log) do
            Logger.metadata(room_id: room_id)
          end

          [room_name, match_id] = String.split(room_id, ":")

          status =
            RoomSheduler.create_room(socket.assigns["#{room_name}_room_module"], room_id,
              room_id: room_id,
              player_id: socket.assigns.player_id,
              max_players: params["max_players"]
            )

          case status do
            "ok" ->
              send(self(), {"garuda_after_join", params})
              {:ok, socket}

            "already_exists" ->
              send(self(), {"garuda_after_rejoin", params})
              {:ok, socket}

            _ ->
              {:error, %{reason: "No room exists"}}
          end
        else
          {:error, %{reason: "unauthorized"}}
        end
      end

      def handle_info({"garuda_after_join", params}, socket) do
        apply(__MODULE__, :on_join, [params, socket])
        {:noreply, socket}
      end

      def handle_info({"garuda_after_rejoin", params}, socket) do
        if Records.is_process_registered(get_room_id(socket)) do
          GenServer.call(id(socket), {"on_rejoin", socket.assigns.player_id})
        end

        apply(__MODULE__, :on_rejoin, [params, socket])
        {:noreply, socket}
      end

      def terminate(reason, socket) do
        RoomDb.on_channel_terminate(socket.channel_pid)

        if Records.is_process_registered(get_room_id(socket)) do
          GenServer.call(id(socket), {"on_channel_leave", socket.assigns.player_id, reason})
        end
      end
    end
  end

  @doc """
  Returns the via tuple of process from Registry
    * socket - socket state of game-channel
  """
  def id(socket) do
    [_namespace, room_id] = String.split(socket.topic, "_")
    Records.via_tuple(room_id)
  end

  @doc """
  Returns the internal id of game-room
    * socket - socket state of game-channel
  """
  @spec get_room_id(map()) :: String.t()
  def get_room_id(socket) do
    [_namespace, room_id] = String.split(socket.topic, "_")
    room_id
  end

  @doc """
  Returns the room name of game-room
    * socket - socket state of game-channel
  """
  @spec get_room_name(map()) :: String.t()
  def get_room_name(socket) do
    [_namespace, room_id] = String.split(socket.topic, "_")
    [room_name, _match_id] = String.split(room_id, ":")
    room_name
  end
end
