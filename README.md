Silvia
===

This project contains my mods for a Rancilio Silvia espresso machine.

This project is using Nerves and Phoenix LiveView.

Currently the versions included are:

* `nerves`  - 1.9.3
* `phoenix`  - 1.7.2
* `phoenix_liveview` - 0.18.18
* `tailwindcss` - 0.2.0


Configuration
---

The order of configuration is loaded in a specific order:

* `config.exs`
* `host.exs` or `target.exs`  based on `MIX_TARGET`
* `prod.exs`, `dev.exs`, or `test.exs` based on `MIX_ENV`
* `runtime.exs` at runtime

To make configuration slightly more straightforward, the application is run 
with `MIX_ENV=prod` when on the device.  Therefore, the configuration for
phoenix on the target device is in the `prod.exs` config file.


Developing
---

You can start the application just like any Phoenix project:

```bash
iex -S mix phx.server
```


Flashing to a Device
---

You can burn the first image with the following commands:

```bash
# If you want to enable wifi:
# export NERVES_SSID="NetworkName" && export NERVES_PSK="password"
MIX_ENV=prod MIX_TARGET=host mix do deps.get, assets.deploy
MIX_ENV=prod MIX_TARGET=rpi3 mix do deps.get, firmware, burn
```

Once the image is running on the device, the following will build and update the firmware
over ssh.

```bash
# If you want to enable wifi:
# export NERVES_SSID="NetworkName" && export NERVES_PSK="password"
MIX_ENV=prod MIX_TARGET=host mix do deps.get, assets.deploy
MIX_ENV=prod MIX_TARGET=rpi3 mix do deps.get, firmware, upload your_app_name.local
```


Network Configuration
---

The network and WiFi configuration are specified in the `target.exs` file.  In order to
specify the network name and password, they must be set as environment variables `NERVES_SSID`
`NERVES_PSK` at runtime.

If they are not specified, a warning will be printed when building firmware, which either
gives you a chance to stop the build and add the environment variables or a clue as to 
why you are no longer able to access the device over WiFi.

