import Config

# Used when running locally - running tests
config :silvia, vintage_net: Fake.VintageNet
config :silvia, vintage_net_wizard: Fake.VintageNetWizard

# Have VintageNet not try to resolve so things can run locally
config :vintage_net,
  resolvconf: "/dev/null",
  persistence: VintageNet.Persistence.Null,
  bin_ip: "false"
