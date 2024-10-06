defmodule PongWeb.Components.PlayerLive do
  use PongWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <div
      id="player"
      class="bg-white w-[1%] h-[20%] fixed top-0 left-0"
      style={"left: 6.25%; top: #{@y}%"}
      phx-hook="TrackClientCursor"
    >
    </div>
    """
  end
end
