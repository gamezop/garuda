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
  @callback leave(player_id :: String.t(), game_state :: term()) :: {:ok, game_state :: term()}
  defmacro __using__(opts \\ []) do
    quote do
      @behaviour unquote(__MODULE__)
      import unquote(__MODULE__)
      @g_room_expiry Keyword.get(unquote(opts), :expiry) || 10_800_000
      @g_reconnection_time Keyword.get(unquote(opts), :reconnection_timeout) || 20_000

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
        game_state =
          case reason do
            {:shutdown, :left} ->
              IO.puts("player left, explicitly")
              RoomDb.on_player_leave(self(), player_id)
              {:ok, game_state} = apply(__MODULE__, :leave, [player_id, game_state])
              game_state

            _ ->
              IO.puts("player left, non-explicitly, will wait")

              timer_ref =
                Process.send_after(
                  self(),
                  {"reconnection_timeout", player_id},
                  @g_reconnection_time
                )

              RoomDb.update_timer_ref(self(), player_id, timer_ref)
              game_state
          end

        {:reply, "ok", game_state}
      end

      @impl true
      def handle_call({"on_rejoin", player_id}, _from, game_state) do
        timer_ref = RoomDb.get_timer_ref(self(), player_id)
        IO.puts(inspect(timer_ref))

        if is_reference(timer_ref) do
          _resp = Process.cancel_timer(timer_ref)
          RoomDb.update_timer_ref(self(), player_id, true)
          IO.puts("Timer Cleared!! => #{player_id}")
        end

        {:reply, "ok", game_state}
      end

      @impl true
      def handle_info("expire_room", game_state) do
        {:stop, {:shutdown, "room_expired"}, game_state}
      end

      @impl true
      def handle_info({"reconnection_timeout", player_id}, game_state) do
        case RoomDb.has_rejoined(self(), player_id) do
          true ->
            IO.puts("Player rejoined, dont kick him out")
            RoomDb.update_timer_ref(self(), player_id, true)
            {:noreply, game_state}

          _ ->
            IO.puts("Player kicked out explcitly on timeout => #{player_id}")
            RoomDb.on_player_leave(self(), player_id)
            {:ok, game_state} = apply(__MODULE__, :leave, [player_id, game_state])
            {:noreply, game_state}
        end
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
