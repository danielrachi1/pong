defmodule Pong.Game do
  alias Pong.{Ball, Player, ScoreBoard}

  @left_player_left_border 6.25

  @right_player_left_border 100 - @left_player_left_border - Player.paddle_width()

  defstruct [:id, :ball, :players, :score_board]

  def new(id) do
    %Pong.Game{
      id: id,
      ball: Ball.new(:left),
      players: %{left: Player.new(), right: Player.new()},
      score_board: ScoreBoard.new(),
    }
  end

  def collision_check(game) do
    cond do
      game.ball.y + Ball.ball_height() / 2 > 100 ->
        collision(game, :wall)

        game.ball.y + Ball.ball_height() / 2 < 0 ->
        collision(game, :wall)

      float_in_range?(
        game.ball.x,
        @left_player_left_border,
        @left_player_left_border + Player.paddle_width()
      ) and
          float_in_range?(
            game.ball.y + Ball.ball_height() / 2,
            game.players.left.position,
            game.players.left.position + Player.paddle_height()
          ) ->
        collision(game, :player, :left)

      float_in_range?(
        game.ball.x,
        @right_player_left_border,
        @right_player_left_border + Player.paddle_width()
      ) and
          float_in_range?(
            game.ball.y + Ball.ball_height() / 2,
            game.players.right.position,
            game.players.right.position + Player.paddle_height()
          ) ->
        collision(game, :player, :right)

      true ->
        game
    end
  end

  def score_check(game) do
    cond do
      game.ball.x > 100 -> score(game)
      game.ball.x < 0 -> score(game)
      true -> game
    end
  end

  defp collision(game, :wall) do
    ball = game.ball

    new_ball = %{
      x: ball.x,
      y: ball.y,
      vx: ball.vx,
      vy: -ball.vy
    }

    %{game | ball: new_ball}
  end

  defp collision(game, :player, :left) do
    ball = game.ball
    player = game.players.left

    sectors = Player.paddle_sectors(player.position, Pong.Player.paddle_sector_sizes())

    {ball_vx_next, ball_vy_next} =
      handle_paddle_collision(
        ball.y + Ball.ball_height() / 2,
        player.position,
        sectors,
        ball.vx,
        ball.vy
      )

    new_ball = %{
      x: ball.x,
      y: ball.y,
      vx: ball_vx_next,
      vy: ball_vy_next
    }

    %{game | ball: new_ball}
  end

  defp collision(game, :player, :right) do
    ball = game.ball
    player = game.players.right

    sectors = Player.paddle_sectors(player.position, Pong.Player.paddle_sector_sizes())

    {ball_vx_next, ball_vy_next} =
      handle_paddle_collision(
        ball.y + Ball.ball_height() / 2,
        player.position,
        sectors,
        ball.vx,
        ball.vy
      )

    new_ball = %{
      x: ball.x,
      y: ball.y,
      vx: ball_vx_next,
      vy: -ball_vy_next
    }

    %{game | ball: new_ball}
  end

  def score(game) when game.ball.x > 100 do
    score_board = game.score_board

    new_score_board = ScoreBoard.score(score_board, :left)
    new_ball = Ball.new(:left)

    %{game | ball: new_ball, score_board: new_score_board}
  end

  def score(game) when game.ball.x < 0 do
    score_board = game.score_board

    new_score_board = ScoreBoard.score(score_board, :right)
    new_ball = Ball.new(:right)

    %{game | ball: new_ball, score_board: new_score_board}
  end

  def move_player(game, side, new_y) do
    players = Map.put(game.players, side, Player.move(new_y))

    %{game | players: players}
  end

  def move_ball(game) do
    ball = Ball.move(game.ball)

    %{game | ball: ball}
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

  defp float_in_range?(float, min, max) do
    float >= min and float <= max
  end
end
