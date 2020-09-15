defmodule Garuda.Monitor do
  @moduledoc false
  defmacro __using__(_options) do
    quote do
      scope "/" do
        pipe_through :browser
        live "/monitor", Garuda.Monitor.OrwellDashboard
      end
    end
  end

end
