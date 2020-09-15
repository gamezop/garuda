defmodule Garuda.GameSocket do
  @moduledoc """
    Injects specific game behaviours in user_socket.ex
  """

  defmacro __using__(_opts \\ []) do
    quote do
      import unquote(__MODULE__)
      use Phoenix.Socket
      Phoenix.Socket.channel("garuda_matchmaker:*", Garuda.Matchmaker.MatchmakerChannel)
    end
  end

  @doc """
    Defines a game channel

    Expects a user specified game room name and associated module
  """
  defmacro game_channel(channel_name, channel_module, game_room_module) do
    quote do
      Phoenix.Socket.channel("room_" <> unquote(channel_name) <> ":*", unquote(channel_module),
        assigns: %{game_room_module: unquote(game_room_module)}
      )
    end
  end
end
