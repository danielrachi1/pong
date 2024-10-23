defmodule PongWeb.HomeLive do
  use PongWeb, :live_view

  def mount(_params, _session, socket) do
    {:ok, socket, layout: false}
  end
end
