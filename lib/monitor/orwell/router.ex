defmodule Garuda.Monitor.Router do
  defmacro monitor(path, opts \\ []) do
    quote bind_quoted: binding() do
      scope path, alias: false, as: false do
        import Phoenix.LiveView.Router, only: [live: 4]
        "/" <> path_atom = path
        opts = Garuda.Monitor.Router.__options__(opts, path_atom)
        live("/", Garuda.Monitor.OrwellDashboard, String.to_atom(path_atom), opts)
      end
    end
  end

  @doc false
  def __options__(options, path_atom) do
    live_socket_path = Keyword.get(options, :live_socket_path, "/live")

    [
      session: {__MODULE__, :__session__, []},
      private: %{live_socket_path: live_socket_path},
      layout: {Garuda.Orwell.LayoutView, :dash},
      as: String.to_atom(path_atom)
    ]
  end

  @doc false
  def __session__(_conn) do
    %{}
  end
end
