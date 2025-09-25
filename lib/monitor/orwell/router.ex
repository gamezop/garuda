defmodule Garuda.Monitor.Router do
  defmacro monitor(path, opts \\ []) do
    quote bind_quoted: binding() do
      scope path, alias: false, as: false do
        import Phoenix.LiveView.Router, only: [live: 3, live_session: 3]

        "/" <> path_atom = path
        opts = Garuda.Monitor.Router.__options__(opts, path_atom)

        live_session String.to_atom(path_atom),
          # private: %{live_socket_path: opts[:live_socket_path]},
          layout: opts[:layout],
          on_mount: [{Garuda.Monitor.Router, :set_session}] do

          live("/", Garuda.Monitor.OrwellDashboardLive, :index)
        end
      end
    end
  end

  @doc false
  def __options__(options, path_atom) do
    live_socket_path = Keyword.get(options, :live_socket_path, "/live")

    [
      live_socket_path: live_socket_path,
      layout: {Garuda.Orwell.LayoutView, :dash},
      as: String.to_atom(path_atom)
    ]
  end

  # replaces the old `:session` callback
  def on_mount(:set_session, _params, _session, socket) do
    {:cont, socket}
  end
end
