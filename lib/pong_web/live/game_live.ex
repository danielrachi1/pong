defmodule PongWeb.GameLive do
  use PongWeb, :live_view
  alias Pong.GameServer
  alias PongWeb.Presence

  def mount(%{"game_id" => game_id}, _session, socket) do
    # Start the GameServer for this game_id if it doesn't exist
    case DynamicSupervisor.start_child(Pong.GameSupervisor, {GameServer, game_id}) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
      {:error, reason} -> {:stop, reason}
    end

    # Generate a unique player ID
    player_id = :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)

    # Get the current game state from the GameServer
    game_state = GameServer.get_state(game_id)

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
      # Assign the game state from the GameServer
      |> assign(:ball, game_state.ball)
      |> assign(:score, game_state.score)

    if connected?(socket) do
      # Subscribe to the game topic for PubSub
      PongWeb.Endpoint.subscribe("game:#{game_id}")

      # Track the player's presence in the game
      Presence.track(self(), "game:#{game_id}", player_id, %{
        y_player: socket.assigns.y_player,
        side: socket.assigns.side
      })
    end

    {:ok, socket, layout: false}
  end

  def handle_event("cursor-move", %{"mouse_y" => y}, socket) do
    game_id = socket.assigns.game_id
    player_id = socket.assigns.player_id
    side = socket.assigns.side

    # Update own paddle position
    socket = assign(socket, :y_player, y)

    # Update presence metadata
    Presence.update(self(), "game:#{game_id}", player_id, %{
      y_player: y,
      side: side
    })

    # Broadcast the new position to other clients
    PongWeb.Endpoint.broadcast_from(self(), "game:#{game_id}", "paddle_update", %{
      "player_id" => player_id,
      "side" => side,
      "y" => y
    })

    {:noreply, socket}
  end

  # Handle presence updates to assign sides
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

  # Handle paddle updates from other players
  def handle_info(%Phoenix.Socket.Broadcast{event: "paddle_update", payload: payload}, socket) do
    %{"player_id" => player_id, "side" => side, "y" => y} = payload

    if player_id != socket.assigns.player_id and opposite_side?(socket.assigns.side, side) do
      {:noreply, assign(socket, :y_opponent, y)}
    else
      {:noreply, socket}
    end
  end

  # Handle game state updates from the GameServer
  def handle_info(
        %Phoenix.Socket.Broadcast{event: "game_state_update", payload: new_state},
        socket
      ) do
    {:noreply, assign(socket, ball: new_state.ball, score: new_state.score)}
  end

  # Helper functions
  defp opposite_side?(:left, :right), do: true
  defp opposite_side?(:right, :left), do: true
  defp opposite_side?(_, _), do: false

  defp assign_side(presences, player_id) do
    player_ids = Map.keys(presences) |> Enum.sort()

    cond do
      length(player_ids) == 1 ->
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
end
