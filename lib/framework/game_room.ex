defmodule Garuda.GameRoom do
  @moduledoc """
  Behaviours and functions for implementing core game-logic rooms.

  Game-logic rooms are under-the-hood genservers, with certain extra properties.

  ## Using GameRoom
      defmodule TictactoePhx.TictactoeRoom do
        use Garuda.GameRoom, expiry: 120_000
        def create(_opts) do
          # Return the initial game state.
          gamestate
        end
      end
  ## Other available functions
  ### get_channel
  Returns the corresponding game-channel of the game-room
  Useful when we want to broadcast to the game-channel from game-rooms.
  ### shutdown
  Shutdowns the game-room gracefully.
  Its recommended to shutdown the game-room, when we know, game-rooms are empty,
  and will not be used further.
  ## Options
  * expiry - expires the game-room in given milliseconds, default to 3hr.
  """
  alias Garuda.RoomManager.RoomDb

  @doc """
  Entry point for the game-room.
  `create` replaces `init` of genserver.
  `opts` available currently are `:room_id` and `:player_id`
  We can setup the inital gamestate by returning `game_state` from `create`,
  where `game_state` is any erlang term.

  Note: `create` is called only once.
  """
  @callback create(opts :: term()) :: game_state :: term()

  defmacro __using__(opts \\ []) do
    quote do
      @behaviour unquote(__MODULE__)
      import unquote(__MODULE__)
      @g_room_expiry Keyword.get(unquote(opts), :expiry) || 10_800_000
      use GenServer, restart: :transient

      def start_link(name: name, opts: opts) do
        result = GenServer.start_link(__MODULE__, opts, name: name)
      end

      @impl true
      def init(init_opts) do
        Process.send_after(self(), "expire_room", @g_room_expiry)
        {:ok, nil, {:continue, {"create", init_opts}}}
      end

      @impl true
      def handle_continue({"create", init_opts}, state) do
        game_state = apply(__MODULE__, :create, [init_opts])
        {:noreply, game_state}
      end

      @impl true
      def handle_call("dispose_room", _from, game_state) do
        {:stop, {:shutdown, "Disposing room"}, "ok", game_state}
      end

      @impl true
      def handle_call({"on_channel_leave", player_id, reason}, _from, game_state) do
        RoomDb.on_player_leave(self(), player_id)
        {:reply, "ok", game_state}
      end

      @impl true
      def handle_info("expire_room", game_state) do
        {:stop, {:shutdown, "room_expired"}, game_state}
      end

      @impl true
      def terminate(reason, _game_state) do
        RoomDb.delete_room(self())
      end

      @doc """
      Returns the corresponding game-channel of the game-room
      """
      def get_channel do
        RoomDb.get_channel_name(self())
      end

      @doc """
      Shutdowns the game-room gracefully.
      """
      def shutdown(game_state) do
        send(self(), "expire_room")
      end
    end
  end
end
