defmodule Pong.GameServer do
  use GenServer

  # Public API

  def start_link(game_id) do
    GenServer.start_link(__MODULE__, %{game_id: game_id}, name: via_tuple(game_id))
  end

  defp via_tuple(game_id) do
    {:via, Registry, {Pong.GameRegistry, game_id}}
  end

  def get_state(game_id) do
    GenServer.call(via_tuple(game_id), :get_state)
  end

  # GenServer Callbacks

  def init(state) do
    initial_state = %{
      game_id: state.game_id,
      ball: %{x: 50, y: 50, vx: -0.25, vy: 0.0},
      score: %{left: 0, right: 0},
      timer_ref: nil
    }

    # Start the game loop
    {:ok, schedule_tick(initial_state)}
  end

  def handle_info(:tick, state) do
    # Update the game state
    new_state = update_game_state(state)

    # Broadcast the new state to clients
    PongWeb.Endpoint.broadcast("game:#{state.game_id}", "game_state_update", %{
      ball: new_state.ball,
      score: new_state.score
    })

    # Schedule the next tick
    {:noreply, schedule_tick(new_state)}
  end

  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  # Helper functions

  defp schedule_tick(state) do
    timer_ref = Process.send_after(self(), :tick, 10)
    Map.replace(state, :timer_ref, timer_ref)
  end

  defp update_game_state(state) do
    ball = state.ball
    score = state.score

    # Update ball position
    ball_left_border_pos_current = ball.x
    ball_top_border_pos_current = ball.y
    ball_speed_x_current = ball.vx
    ball_speed_y_current = ball.vy

    ball_height = 1.25
    # Assuming the ball is square
    ball_width = 1.25

    # Compute next positions
    ball_left_border_next = ball_left_border_pos_current + ball_speed_x_current
    ball_top_border_next = ball_top_border_pos_current + ball_speed_y_current
    ball_bottom_border_next = ball_top_border_next + ball_height
    ball_right_border_next = ball_left_border_next + ball_width
    ball_vertical_middle = ball_top_border_next + ball_height / 2

    # Paddle dimensions and positions
    paddle_sector_sizes = [45, 10, 45]

    # Retrieve paddle positions from Presence
    paddles = get_paddle_positions(state.game_id)

    # Left paddle
    {left_paddle_top, left_paddle_left_border} =
      case paddles.left do
        # Default values if paddle position not available
        nil -> {50, 6.25}
        y_player -> {y_player, 6.25}
      end

    # Paddle width is 1%
    left_paddle_right_border = left_paddle_left_border + 1

    {left_paddle_top_sector_bottom_limit, left_paddle_middle_sector_bottom_limit,
     left_paddle_bottom} =
      paddle_sectors(left_paddle_top, paddle_sector_sizes)

    # Right paddle
    {right_paddle_top, right_paddle_left_border} =
      case paddles.right do
        # Default values if paddle position not available
        nil -> {50, 93.75}
        y_player -> {y_player, 93.75}
      end

    # Paddle width is 1%
    right_paddle_right_border = right_paddle_left_border + 1

    {right_paddle_top_sector_bottom_limit, right_paddle_middle_sector_bottom_limit,
     right_paddle_bottom} =
      paddle_sectors(right_paddle_top, paddle_sector_sizes)

    # Check for collisions
    collision_with_left_paddle =
      float_in_range?(ball_left_border_next, left_paddle_left_border, left_paddle_right_border) and
        float_in_range?(ball_vertical_middle, left_paddle_top, left_paddle_bottom)

    collision_with_right_paddle =
      float_in_range?(ball_right_border_next, right_paddle_left_border, right_paddle_right_border) and
        float_in_range?(ball_vertical_middle, right_paddle_top, right_paddle_bottom)

    {ball_speed_x_next, ball_speed_y_next} =
      cond do
        collision_with_left_paddle ->
          handle_paddle_collision(
            ball_vertical_middle,
            left_paddle_top,
            {left_paddle_top_sector_bottom_limit, left_paddle_middle_sector_bottom_limit,
             left_paddle_bottom},
            ball_speed_x_current,
            ball_speed_y_current
          )

        collision_with_right_paddle ->
          handle_paddle_collision(
            ball_vertical_middle,
            right_paddle_top,
            {right_paddle_top_sector_bottom_limit, right_paddle_middle_sector_bottom_limit,
             right_paddle_bottom},
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

    # Check for scoring and respawn ball if necessary
    {score, ball} =
      check_score_and_respawn_ball(
        ball_left_border_next,
        ball_right_border_next,
        score.left,
        score.right,
        ball_speed_x_next,
        ball_speed_y_next,
        ball_top_border_next
      )

    new_ball = %{
      x: ball.x,
      y: ball.y,
      vx: ball.vx,
      vy: ball.vy
    }

    %{state | ball: new_ball, score: score}
  end

  # Helper functions

  defp paddle_sectors(paddle_top, paddle_sector_sizes) do
    paddle_sector_sizes_absolute = Enum.map(paddle_sector_sizes, &(&1 * 20 / 100))
    paddle_top_sector_bottom_limit = paddle_top + Enum.at(paddle_sector_sizes_absolute, 0)

    paddle_middle_sector_bottom_limit =
      paddle_top_sector_bottom_limit + Enum.at(paddle_sector_sizes_absolute, 1)

    paddle_bottom = paddle_middle_sector_bottom_limit + Enum.at(paddle_sector_sizes_absolute, 2)

    {paddle_top_sector_bottom_limit, paddle_middle_sector_bottom_limit, paddle_bottom}
  end

  defp handle_paddle_collision(
         ball_vertical_middle,
         paddle_top,
         {paddle_top_sector_bottom_limit, paddle_middle_sector_bottom_limit, paddle_bottom},
         ball_speed_x_current,
         ball_speed_y_current
       ) do
    cond do
      float_in_range?(ball_vertical_middle, paddle_top, paddle_top_sector_bottom_limit) ->
        {-ball_speed_x_current, ball_speed_x_current}

      float_in_range?(
        ball_vertical_middle,
        paddle_top_sector_bottom_limit,
        paddle_middle_sector_bottom_limit
      ) ->
        {-ball_speed_x_current, ball_speed_y_current}

      float_in_range?(ball_vertical_middle, paddle_middle_sector_bottom_limit, paddle_bottom) ->
        {-ball_speed_x_current, -ball_speed_x_current}

      true ->
        {ball_speed_x_current, ball_speed_y_current}
    end
  end

  defp check_score_and_respawn_ball(
         ball_left_border_next,
         ball_right_border_next,
         left_player_current_points,
         right_player_current_points,
         _ball_speed_x_next,
         _ball_speed_y_next,
         _ball_top_border_next
       ) do
    cond do
      # Ball went past the right boundary
      ball_left_border_next > 100 ->
        {%{left: left_player_current_points + 1, right: right_player_current_points},
         %{x: 50, y: 50, vx: 25 / 100, vy: 0 / 100}}

      # Ball went past the left boundary
      ball_right_border_next < 0 ->
        {%{left: left_player_current_points, right: right_player_current_points + 1},
         %{x: 50, y: 50, vx: -25 / 100, vy: 0 / 100}}

      true ->
        {%{left: left_player_current_points, right: right_player_current_points},
         %{
           x: ball_left_border_next,
           y: _ball_top_border_next,
           vx: _ball_speed_x_next,
           vy: _ball_speed_y_next
         }}
    end
  end

  defp float_in_range?(float, min, max) do
    float >= min and float <= max
  end

  # Function to get paddle positions from Presence
  defp get_paddle_positions(game_id) do
    presences = PongWeb.Presence.list("game:#{game_id}")

    left_paddle =
      presences
      |> Enum.find(fn
        {_, %{metas: [%{side: :left}]}} -> true
        _ -> false
      end)
      |> case do
        {_, %{metas: [%{y_player: y}]}} -> y
        _ -> nil
      end

    right_paddle =
      presences
      |> Enum.find(fn
        {_, %{metas: [%{side: :right}]}} -> true
        _ -> false
      end)
      |> case do
        {_, %{metas: [%{y_player: y}]}} -> y
        _ -> nil
      end

    %{left: left_paddle, right: right_paddle}
  end
end
