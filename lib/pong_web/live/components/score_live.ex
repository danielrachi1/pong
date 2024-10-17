defmodule PongWeb.Components.ScoreLive do
  use PongWeb, :live_component

  def render(assigns) do
    ~H"""
    <div class="flex justify-center w-[50%] gap-20" style={"position: absolute;left: 25%; top: 2%"}>
      <div class="text-left">
        <p class="text-9xl font-extrabold text-white">
          <%= @left_player_points %>
        </p>
      </div>

      <div class="text-right">
        <p class="text-9xl font-extrabold text-white">
          <%= @right_player_points %>
        </p>
      </div>
    </div>
    """
  end
end
