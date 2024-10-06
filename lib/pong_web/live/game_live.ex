defmodule PongWeb.GameLive do
  use PongWeb, :live_view

  def render(assigns) do
    ~H"""
    <.live_component module={PongWeb.Components.PlayerLive} id="player" y={@y_player} />
    <.live_component module={PongWeb.Components.BallLive} id="ball" x={@ball.x} y={@ball.y} />
    """
  end

  def mount(_params, _session, socket) do
    if connected?(socket), do: :timer.send_interval(10, self(), :tick)
    ball = %{x: 50, y: 50, vx: -25 / 100, vy: 0 / 100}

    {
      :ok,
      socket
      |> assign(:y_player, 50)
      |> assign(:ball, ball),
      layout: {PongWeb.GameHTML, :game}
    }
  end

  def handle_event("cursor-move", %{"mouse_y" => y}, socket) do
    {:noreply, assign(socket, :y_player, y)}
  end

  def handle_info(:tick, socket) do
    %{
      x: ball_left_border_pos_current,
      y: ball_top_border_pos_current,
      vx: ball_speed_x_current,
      vy: ball_speed_y_current
    } =
      socket.assigns.ball

    ball_height = 1.25
    ball_vertical_middle = ball_top_border_pos_current + ball_height / 2

    paddel_size = 20
    paddel_sector_sizes = [45, 10, 45]
    paddel_sector_sizes_absolute = Enum.map(paddel_sector_sizes, &(&1 * paddel_size / 100))

    paddel_top = socket.assigns.y_player
    paddel_top_sector_bottom_limit = paddel_top + Enum.at(paddel_sector_sizes_absolute, 0)

    paddel_middle_sector_bottom_limit =
      paddel_top_sector_bottom_limit + Enum.at(paddel_sector_sizes_absolute, 1)

    paddel_bottom = paddel_middle_sector_bottom_limit + Enum.at(paddel_sector_sizes_absolute, 2)

    paddel_left_border = 6.25
    paddel_right_border = paddel_left_border + 1

    ball_left_border_next = ball_left_border_pos_current + ball_speed_x_current
    ball_top_border_next = ball_top_border_pos_current + ball_speed_y_current
    ball_bottom_border_next = ball_top_border_next + ball_height

    {ball_speed_x_next, ball_speed_y_next} =
      if is_float_in_range?(
           ball_left_border_next,
           paddel_left_border,
           paddel_right_border
         ) do
        cond do
          # Ball hits top paddel sector
          is_float_in_range?(ball_vertical_middle, paddel_top, paddel_top_sector_bottom_limit) ->
            {-ball_speed_x_current, ball_speed_x_current}

          # Ball hits middle paddel sector
          is_float_in_range?(
            ball_vertical_middle,
            paddel_top_sector_bottom_limit,
            paddel_middle_sector_bottom_limit
          ) ->
            {-ball_speed_x_current, ball_speed_y_current}

          # Ball hits bottom paddel sector
          is_float_in_range?(
            ball_vertical_middle,
            paddel_middle_sector_bottom_limit,
            paddel_bottom
          ) ->
            {-ball_speed_x_current, -ball_speed_x_current}

          # Ball doesn't hit the paddel
          true ->
            {ball_speed_x_current, ball_speed_y_current}
        end
      else
        # For collision against the walls
        cond do
          # Top wall
          ball_top_border_next < 0 -> {ball_speed_x_current, -ball_speed_y_current}
          # Bottom wall
          ball_bottom_border_next > 100 -> {ball_speed_x_current, -ball_speed_y_current}
          # No wall
          true -> {ball_speed_x_current, ball_speed_y_current}
        end
      end

    ball = %{
      x: ball_left_border_next,
      y: ball_top_border_next,
      vx: ball_speed_x_next,
      vy: ball_speed_y_next
    }

    {:noreply, assign(socket, ball: ball)}
  end

  defp is_float_in_range?(float, min, max) do
    float >= min and float <= max
  end
end
