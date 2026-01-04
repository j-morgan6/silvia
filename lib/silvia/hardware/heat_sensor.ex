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
  @max_raw_value 2047       # Maximum raw value (2^11 - 1)
  @temp_range 200.0         # Temperature range in Celsius (-50 to +150)
  @temp_offset -50.0        # Temperature offset in Celsius
  @timeout 1000             # Timeout for waiting for sensor response in ms
  # Note: @half_frame_us removed - now measured dynamically as Tstrobe

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
         {:ok, tstrobe} <- measure_start_bit_strobe(gpio_mod, gpio),
         {:ok, packet1} <- read_packet(gpio_mod, gpio, tstrobe, 1),
         :ok <- wait_for_stop_bit(gpio_mod, gpio),
         {:ok, packet2} <- read_packet(gpio_mod, gpio, tstrobe, 2) do
      Debug.print(tstrobe, "measured Tstrobe (μs)")
      Debug.print(packet1, "packet1 data bits")
      Debug.print(packet2, "packet2 data bits")
      {:ok, assemble_temperature(packet1, packet2)}
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

  # Measure Tstrobe from start bit (50% duty cycle)
  # Start bit: falling edge -> wait -> rising edge
  # Tstrobe = time from falling to rising edge (~62.5 μs nominal)
  defp measure_start_bit_strobe(gpio_mod, gpio) do
    # Wait for falling edge of start bit
    with :ok <- wait_for_edge(gpio_mod, gpio, 0) do
      # Start timing at falling edge
      start_time = System.monotonic_time(:microsecond)

      # Wait for rising edge
      case wait_for_edge(gpio_mod, gpio, 1) do
        :ok ->
          # Calculate Tstrobe duration
          tstrobe = System.monotonic_time(:microsecond) - start_time
          {:ok, tstrobe}
        error -> error
      end
    end
  end

  # Wait for GPIO to reach target value (0 or 1)
  defp wait_for_edge(gpio_mod, gpio, target_value) do
    start_time = System.monotonic_time(:millisecond)
    wait_for_edge_loop(gpio_mod, gpio, target_value, start_time)
  end

  defp wait_for_edge_loop(gpio_mod, gpio, target_value, start_time) do
    case gpio_mod.read(gpio) do
      {:error, reason} ->
        {:error, reason}
      ^target_value ->
        :ok
      _ ->
        if System.monotonic_time(:millisecond) - start_time > @timeout do
          {:error, :timeout}
        else
          # Busy wait for microsecond precision
          wait_for_edge_loop(gpio_mod, gpio, target_value, start_time)
        end
    end
  end

  # Read a single packet (10 bits: 1 start + 8 data + 1 parity)
  # Returns {:ok, data_bits} if parity is valid, or {:error, :parity_error}
  defp read_packet(gpio_mod, gpio, tstrobe, packet_num) do
    try do
      # Read 9 bits after start bit (8 data + 1 parity)
      bits = for _bit <- 1..9 do
        case read_single_bit(gpio_mod, gpio, tstrobe) do
          {:ok, bit} -> bit
          error -> throw(error)
        end
      end

      # Split into data bits and parity bit
      data_bits = Enum.take(bits, 8)
      parity_bit = Enum.at(bits, 8)

      # Validate even parity
      if check_even_parity(data_bits, parity_bit) do
        {:ok, data_bits}
      else
        Logger.error("Parity error in packet #{packet_num}")
        {:error, :"parity_error_packet#{packet_num}"}
      end
    catch
      error -> error
    end
  end

  # Wait for stop bit (signal HIGH for one bit window) between packets
  defp wait_for_stop_bit(gpio_mod, gpio) do
    # Wait for signal to go HIGH
    case wait_for_edge(gpio_mod, gpio, 1) do
      :ok -> :ok
      error -> error
    end
  end

  # Check even parity: count of 1s in (data_bits + parity_bit) should be even
  defp check_even_parity(data_bits, parity_bit) do
    ones_count = Enum.count(data_bits, &(&1 == 1))
    total_ones = ones_count + parity_bit
    rem(total_ones, 2) == 0
  end

  # Assemble 11-bit temperature from two 8-bit packets
  # Packet 1 bits [5,6,7] = T[10,9,8] (high 3 bits)
  # Packet 2 bits [0..7] = T[7..0] (low 8 bits)
  defp assemble_temperature(packet1_data, packet2_data) do
    # Extract high 3 bits from packet 1 (positions 5, 6, 7)
    t10 = Enum.at(packet1_data, 5)
    t9 = Enum.at(packet1_data, 6)
    t8 = Enum.at(packet1_data, 7)
    high_bits = (t10 <<< 2) ||| (t9 <<< 1) ||| t8

    # Extract low 8 bits from packet 2 (positions 0..7)
    low_bits = packet2_data
      |> Enum.with_index()
      |> Enum.reduce(0, fn {bit, index}, acc ->
        acc ||| (bit <<< (7 - index))
      end)

    # Combine into 11-bit temperature value
    (high_bits <<< 8) ||| low_bits
  end

  # Read a single bit using ZACWire duty cycle encoding
  # Sample at Tstrobe after falling edge to detect duty cycle
  defp read_single_bit(gpio_mod, gpio, tstrobe) do
    # Wait for falling edge of next bit
    with :ok <- wait_for_edge(gpio_mod, gpio, 0) do
      # Wait Tstrobe duration (busy-wait for microsecond precision)
      target_time = System.monotonic_time(:microsecond) + tstrobe
      busy_wait_until(target_time)

      # Sample GPIO at middle of bit window
      # 75% duty cycle: signal is HIGH -> bit = 1
      # 25% duty cycle: signal is LOW -> bit = 0
      case gpio_mod.read(gpio) do
        bit when bit in [0, 1] -> {:ok, bit}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  # Busy-wait until target time (microsecond precision)
  # Note: This blocks the BEAM scheduler but necessary for protocol timing
  defp busy_wait_until(target_time) do
    if System.monotonic_time(:microsecond) < target_time do
      busy_wait_until(target_time)
    end
  end

  defp convert_to_celsius(raw_value) do
    (raw_value / @max_raw_value * @temp_range) + @temp_offset
  end

  defp valid_temperature?(temp) do
    temp >= @temp_offset and temp <= (@temp_offset + @temp_range)
  end
end
