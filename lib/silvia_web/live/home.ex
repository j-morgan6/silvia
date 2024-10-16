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
  def render(assigns) do
    ~H"""
    <.page_title title="Dashboard" />
    <.body>
      <div id="dashboard">
        <div class="info">
          <div class="datapoint">
            <span class="value">
              <%= @temperature %>C
            </span>
            <span class="label">
              Current Temperature
            </span>
          </div>
          <div class="datapoint">
            <span class="value">
              <%= @brew_temperature %>C
            </span>
            <span class="label">
              Brew Temperature
            </span>
          </div>
          <div class="datapoint">
            <span class="value">
              <%= @steam_temperature %>C
            </span>
            <span class="label">
              Steam Temperature
            </span>
          </div>
        </div>
      </div>

      <div id="set_temperature">
        <h2>Set Brew Temperature</h2>
        <div class="meter">
          <span style={"width: #{(100-(98-@brew_temperature)*(100/6))}%; background: #F1C40D"}>
            <%= @brew_temperature %>C
          </span>
        </div>
        <button>
          <img src="/images/down.svg" />
        </button>
        <button>
          <img src="/images/up.svg" />
        </button>
      </div>

      <div id="set_temperature">
        <h2>Set Steam Temperature</h2>
        <div class="meter">
          <span style={"width: #{(100-(145-@steam_temperature)*10)}%; background: #99CCFF"}>
            <%= @steam_temperature %>C
          </span>
        </div>
        <button>
          <img src="/images/down.svg" />
        </button>
        <button>
          <img src="/images/up.svg" />
        </button>
      </div>
    </.body>
    """
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
      steam_temperature: dashboard.steam_temperature
    )
  end

end
