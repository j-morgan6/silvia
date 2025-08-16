# add GenServer
# ... existing code ...
#    children = [
#      # ... other children ...
#      {Silvia.Relay, []}
#    ]
# ... existing code ...


# Turn the relay on
#Silvia.Relay.on()

# Turn the relay off
#Silvia.Relay.off()

# Check the current state
#case Silvia.Relay.state() do
#  :on -> IO.puts("Relay is on")
#  :off -> IO.puts("Relay is off")
#end

# Specify the pin number
#Silvia.Relay, [pin: 23]}


defmodule Silvia.Hardware.Relay do
  @moduledoc """
  GenServer for controlling the RA2425-D06 relay.
  This module handles the relay state and provides a clean interface for controlling it.
  """
  use GenServer
  require Logger

  @default_pin 18  # You can adjust this pin number based on your wiring

  # Client API

  def start_link(opts \\ []) do
    pin = Keyword.get(opts, :pin, @default_pin)
    GenServer.start_link(__MODULE__, pin, name: __MODULE__)
  end

  @doc """
  Turns the relay on
  """
  def on do
    GenServer.call(__MODULE__, :on)
  end

  @doc """
  Turns the relay off
  """
  def off do
    GenServer.call(__MODULE__, :off)
  end

  @doc """
  Gets the current state of the relay
  Returns :on or :off
  """
  def state do
    GenServer.call(__MODULE__, :get_state)
  end

  # Server Callbacks

  @impl true
  def init(pin) do
    gpio_module = Application.get_env(:silvia, :gpio_module, Circuits.GPIO)

    case gpio_module.open(pin, :output) do
      {:ok, gpio} ->
        # Initialize in OFF state
        gpio_module.write(gpio, 0)
        {:ok, %{gpio: gpio, state: :off, pin: pin, gpio_module: gpio_module}}

      {:error, error} ->
        Logger.error("Failed to initialize GPIO #{pin}: #{inspect(error)}")
        {:stop, error}
    end
  end

  @impl true
  def handle_call(:on, _from, %{gpio: gpio, gpio_module: gpio_module} = state) do
    gpio_module.write(gpio, 1)
    {:reply, :ok, %{state | state: :on}}
  end

  @impl true
  def handle_call(:off, _from, %{gpio: gpio, gpio_module: gpio_module} = state) do
    gpio_module.write(gpio, 0)
    {:reply, :ok, %{state | state: :off}}
  end

  @impl true
  def handle_call(:get_state, _from, state) do
    {:reply, state.state, state}
  end

  @impl true
  def terminate(_reason, %{gpio: gpio, gpio_module: gpio_module}) do
    # Ensure we turn off the relay and close the GPIO properly
    gpio_module.write(gpio, 0)
    gpio_module.close(gpio)
    :ok
  end
end
