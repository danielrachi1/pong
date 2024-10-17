defmodule PongWeb.GameLive do
  use PongWeb, :live_view

  def mount(_params, _session, socket) do
    if connected?(socket), do: :timer.send_interval(10, self(), :tick)
    ball = %{x: 50, y: 50, vx: -25 / 100, vy: 0 / 100}

    {
      :ok,
      socket
      |> assign(:y_player, 50)
      |> assign(:ball, ball)
      |> assign(:score, %{left: 0, right: 0}),
      layout: false
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
    } = socket.assigns.ball

    %{left: left_player_current_points, right: right_player_current_points} = socket.assigns.score

    ball_height = 1.25
    ball_vertical_middle = ball_top_border_pos_current + ball_height / 2

    paddel_top = socket.assigns.y_player
    paddel_sector_sizes = [45, 10, 45]

    {paddel_top_sector_bottom_limit, paddel_middle_sector_bottom_limit, paddel_bottom} =
      paddel_sectors(paddel_top, paddel_sector_sizes)

    paddel_left_border = 6.25
    paddel_right_border = paddel_left_border + 1

    ball_left_border_next = ball_left_border_pos_current + ball_speed_x_current
    ball_top_border_next = ball_top_border_pos_current + ball_speed_y_current
    ball_bottom_border_next = ball_top_border_next + ball_height

    {ball_speed_x_next, ball_speed_y_next} =
      cond do
        float_in_range?(ball_left_border_next, paddel_left_border, paddel_right_border) ->
          handle_paddle_collision(
            ball_vertical_middle,
            paddel_top,
            {paddel_top_sector_bottom_limit, paddel_middle_sector_bottom_limit, paddel_bottom},
            ball_speed_x_current,
            ball_speed_y_current
          )

        ball_top_border_next < 0 ->
          {ball_speed_x_current, -ball_speed_y_current}

        ball_bottom_border_next > 100 ->
          {ball_speed_x_current, -ball_speed_y_current}

        true ->
          {ball_speed_x_current, ball_speed_y_current}
      end

    {score, ball} =
      check_score_and_respawn_ball(
        ball_left_border_next,
        left_player_current_points,
        right_player_current_points,
        ball_speed_x_next,
        ball_speed_y_next,
        ball_top_border_next
      )

    {:noreply, assign(socket, ball: ball, score: score)}
  end

  defp paddel_sectors(paddel_top, paddel_sector_sizes) do
    paddel_sector_sizes_absolute = Enum.map(paddel_sector_sizes, &(&1 * 20 / 100))
    paddel_top_sector_bottom_limit = paddel_top + Enum.at(paddel_sector_sizes_absolute, 0)

    paddel_middle_sector_bottom_limit =
      paddel_top_sector_bottom_limit + Enum.at(paddel_sector_sizes_absolute, 1)

    paddel_bottom = paddel_middle_sector_bottom_limit + Enum.at(paddel_sector_sizes_absolute, 2)

    {paddel_top_sector_bottom_limit, paddel_middle_sector_bottom_limit, paddel_bottom}
  end

  defp handle_paddle_collision(
         ball_vertical_middle,
         paddel_top,
         {paddel_top_sector_bottom_limit, paddel_middle_sector_bottom_limit, paddel_bottom},
         ball_speed_x_current,
         ball_speed_y_current
       ) do
    cond do
      float_in_range?(ball_vertical_middle, paddel_top, paddel_top_sector_bottom_limit) ->
        {-ball_speed_x_current, ball_speed_x_current}

      float_in_range?(
        ball_vertical_middle,
        paddel_top_sector_bottom_limit,
        paddel_middle_sector_bottom_limit
      ) ->
        {-ball_speed_x_current, ball_speed_y_current}

      float_in_range?(ball_vertical_middle, paddel_middle_sector_bottom_limit, paddel_bottom) ->
        {-ball_speed_x_current, -ball_speed_x_current}

      true ->
        {ball_speed_x_current, ball_speed_y_current}
    end
  end

  defp check_score_and_respawn_ball(
         ball_left_border_next,
         left_player_current_points,
         right_player_current_points,
         ball_speed_x_next,
         ball_speed_y_next,
         ball_top_border_next
       ) do
    cond do
      ball_left_border_next > 100 ->
        {%{left: left_player_current_points + 1, right: right_player_current_points},
         %{x: 50, y: 50, vx: 25 / 100, vy: 0 / 100}}

      ball_left_border_next < 0 ->
        {%{left: left_player_current_points, right: right_player_current_points + 1},
         %{x: 50, y: 50, vx: -25 / 100, vy: 0 / 100}}

      true ->
        {%{left: left_player_current_points, right: right_player_current_points},
         %{
           x: ball_left_border_next,
           y: ball_top_border_next,
           vx: ball_speed_x_next,
           vy: ball_speed_y_next
         }}
    end
  end

  defp float_in_range?(float, min, max) do
    float >= min and float <= max
  end
end
