defmodule Silvia.WifiChecker do
  use GenServer
  require Logger
  alias Silvia.WifiWizard
  alias Silvia.Controller

  @me __MODULE__
  @connected_frequency 60_000
  @disconnected_frequency 10_000

  def start_link(_) do
    GenServer.start_link(__MODULE__, :noargs, name: @me)
  end

  def init(:noargs) do
    Logger.info("[#{inspect(@me)}] starting WifiChecker GenServer")
    Process.send_after(self(), :check_wifi, 2_000)
    {:ok, :ok}
  end

  def handle_info(:check_wifi, :ok) do

    wifi_status = wifi_status()
    Process.send_after(self(), :check_wifi, delay(wifi_status))
    Controller.wifi(wifi_status)

    {:noreply, :ok}
  end

  def wifi_status() do
    if WifiWizard.connected_to_internet?() do
      {:connected, WifiWizard.ssid()}
    else
      {:disconnected, ""}
    end
  end

  defp delay({:disconnected, _}), do: @disconnected_frequency
  defp delay(_), do: @connected_frequency

end