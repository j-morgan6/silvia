defmodule Silvia.WifiWizard do

  require Logger

  @ifname "wlan0"

  @doc false
  def setup_wifi_if_necessary() do
    unless network_configured?() do
      vintage_net_wizard().run_wizard(
        on_exit: {__MODULE__, :on_wizard_exit, []},
        ui: [title: "Silvia WiFi Wizard"]
      )
    end
  end

  @doc false
  def on_wizard_exit() do
    Logger.notice("[Silvia] - WiFi Wizard stopped")
  end


  def network_configured?() do
    case connection() do
      conn when conn in [:internet, :lan] ->
        true

      _ ->
        check_config()
    end
  end

  def connected_to_internet?() do
    connection() == :internet
  end

  def ssid() do
    case networks() do
      [network | _] -> network.ssid
      [] -> "No network"
    end
  end

  defp check_config() do
    Logger.info("[#{inspect(__MODULE__)}] Checking for wifi")

    with true <- wifi_configured?() || :not_configured,
         true <- has_networks?() || :no_networks do
      # By this point we know there is a wlan interface available
      # and already configured with networks.
      Logger.notice("[#{inspect(__MODULE__)}] Wifi is configured so will not start the wizard!")
      true
    else
      status ->
        info_message(status)
        vintage_net_wizard().run_wizard(on_exit: {__MODULE__, :on_wizard_exit, []})
      false
    end

  end

  def wifi_configured?() do
    configured_interfaces = vintage_net().configured_interfaces()
    @ifname in configured_interfaces
  end

  def has_networks?() do
    networks() != []
  end

  def info_message(status) do
    msg =
      case status do
        :not_configured -> "WiFi has not been configured"
        :no_networks -> "WiFi was configured without any networks"
      end

    Logger.notice("[#{inspect(__MODULE__)}] #{msg} - Starting WiFi Wizard")
  end

  defp networks() do
    case vintage_net().get_configuration(@ifname) do
      %{vintage_net_wifi: %{networks: networks}} -> networks
      _ -> []
    end
  end

  defp connection() do
    vintage_net().get(["connection"])
  end

  defp vintage_net() do
    Application.get_env(:silvia, :vintage_net)
  end

  defp vintage_net_wizard() do
    Application.get_env(:silvia, :vintage_net_wizard)
  end
end