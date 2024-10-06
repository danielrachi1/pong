defmodule PongWeb.Components.BallLive do
  use PongWeb, :live_component

  def render(assigns) do
    ~H"""
    <div
      id="ball"
      class="aspect-square h-[1.25%] bg-white"
      style={"position: absolute;left: #{@x}%; top: #{@y}%"}
    >
    </div>
    """
  end
end
