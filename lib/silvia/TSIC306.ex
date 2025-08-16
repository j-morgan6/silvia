defmodule Silvia.TSIC306 do
  require Logger
  use GenServer

  import Bitwise

  @me __MODULE__

  # total number of bits to read from tsic sensor
  @tsic_bits 20
  # length of the bit frame used by the tsic sensor in microseconds
  @tsic_frame_us 125
  # length of half of the bit frame used by the tsic sensor in microseconds
  @half_tsic_frame_us div(@tsic_frame_us, 2)
  # scale factor used to convert sensor values to fixed point integer
  @scale_factor 1000
  # minimum temperature
  @min_temp -50
  # maximum temperature
  @max_temp 150

  defstruct [:gpio_pin, :gpio_ref]


  def start_link(gpio_pin) do
    GenServer.start_link(__MODULE__, gpio_pin, name: __MODULE__)
  end

  # Public API when using GenServer
  def read_temp do
    GenServer.call(__MODULE__, :read_temperature)
  end

  def stop do
    GenServer.call(__MODULE__, :close)
    GenServer.stop(__MODULE__)
  end


  # GenServer callbacks
  def init(gpio_pin) do
    case open(gpio_pin) do
      {:ok, sensor} -> {:ok, sensor}
      error -> {:stop, error}
    end
  end

  def handle_call(:read_temperature, _from, sensor) do
    result = read_temperature(sensor)
    {:reply, result, sensor}
  end

  def handle_call(:close, _from, sensor) do
    close(sensor)
    {:reply, :ok, nil}
  end



  def open(gpio_pin) do
    case Circuits.GPIO.open(gpio_pin, :input, pull_mode: :pullup) do
      {:ok, gpio_ref} ->
        {:ok, %__MODULE__{gpio_pin: gpio_pin, gpio_ref: gpio_ref}}
      error ->
        Logger.error("Failed to open GPIO pin #{gpio_pin}: #{inspect(error)}")
        error
    end
  end

  def read_temperature(sensor) do
    case read_raw_data(sensor) do
      {:ok, raw_value} ->
        temperature = convert_to_celsius(raw_value)
        if valid_temperature?(temperature) do
          {:ok, temperature}
        else
          Logger.warning("Invalid temperature reading: #{temperature}")
          {:error, :invalid_reading}
        end
      error ->
        error
    end
  end

  defp read_raw_data(%__MODULE__{gpio_ref: gpio_ref}) do
    # Wait for start bit (falling edge)
    case wait_for_start_bit(gpio_ref) do
      :ok ->
        # Read the 20 bits of data
        case read_bits(gpio_ref, @tsic_bits) do
          {:ok, bits} ->
            # Convert bits to integer value
            raw_value = bits_to_integer(bits)
            {:ok, raw_value}
          error ->
            error
        end
      error ->
        error
    end
  end

  defp wait_for_start_bit(gpio_ref, timeout \\ 1000) do
    case wait_for_edge(gpio_ref, :falling, timeout) do
      :ok -> :ok
      :timeout ->
        Logger.warning("Timeout waiting for start bit")
        {:error, :timeout}
      error -> error
    end
  end

  defp wait_for_edge(gpio_ref, edge, timeout) do
    start_time = System.monotonic_time(:millisecond)

    current_state = Circuits.GPIO.read(gpio_ref)
    target_state = case edge do
      :falling -> 0
      :rising -> 1
    end

    wait_for_edge_loop(gpio_ref, target_state, start_time, timeout)
  end

  defp wait_for_edge_loop(gpio_ref, target_state, start_time, timeout) do
    current_time = System.monotonic_time(:millisecond)

    if current_time - start_time > timeout do
      :timeout
    else
      case Circuits.GPIO.read(gpio_ref) do
        ^target_state -> :ok
        _ ->
          Process.sleep(1)
          wait_for_edge_loop(gpio_ref, target_state, start_time, timeout)
      end
    end
  end

  defp read_bits(gpio_ref, num_bits) do
    bits = for bit_index <- 0..(num_bits - 1) do
    case read_single_bit(gpio_ref) do
      {:ok, bit} -> bit
        error -> throw(error)
      end
    end

    {:ok, bits}
  catch
      error -> error
  end

  defp read_single_bit(gpio_ref) do
    # Each bit frame is 125 microseconds
    # Sample at the middle of the frame (62.5 microseconds)
    :timer.sleep(div(@half_tsic_frame_us, 1000)) # Convert to milliseconds

    case Circuits.GPIO.read(gpio_ref) do
      bit when bit in [0, 1] ->
        # Wait for the rest of the bit frame
        :timer.sleep(div(@half_tsic_frame_us, 1000))
        {:ok, bit}
      error ->
        Logger.error("Failed to read bit: #{inspect(error)}")
        {:error, :read_failed}
    end
  end

  defp bits_to_integer(bits) do
    bits
    |> Enum.with_index()
    |> Enum.reduce(0, fn {bit, index}, acc ->
      acc ||| (bit <<< (@tsic_bits - 1 - index))
    end)
  end

  defp convert_to_celsius(raw_value) do
    # TSIC306 conversion formula
    # Temperature = (raw_value / 2047) * 200 - 50
    # where 2047 is the maximum raw value (2^11 - 1)
    # and the sensor range is -50°C to +150°C (200°C span)

    temp_float = (raw_value / 2047.0) * 200.0 - 50.0
    round(temp_float * @scale_factor) / @scale_factor
  end

  defp valid_temperature?(temp) do
    temp >= @min_temp and temp <= @max_temp
  end

  def close(%__MODULE__{gpio_ref: gpio_ref}) when gpio_ref != nil do
    Circuits.GPIO.close(gpio_ref)
  end
  def close(_), do: :ok

end
