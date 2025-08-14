defmodule Silvia.WifiCheckerTest do
  use ExUnit.Case , async: true

  alias Silvia.WifiChecker

  describe "WifiChecker checking for wifi" do
    test "can know when wifi is up" do
      defmodule NetworkConnected do
        def get(_type), do: :internet
        def get_configuration(_type) do
          %{
            vintage_net_wifi: %{
              networks: [
                %{ssid: "deepfriedolives"}
              ]
            }
          }
        end
      end
      set_vintage_net_fake(NetworkConnected)

      {status, ssid} = WifiChecker.wifi_status()
      assert status == :connected
      assert ssid == "deepfriedolives"
    end

    test "can know when wifi is down" do
      defmodule CheckingWifi do
        def get(_type), do: :disconnected
      end
      set_vintage_net_fake(CheckingWifi)
      {status, _} = WifiChecker.wifi_status()
      assert status == :disconnected
    end

  end

  defp set_vintage_net_fake(module) do
    Application.put_env(:silvia, :vintage_net, module)
  end
end