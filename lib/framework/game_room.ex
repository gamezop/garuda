defmodule Garuda.GameRoom do
  @moduledoc """
    Behaviours and functions for implementing core game logic rooms
  """
  alias Garuda.RoomManager.RoomDb

  defmacro __using__(_opts \\ []) do
    quote do
      import unquote(__MODULE__)
      use GenServer, restart: :transient

      def start_link(name: name, opts: opts) do
        result = GenServer.start_link(__MODULE__, opts, name: name)

        case result do
          {:ok, child} ->
            Process.send_after(Garuda.RoomManager.RoomSheduler, {:room_started, child, opts}, 5)

          # {:error, {:already_started, child}} -> Process.send_after(Garuda.RoomManager.RoomSheduler, {
          # :room_join, child, opts})
          {:error, error} ->
            IO.puts("Room creation Failed due to #{inspect(error)}")

          _ ->
            IO.puts("Error")
        end

        result
      end

      def handle_cast(:dispose_room, state) do
        {:stop, {:shutdown, "Disposing room"}, state}
      end

      def get_channel do
        RoomDb.get_channel_name(self())
      end
    end
  end
end
