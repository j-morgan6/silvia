defmodule Fake.VintageNet do
  @moduledoc false

  @valid_config %{
      ipv4: %{method: :dhcp},
      type: VintageNetWiFi,
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


  def get(_type) do
    :internet
  end

  def configured_interfaces() do
    ["wlan0"]
  end

  def get_configuration(_type) do
    @valid_config
  end

end
