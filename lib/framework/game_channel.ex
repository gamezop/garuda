defmodule Garuda.GameChannel do
  @moduledoc """
  Defines specific game behaviours over `Phoenix.Channel`.

  GameChannel extends `Phoenix.Channel` and defines game-behaviours.

  ## Using GameChannel
      defmodule TictactoePhxWeb.TictactoeChannel do
        use Garuda.GameChannel

        @impl true
        def on_join(_params, _socket) do
          IO.puts("Player Joined")
        end

        @impl true
        def on_rejoin(_params, _socket) do
          IO.puts("Player rejoined")
        end

        @impl true
        def authorized?(_params) do
          # Custom authorization code
          true
        end

        @impl true
        def handle_in("player_move", cell, socket) do
          # Handling usual events from client
          {:noreply, socket}
        end
      end

  You might have noticed that instead of `use Phoenix.Channel`, we are using `Garuda.GameChannel`.
  """
  alias Garuda.RoomManager.Records

  @doc """
  handles game-channel join.

  `on_join` is called after socket connection is established successfully.
  """
  @callback on_join(params :: map, socket :: Phoenix.Socket) :: any()

  @doc """
  handles game-channel re-join.

  Called when a player re-joins the game-channel, ex after network reconnection.
  """
  @callback on_rejoin(params :: map, socket :: Phoenix.Socket) :: any()

  @doc """
  Verifies the channel connection

  Channel connection is only established , if `authorized?`, returns true.
  `params` is the object that is send from the client.
  """
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
        [_namespace, room_id] = String.split(socket.topic, "_")

        if Records.is_process_registered(room_id) do
          GenServer.call(rid(socket), {"on_rejoin", socket.assigns.player_id})
        end

        apply(__MODULE__, :on_rejoin, [params, socket])
        {:noreply, socket}
      end

      def terminate(reason, socket) do
        RoomDb.on_channel_terminate(socket.channel_pid)
        [_namespace, room_id] = String.split(socket.topic, "_")

        if Records.is_process_registered(room_id) do
          GenServer.call(rid(socket), {"on_channel_leave", socket.assigns.player_id, reason})
        end
      end
    end
  end

  @doc """
  Returns the process id of game-room
    * socket - socket state of game-channel
  """
  def rid(socket) do
    [_namespace, room_id] = String.split(socket.topic, "_")
    Records.via_tuple(room_id)
  end
end
