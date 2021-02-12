# Server

This section contains the details on how to use Garuda for our games in phoenix.

## Matchmaking system
  Matchmaking system is inbuilt into the core, so developers doesn't have to know any api to work with it. For every room created, Garuda will create a unique matchId for it. If we have to use custom matchId, then we can specify it from [client side](client.html).
## Framework system
  Framework has 3 parts
  - [GameSocket](Garuda.GameSocket.html) - Extends [Phoenix.Socket](https://hexdocs.pm/phoenix/Phoenix.Socket.html) with extra game behaviours.
  - [GameChannel](Garuda.GameChannel.html) - Extends [Phoenix.Channel](https://hexdocs.pm/phoenix/Phoenix.Channel.html) with extra game behaviours.
  - [GameRoom](Garuda.GameRoom.html) - Extends [GenServer](https://hexdocs.pm/elixir/GenServer.html) with extra game behaviours.



#### GameSocket
 In `user_socket.ex`, we can do
      defmodule TictactoePhxWeb.UserSocket do
        use Garuda.GameSocket
        game_channel "tictactoe", TictactoePhxWeb.TictactoeChannel, TictactoePhx.TictactoeRoom
      end
 Here we replaced `use Phoenix.Socket` with `use Garuda.GameSocket`. Also we have to 
 remove the `connect/3`, which we normally use in `user_socket.ex`, GameSocket module will take care of that.

 On the third line of above code snippet, we are mapping our socket events.
 We are specifying the name of our game, the GameChannel (where we handle the events), and the GameRoom where the core gameplay logic should happen.
 For more details, go through [GameSocket](Garuda.GameSocket.html) module.

#### GameChannel
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
 Here we replaced `use Phoenix.Channel` with `use Garuda.GameChannel`.
 GameChannel works exactly like Phoenix Channel. We don't have to use `join/3`.
 Instead there are 3 mandatory callbacks, `on_join/2` (calls when player is authenticated and joins the channel), `authorized?/1` (custom authorization), `on_rejoin/2`(when player rejoins the game, after a short delay).

 We can use all the other callbacks in phoenix channels, here too. Like `handle_in/3`, `handle_out/3` etc.

 For more details, go through [GameChannel](Garuda.GameChannel.html) module.
#### GameRoom
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

  GameRooms are extended genservers, where our core gameplay logic resides.
  We don't have to use Genserver functions like `start_link/3` or `init/2`.
  `init/2` is replaced by `create/1`. Rest everything works like genserver.
  For more detauls, go through [GameRoom](Garuda.GameRoom.html)
## Monitoring system
Real-time monitoring of game-server is first-class in Garuda.
Configuring monitoring is covered here, [Realtime-monitoring](monitoring.html)
