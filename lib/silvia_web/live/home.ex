defmodule SilviaWeb.Home do
  use SilviaWeb, :live_view

  alias Silvia.Controller
  alias Silvia.Dashboard

  @refresh_frequency 2_000

  #temperature limits
  @brew_temp_min 88
  @brew_temp_max 96
  @steam_temp_min 130
  @steam_temp_max 160

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
    new_temp = max(socket.assigns.brew_temperature - 1, @brew_temp_min)
    socket = assign(socket, :brew_temperature, new_temp)
    Controller.brew_temperature(new_temp)
    {:noreply, socket}
  end

  def handle_event("brew-up", _, socket) do
    new_temp = min(socket.assigns.brew_temperature + 1, @brew_temp_max)
    socket = assign(socket, :brew_temperature, new_temp)
    Controller.brew_temperature(new_temp)
    {:noreply, socket}
  end

  def handle_event("steam-down", _, socket) do
    new_temp = max(socket.assigns.steam_temperature - 1, @steam_temp_min)
    socket = assign(socket, :steam_temperature, new_temp)
    Controller.steam_temperature(new_temp)
    {:noreply, socket}
  end

  def handle_event("steam-up", _, socket) do
    new_temp = min(socket.assigns.steam_temperature + 1, @steam_temp_max)
    socket = assign(socket, :steam_temperature, new_temp)
    Controller.steam_temperature(new_temp)
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
