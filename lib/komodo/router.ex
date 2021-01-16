defmodule Garuda.Komodo.Router do

  defmacro komodo(path, opts \\ []) do
    quote bind_quoted: binding() do
      scope path, alias: false, as: false do
        import Phoenix.LiveView.Router, only: [live: 4]
        "/"<>path_atom = path
        opts = Garuda.Komodo.Router.__options__(opts, path_atom)
        # live "/", Garuda.Komodo.KomodoLive, :komodo, opts
        live "/", Garuda.Monitor.OrwellDashboard, String.to_atom(path_atom), opts
      end
    end
  end

  @doc false
  def __options__(options, path_atom) do
    live_socket_path = Keyword.get(options, :live_socket_path, "/live")

    [
      session: {__MODULE__, :__session__, []},
      private: %{live_socket_path: live_socket_path},
      layout: {Garuda.Komodo.LayoutView, :dash},
      # as: :komodo
      as: String.to_atom(path_atom)
    ]
  end

  @doc false
  def __session__(_conn) do
    %{}
  end

end
