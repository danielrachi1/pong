defmodule Pong.ScoreBoard do
  @initial_scores %{left: 0, right: 0}

  def new() do
    @initial_scores
  end

  def score(score_board, :left) do
    %{left: score_board.left + 1, right: score_board.right}
  end

  def score(score_board, :right) do
    %{left: score_board.left, right: score_board.right + 1}
  end
end
