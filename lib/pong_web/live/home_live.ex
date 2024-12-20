defmodule PongWeb.HomeLive do
  use PongWeb, :live_view

  def mount(_params, _session, socket) do
    room_code = generate_code()
    socket = assign(socket, :room_code, room_code)
    {:ok, socket, layout: false}
  end

  defp generate_code() do
    :rand.uniform(900_000) + 100_000
  end

  def handle_event("room_code_entered", %{"room_code" => room_code}, socket) do
    {:noreply, redirect(socket, to: "/#{room_code}")}
  end
end
