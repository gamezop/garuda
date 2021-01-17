defmodule Garuda.GameRoom do
  @moduledoc """
  Behaviours and functions for implementing core game-logic rooms.

  Game-rooms are under-the-hood genservers, with certain extra gamey properties.
  We can write our gameplay code in game-room, and game-channel act as event handler.
  Events from game-channel can be then route to corresponding game-room functions.

  ## Using GameRoom
      defmodule TictactoePhx.TictactoeRoom do
        use Garuda.GameRoom, expiry: 120_000
        def create(_opts) do
          # Return the initial game state.
          gamestate
        end

        def leave(player_id, game_state) do
          # handle player leaving.
          {:ok, gamestate}
        end
      end
  ## Options
    * expiry - game-room will shutdown itself after given time(ms). Default 3hr
    * reconnection_timeout - Time game-room will wait for a player who left non-explicitly. Default 20s
  """
  alias Garuda.RoomManager.RoomDb

  @doc """
  create the game-room.

  We can setup the inital gamestate by returning game_state, where game_state is any erlang term.
  Note: `create` is called only once.
  """
  @callback create(opts :: term()) :: game_state :: term()
  @doc """
  Handle player leaving.

  We can handle the gamestate, when a player leaves.
  """
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
              RoomDb.on_player_leave(self(), player_id)
              {:ok, game_state} = apply(__MODULE__, :leave, [player_id, game_state])
              game_state

            _ ->
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

        if is_reference(timer_ref) do
          _resp = Process.cancel_timer(timer_ref)
          RoomDb.update_timer_ref(self(), player_id, true)
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
            RoomDb.update_timer_ref(self(), player_id, true)
            {:noreply, game_state}

          _ ->
            RoomDb.on_player_leave(self(), player_id)
            {:ok, game_state} = apply(__MODULE__, :leave, [player_id, game_state])
            {:noreply, game_state}
        end
      end

      @impl true
      def terminate(reason, _game_state) do
        RoomDb.delete_room(self())
      end
    end
  end

  @doc """
  Returns the corresponding game-channel of the game-room.

  We can broadcast to game-channel from game-room itself like,

  `DingoWeb.Endpoint.broadcast!(get_channel(), "line_counts", %{"msg" => "heelp"})`

  """
  def get_channel do
    RoomDb.get_channel_name(self())
  end

  @doc """
  Shutdowns the game-room gracefully.
  """
  def shutdown do
    send(self(), "expire_room")
  end
end
