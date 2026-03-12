import Config

# Have VintageNet not try to resolve so things can run locally
config :vintage_net,
  resolvconf: "/dev/null",
  persistence: VintageNet.Persistence.Null,
  bin_ip: "false"

# Use fake SPI on host (no hardware available)
config :silvia, :spi_module, Fake.SPI

################################################################
## NervesHub Config
################################################################
config :nerves_hub_link, connect: false