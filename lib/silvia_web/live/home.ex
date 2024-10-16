defmodule SilviaWeb.Home do
  use SilviaWeb, :live_view

  alias Silvia.Dashboard

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      :timer.send_interval(5000, self(), :tick)
    end

    {:ok, assign_values(socket)}
  end

  @impl true
  def handle_event("refresh", _, socket) do
    {:noreply, assign_values(socket)}
  end

  @impl true
  def handle_info(:tick, socket) do
    {:noreply, assign_values(socket)}
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
