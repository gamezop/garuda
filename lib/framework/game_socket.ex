defmodule Garuda.GameSocket do
  @moduledoc """
  Defines specific game behaviours over `Phoenix.Socket`

  GameSocket extends `Phoenix.Socket` and adds needed macros and functions for defining game behaviours.

  ## Using GameSocket
  In user_socket.ex, we can do
      defmodule TictactoePhxWeb.UserSocket do
        use Garuda.GameSocket

        game_channel "tictactoe", TictactoePhxWeb.TictactoeChannel, TictactoePhx.TictactoeRoom

        @impl true
        def connect(_params, socket, _connect_info) do
          {:ok, socket}
        end

        @impl true
        def id(_socket), do: nil
      end

  You might have noticed that instead of `use Phoenix.Socket`, we are using `Garuda.GameSocket` and instead of
  `channel`, we are using `game_channel`.
  """

  defmacro __using__(_opts \\ []) do
    quote do
      import unquote(__MODULE__)
      use Phoenix.Socket
      Phoenix.Socket.channel("garuda_matchmaker:*", Garuda.Matchmaker.MatchmakerChannel)
      Phoenix.Socket.channel("garuda_neo_matchmaker:*", Garuda.NeoMatcherChannel)

      def connect(params, socket, _connect_info) do
        IO.puts("connect params - #{inspect(params)}")
        {:ok, assign(socket, :player_id, params["playerId"])}
      end
    end
  end

  @doc """
  Defines a game channel matching the given game-channel name.
    * `channel_name` - A game-channel name as string, ex "tictactoe"
    * `channel_module` - The game-channel module handler, ex `TictactoePhxWeb.TictactoeChannel`
    * `game_room_module` - The game-room module handler, where core game logic resides, ex `TictactoePhx.TictactoeRoom`

  ## Example
      game_channel "tictactoe", TictactoePhxWeb.TictactoeChannel, TictactoePhx.TictactoeRoom
  """
  defmacro game_channel(channel_name, channel_module, room_module) do
    quote do
      Phoenix.Socket.channel("room_" <> unquote(channel_name) <> ":*", unquote(channel_module),
        assigns: %{"#{unquote(channel_name)}_room_module" => unquote(room_module)}
      )
    end
  end
end
