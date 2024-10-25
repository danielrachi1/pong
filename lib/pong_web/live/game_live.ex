defmodule PongWeb.GameLive do
  use PongWeb, :live_view
  alias PongWeb.Presence

  def mount(%{"game_id" => game_id}, _session, socket) do
    # Start the game tick if the socket is connected
    if connected?(socket), do: :timer.send_interval(10, self(), :tick)

    # Generate a unique player ID using :crypto and Base modules
    player_id = :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)

    # Assign initial values to the socket
    socket =
      socket
      |> assign(:player_id, player_id)
      |> assign(:game_id, game_id)
      # Initial paddle position for the player
      |> assign(:y_player, 50)
      # Initial paddle position for the opponent
      |> assign(:y_opponent, 50)
      # Default side until assigned
      |> assign(:side, :spectator)
      # Initial ball state
      |> assign(:ball, %{x: 50, y: 50, vx: -0.25, vy: 0.0})
      # Initial score
      |> assign(:score, %{left: 0, right: 0})

    if connected?(socket) do
      # Subscribe to the game topic for PubSub
      PongWeb.Endpoint.subscribe("game:#{game_id}")

      # Track the player's presence in the game
      Presence.track(self(), "game:#{game_id}", player_id, %{})

      # Get the current list of presences to assign sides
      presences = Presence.list("game:#{game_id}")
      side = assign_side(presences, player_id)
      socket = assign(socket, :side, side)
    end

    {:ok, socket, layout: false}
  end

  def handle_event("cursor-move", %{"mouse_y" => y}, socket) do
    game_id = socket.assigns.game_id
    player_id = socket.assigns.player_id
    side = socket.assigns.side

    # Update own paddle position
    socket = assign(socket, :y_player, y)

    # Broadcast the new position to other clients
    PongWeb.Endpoint.broadcast_from(self(), "game:#{game_id}", "update_paddle", %{
      player_id: player_id,
      side: side,
      y: y
    })

    {:noreply, socket}
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

  def handle_info(
        %Phoenix.Socket.Broadcast{
          event: "presence_diff",
          payload: %{joins: _joins, leaves: _leaves}
        },
        socket
      ) do
    presences = PongWeb.Presence.list("game:#{socket.assigns.game_id}")
    side = assign_side(presences, socket.assigns.player_id)
    {:noreply, assign(socket, :side, side)}
  end

  def handle_info(%Phoenix.Socket.Broadcast{event: "update_paddle", payload: payload}, socket) do
    %{player_id: player_id, side: side, y: y} = payload

    if player_id != socket.assigns.player_id and opposite_side?(socket.assigns.side, side) do
      {:noreply, assign(socket, :y_opponent, y)}
    else
      {:noreply, socket}
    end
  end

  defp opposite_side?(:left, :right), do: true
  defp opposite_side?(:right, :left), do: true
  defp opposite_side?(_, _), do: false

  defp assign_side(presences, player_id) do
    player_ids = Map.keys(presences) |> Enum.sort()

    cond do
      player_ids == [player_id] ->
        :left

      length(player_ids) >= 2 ->
        [player1_id, player2_id | _] = player_ids

        cond do
          player_id == player1_id -> :left
          player_id == player2_id -> :right
          true -> :spectator
        end

      true ->
        :spectator
    end
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
