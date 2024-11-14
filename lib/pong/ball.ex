defmodule Pong.Ball do
  @initial_state %{
    x: 50,
    y: 50,
    vx: 0,
    vy: 0
  }

  @ball_height 1.25
  def ball_height, do: @ball_height

  def new(:left) do
    %{@initial_state | vx: -0.25}
  end

  def new(:right) do
    %{@initial_state | vx: 0.25}
  end

  def move(ball) do
    %{
      x: ball.x + ball.vx,
      y: ball.y + ball.vy,
      vx: ball.vx,
      vy: ball.vy
    }
  end
end
