defmodule Pong.Player do
  @initial_top_of_paddle_position 50

  @paddle_sector_sizes [45, 10, 45]

  @paddle_width 1
  def paddle_width, do: @paddle_width

  @paddle_height 20
  def paddle_height, do: @paddle_height

  def paddle_sector_sizes, do: @paddle_sector_sizes

  def new() do
    %{
      position: @initial_top_of_paddle_position
    }
  end

  def move(new_position) do
    %{
      position: new_position
    }
  end

  def paddle_sectors(paddle_top, paddle_sector_sizes) do
    paddle_sector_sizes_absolute = Enum.map(paddle_sector_sizes, &(&1 * @paddle_height / 100))
    paddle_top_sector_bottom_limit = paddle_top + Enum.at(paddle_sector_sizes_absolute, 0)

    paddle_middle_sector_bottom_limit =
      paddle_top_sector_bottom_limit + Enum.at(paddle_sector_sizes_absolute, 1)

    paddle_bottom = paddle_middle_sector_bottom_limit + Enum.at(paddle_sector_sizes_absolute, 2)

    {paddle_top_sector_bottom_limit, paddle_middle_sector_bottom_limit, paddle_bottom}
  end
end
