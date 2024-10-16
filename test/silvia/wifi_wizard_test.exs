defmodule Silvia.WifiWizardTest do
  use ExUnit.Case
  import ExUnit.CaptureLog
  require Logger

  alias Silvia.WifiWizard

  describe "WifiWizard wifi configuration" do
    test "can detect when it is configured" do
      defmodule WifiConfigured do
        def configured_interfaces(), do: ["wlan0"]
      end
      set_vintage_net_fake(WifiConfigured)

      assert WifiWizard.wifi_configured?() == true
    end

    test "can detect when it is not configured" do
      defmodule WifiNotConfigured do
        def configured_interfaces(), do: []
      end
      set_vintage_net_fake(WifiNotConfigured)

      assert WifiWizard.wifi_configured?() == false
    end
  end

  describe "WifiWizard has networks" do
    test "can determine when a wifi network is available" do
      defmodule WifiPresent do
        def get_configuration(_type) do
          %{
            vintage_net_wifi: %{
              networks: [
                %{
                  key_mgmt: :wpa_psk,
                  mode: :infrastructure,
                  psk: "C003ECDDAFASDF",
                  ssid: "deepfriedolives"
                }
              ]
            }
          }
        end
      end
      set_vintage_net_fake(WifiPresent)

      assert WifiWizard.has_networks?() == true
    end

    test "can get the ssid for the network it is connected to" do
      defmodule GetSSID do
        def get_configuration(_type) do
          %{
            vintage_net_wifi: %{
              networks: [
                %{
                  key_mgmt: :wpa_psk,
                  mode: :infrastructure,
                  psk: "C003ECDDAFASDF",
                  ssid: "deepfriedolives"
                }
              ]
            }
          }
        end
      end
      set_vintage_net_fake(GetSSID)

      assert WifiWizard.ssid() == "deepfriedolives"
    end

    test "can determine when a wifi network is not available" do
      defmodule WifiNotPresent do
        def get_configuration(_type) do
          %{
            vintage_net_wifi: %{
              networks: []
            }
          }
        end
      end
      set_vintage_net_fake(WifiNotPresent)

      assert WifiWizard.has_networks?() == false
    end
  end

  describe "WifiWizard detect if system is on the Internet" do
    test "can know when connected to a network" do
      defmodule NetworkConnected do
        def get(_type), do: :internet
      end
      set_vintage_net_fake(NetworkConnected)

      assert WifiWizard.network_configured?() == true
    end

    test "can know if it has internet access" do
      defmodule InternetConnected do
        def get(_type), do: :internet
      end
      set_vintage_net_fake(InternetConnected)

      assert WifiWizard.connected_to_internet?() == true
    end

    test "can check when not connected to Internet if it is on wifi" do
      defmodule CheckingWifi do
        def get(_type), do: :disconnected
        def configured_interfaces(), do: ["wlan0"]
        def get_configuration(_type) do
          %{
            vintage_net_wifi: %{
              networks: [%{}]
            }
          }
        end
      end
      set_vintage_net_fake(CheckingWifi)

      assert capture_log(fn -> WifiWizard.network_configured?() end)
             =~ "Wifi is configured so will not start the wizard!"
    end

    test "notifies when the wifi is not available" do
      defmodule WifiNotAvilable do
        def get(_type), do: :disconnected
        def configured_interfaces(), do: []
        def get_configuration(_type) do
          %{
            vintage_net_wifi: %{
              networks: []
            }
          }
        end
      end
      set_vintage_net_fake(WifiNotAvilable)

      assert capture_log(fn -> WifiWizard.network_configured?() end)
             =~ "WiFi has not been configured"
    end

    test "notifies when the Wifi was configured without any networks" do
      defmodule ConfigWithoutNetwork do
        def get(_type), do: :disconnected
        def configured_interfaces(), do: ["wlan0"]
        def get_configuration(_type) do
          %{
            vintage_net_wifi: %{
              networks: []
            }
          }
        end
      end
      set_vintage_net_fake(ConfigWithoutNetwork)

      assert capture_log(fn -> WifiWizard.network_configured?() end)
             =~ "WiFi was configured without any networks"
    end

    test "starts the Wifi wizard when the wifi is not configured" do
      defmodule NeedWizard do
        def get(_type), do: :disconnected
        def configured_interfaces(), do: []
      end
      defmodule Wizard do
        def run_wizard(_opts), do: Logger.info("Starting Wizard")
      end
      set_vintage_net_fake(NeedWizard)
      set_vintage_net_wizard_fake(Wizard)

      assert capture_log(fn -> WifiWizard.network_configured?() end)
             =~ "Starting Wizard"
    end
  end

  defp set_vintage_net_fake(module) do
    Application.put_env(:silvia, :vintage_net, module)
  end

  defp set_vintage_net_wizard_fake(module) do
    Application.put_env(:silvia, :vintage_net_wizard, module)
  end
end