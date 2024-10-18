defmodule SilviaWeb.Home do
  use SilviaWeb, :live_view

  alias Silvia.Controller
  alias Silvia.Dashboard

  @refresh_frequency 2_000

  def mount(_params, _session, socket) do
    if connected?(socket) do
      :timer.send_interval(@refresh_frequency, self(), :tick)
    end

    {:ok, assign_values(socket)}
  end

  def handle_info(:tick, socket) do
    {:noreply, assign_values(socket)}
  end

  def handle_event("refresh", _, socket) do
    {:noreply, assign_values(socket)}
  end

  def handle_event("brew-down", _, socket) do
    socket = update(socket, :brew_temperature, &(&1 - 1))
    Controller.brew_temperature(socket.assigns.brew_temperature)
    {:noreply, socket}
  end

  def handle_event("brew-up", _, socket) do
    socket = update(socket, :brew_temperature, &(&1 + 1))
    Controller.brew_temperature(socket.assigns.brew_temperature)
    {:noreply, socket}
  end

  def handle_event("steam-down", _, socket) do
    socket = update(socket, :steam_temperature, &(&1 - 1))
    Controller.steam_temperature(socket.assigns.steam_temperature)
    {:noreply, socket}
  end

  def handle_event("steam-up", _, socket) do
    socket = update(socket, :steam_temperature, &(&1 + 1))
    Controller.steam_temperature(socket.assigns.steam_temperature)
    {:noreply, socket}
  end

  defp assign_values(socket) do
    dashboard = Dashboard.dashboard_info()
    assign(socket,
      temperature: dashboard.temperature,
      brew_temperature: dashboard.brew_temperature,
      steam_temperature: dashboard.steam_temperature,
      wifi_status: dashboard.wifi_status
    )
  end

end
