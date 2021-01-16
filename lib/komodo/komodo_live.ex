defmodule Garuda.Komodo.KomodoLive do

  use Phoenix.LiveView
  # ,
  #   layout: {Garuda.Komodo.LayoutView, "live.html"},
  #   container: {:div, class: "font-sans antialiased h-screen flex"}

  use Garuda.Komodo.Web, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok,socket}
  end

  @impl true
  def render(assigns) do
    ~L"""
    <h1>Hello Komodo</h1>
    """
  end
end
