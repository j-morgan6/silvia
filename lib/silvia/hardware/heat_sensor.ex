defmodule Silvia.Hardware.HeatSensor do
  @moduledoc """
  GenServer implementation for the TSIC306 temperature sensor.
  The TSIC306 is a digital temperature sensor with a range of -50°C to +150°C.
  """
  use GenServer
  require Logger
  import Bitwise

  # Constants for TSIC306
  @sample_interval 1_000      # Read interval in ms
  @bit_count 20              # Total number of bits in a reading
  @half_frame_us 62          # Half of the bit frame for sampling
  @max_raw_value 2047       # Maximum raw value (2^11 - 1)
  @temp_range 200.0         # Temperature range in Celsius (-50 to +150)
  @temp_offset -50.0        # Temperature offset in Celsius
  @timeout 1000             # Timeout for waiting for sensor response in ms

  defmodule State do
    defstruct [
      :gpio,                # GPIO reference
      :pin,                # GPIO pin number
      :timer,              # Timer reference for periodic readings
      :last_reading        # Last valid temperature reading
    ]
  end

  # Client API

  def start_link(opts \\ []) do
    pin = Keyword.get(opts, :pin, 4)  # Default to GPIO 4
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, pin, name: name)
  end

  def get_temperature do
    GenServer.call(__MODULE__, :get_temperature)
  end

  # Server Callbacks

  @impl true
  def init(pin) do
    gpio_mod = Application.get_env(:silvia, :gpio_module, Circuits.GPIO)

    case gpio_mod.open(pin, :input, pull_mode: :pullup) do
      {:ok, gpio} ->
        state = %State{
          gpio: gpio,
          pin: pin,
          last_reading: nil
        }
        schedule_reading()
        {:ok, state}

      {:error, reason} ->
        Logger.error("Failed to initialize GPIO #{pin}: #{inspect(reason)}")
        {:stop, reason}
    end
  end

  @impl true
  def handle_call(:get_temperature, _from, state) do
    {:reply, state.last_reading, state}
  end

  @impl true
  def handle_info(:read_temperature, state) do
    new_reading = read_temperature(state)
    schedule_reading()
    {:noreply, %{state | last_reading: new_reading}}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    {:noreply, %{state | subscribers: List.delete(state.subscribers, pid)}}
  end

  @impl true
  def terminate(_reason, state) do
    gpio_mod = Application.get_env(:silvia, :gpio_module, Circuits.GPIO)
    if state.gpio, do: gpio_mod.close(state.gpio)
    :ok
  end

  # Private Functions

  defp schedule_reading do
    Process.send_after(self(), :read_temperature, @sample_interval)
  end

  def read_temperature(%{gpio: gpio}) do
    gpio_mod = Application.get_env(:silvia, :gpio_module, Circuits.GPIO)
    case read_raw_data(gpio_mod, gpio) do
      {:ok, raw_value} ->
        Debug.print(raw_value, "raw_value in read_temperature")
        temp = convert_to_celsius(raw_value)
        Debug.print(temp, "temp in read_temperature")
        if valid_temperature?(temp), do: {:ok, temp}, else: {:error, :invalid_reading}
      error -> error
    end
  end

  def read_raw_data(gpio_mod, gpio) do
    with :ok <- wait_for_start(gpio_mod, gpio),
         {:ok, bits} <- read_bits(gpio_mod, gpio) do
      {:ok, bits_to_value(bits)}
    end
  end

  defp wait_for_start(gpio_mod, gpio) do
    start_time = System.monotonic_time(:millisecond)
    wait_for_falling_edge(gpio_mod, gpio, start_time)
  end

  defp wait_for_falling_edge(gpio_mod, gpio, start_time) do
    case gpio_mod.read(gpio) do
      0 -> :ok
      1 ->
        if System.monotonic_time(:millisecond) - start_time > @timeout do
          {:error, :timeout}
        else
          Process.sleep(1)
          wait_for_falling_edge(gpio_mod, gpio, start_time)
        end
      {:error, reason} -> {:error, reason}
    end
  end

  defp read_bits(gpio_mod, gpio) do
    try do
      bits = for _bit <- 1..@bit_count do
        case read_single_bit(gpio_mod, gpio) do
          {:ok, bit} -> bit
          error -> throw(error)
        end
      end
      Debug.print(bits, "bits in read_bits")
      {:ok, bits}
    catch
      error -> error
    end
  end

  defp read_single_bit(gpio_mod, gpio) do
    # Wait for half the bit frame
    :timer.sleep(@half_frame_us)

    case gpio_mod.read(gpio) do
      bit when bit in [0, 1] ->
        # Wait for the remaining half frame
        :timer.sleep(@half_frame_us)
        {:ok, bit}
      error -> {:error, error}
    end
  end

  defp bits_to_value(bits) do
    bits
    |> Enum.with_index()
    |> Enum.reduce(0, fn {bit, index}, acc ->
      acc ||| (bit <<< (@bit_count - 1 - index))
    end)
  end

  defp convert_to_celsius(raw_value) do
    (raw_value / @max_raw_value * @temp_range) + @temp_offset
  end

  defp valid_temperature?(temp) when is_number(temp) do
    temp >= @temp_offset and temp <= (@temp_offset + @temp_range)
  end
  defp valid_temperature?(_), do: false
end
