defmodule PongWeb.GameLive do
  use PongWeb, :live_view
  alias Pong.Game
  alias PongWeb.Presence

  def mount(%{"game_id" => game_id}, _session, socket) do
    game = Game.new(game_id)

    socket =
      socket
      |> assign(side: :spectator)
      |> assign(game: game)

    if connected?(socket) do
      # Subscribe to the game topic for PubSub
      PongWeb.Endpoint.subscribe("game:#{game_id}")

      # Track the player's presence in the game
      Presence.track(self(), "game:#{game_id}", socket.id, %{
        side: socket.assigns.side
      })
    end

    {:ok, socket, layout: false}
  end

  def handle_event("mouse_move", %{"mouse_y" => y}, socket) do
    game = socket.assigns.game

    updated_game = Game.move_player(game, socket.assigns.side, y)

    # broadcast to other browsers
    PongWeb.Endpoint.broadcast("game:#{game.id}", "game_update", updated_game)

    {:noreply, assign(socket, game: updated_game)}
  end

  def handle_info(%Phoenix.Socket.Broadcast{event: "game_update", payload: updated_game}, socket) do
    # Update the socket assigns with the new game data
    {:noreply, assign(socket, :game, updated_game)}
  end

  def handle_info(%Phoenix.Socket.Broadcast{event: "presence_diff", payload: _}, socket) do
    presences = PongWeb.Presence.list("game:#{socket.assigns.game.id}")
    side = assign_side(presences, socket.id)
    {:noreply, assign(socket, side: side)}
  end

  def handle_info(:move_ball, socket) do
    updated_game =
      socket.assigns.game
      |> Game.collision_check()
      |> Game.score_check()
      |> Game.move_ball()

    socket = socket |> assign(game: updated_game)

    PongWeb.Endpoint.broadcast("game:#{updated_game.id}", "game_update", updated_game)

    schedule_ball_movement()

    {:noreply, socket}
  end

  defp assign_side(presences, player_id) do
    player_ids = Map.keys(presences) |> Enum.sort() |> IO.inspect()

    cond do
      length(player_ids) == 1 ->
        :left

      length(player_ids) >= 2 ->
        [player1_id, player2_id | _] = player_ids
        schedule_ball_movement()

        cond do
          player_id == player1_id -> :left
          player_id == player2_id -> :right
          true -> :spectator
        end

      true ->
        :spectator
    end
  end

  defp schedule_ball_movement() do
    Process.send_after(self(), :move_ball, 10)
  end
end
