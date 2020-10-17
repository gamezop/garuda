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
          RoomDb.on_channel_connection(socket.channel_pid, %{})

          [room_name, match_id] = String.split(room_id, ":")

          if Keyword.get(unquote(opts), :log) do
            Logger.metadata(match_id: match_id)
          end

          RoomSheduler.create_room(socket.assigns["#{room_name}_room_module"], room_id,
            game_room_id: room_id
          )

          Process.send_after(self(), {"garuda_on_join", params, socket}, 10)

          {:ok, socket}
        else
          {:error, %{reason: "unauthorized"}}
        end
      end

      def handle_info({"garuda_on_join", params, socket}, state) do
        apply(__MODULE__, :on_join, [params, socket])
        {:noreply, state}
      end

      def terminate(reason, socket) do
        RoomDb.on_channel_terminate(socket.channel_pid)
        # apply(socket.assigns["#{room_name}_room_module"], :on_leave, [reason])
        apply(__MODULE__, :on_leave, [reason, socket])
      end
    end
  end

  @doc """
  Returns the via tuple of process from Registry
    * socket - socket state of game-channel
  """
  def id(socket) do
    [_namespace, game_room_id] = String.split(socket.topic, "_")
    Records.via_tuple(game_room_id)
  end
end
