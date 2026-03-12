Silvia
===

This project contains my mods for a Rancilio Silvia espresso machine.

This project is using Nerves and Phoenix LiveView.

Currently the versions included are:

* `nerves`  - 1.11.1
* `phoenix`  - 1.7.18
* `phoenix_liveview` - 1.0.1
* `tailwindcss` - 0.2.3


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



Flashing to a Device
---

You can burn the first image with the following commands:

```bash
./scripts/deploy.sh
```


Hardware
---

* **Temperature Sensor:** PT100 RTD via MAX31865 SPI converter (3-wire, one-shot mode)
* **Relay:** RA2425-D06 solid state relay for heating element control

Roadmap
---

The next few steps are:
* Implement the PID controller for boiler temperature
* Insulate the boiler on the physical machine
* Work on the UI for the Dashboard
 
