defmodule Garuda.Monitor.Router do
  defmacro monitor(path, opts \\ []) do
    quote bind_quoted: binding() do
      scope path, alias: false, as: false do
        import Phoenix.LiveView.Router
        "/" <> path_atom = path
        opts = Garuda.Monitor.Router.__options__(opts, path_atom)
        live_socket_path = Keyword.get(opts, :live_socket_path, "/live")

        live_opts = [
          # session: {__MODULE__, :__session__, []},
          private: %{live_socket_path: live_socket_path},
          # layout: {Garuda.Orwell.LayoutView, :dash},
          as: String.to_atom(path_atom)
        ]

        live_session :default, opts do
          live("/", Garuda.Monitor.OrwellDashboard, String.to_atom(path_atom), live_opts)
        end
      end
    end
  end

  @doc false
  def __options__(options, path_atom) do
    [
      session: {__MODULE__, :__session__, []},
      # private: %{live_socket_path: live_socket_path},
      root_layout: {Garuda.Orwell.LayoutView, :dash}
      # as: String.to_atom(path_atom)
    ]
  end

  @doc false
  def __session__(_conn) do
    %{}
  end
end
