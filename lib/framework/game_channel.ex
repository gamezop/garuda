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
          RoomDb.on_channel_connection(socket.channel_pid, %{})

          [room_name, match_id] = String.split(room_id, ":")

          socket = Phoenix.Socket.assign(socket, :garuda_room_name, room_name)
          |> Phoenix.Socket.assign(:garuda_match_id, match_id)
          |> Phoenix.Socket.assign(:garuda_game_room_id, room_id)

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

      def terminate(reason, socket) do
        RoomDb.on_channel_terminate(socket.channel_pid)
        apply(__MODULE__, :on_leave, [reason, socket])
      end
    end
  end

  @doc """
  Returns the via tuple of process from Registry
    * socket - socket state of game-channel
  """
  def id(socket) do
    Records.via_tuple(socket.assigns.garuda_game_room_id)
  end
end
