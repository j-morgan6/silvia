defmodule Silvia.Hardware.TemperatureSensor do
  @moduledoc """
  GenServer driver for reading a PT100 RTD via MAX31865 over SPI.

  Communicates with the MAX31865 RTD-to-digital converter using SPI.
  Configured for 3-wire PT100, one-shot conversion mode, 60Hz noise filter.
  """
  use GenServer
  import Bitwise
  require Logger

  # MAX31865 register addresses (read)
  @config_reg 0x00
  @rtd_msb_reg 0x01
  @rtd_lsb_reg 0x02
  @fault_reg 0x07

  # Write address = read address | 0x80
  @write_bit 0x80

  # Config register bits for 3-wire PT100, one-shot, 60Hz filter
  # Bit 7: Vbias (1 = on)
  # Bit 6: Conversion mode (0 = one-shot)
  # Bit 5: One-shot (1 = trigger)
  # Bit 4: 3-wire (1 = 3-wire)
  # Bit 3-2: Fault detection (00 = none)
  # Bit 1: Fault status clear (0)
  # Bit 0: 50/60Hz filter (1 = 50Hz, 0 = 60Hz)
  @config_bias_on 0b10010000
  @config_oneshot 0b10110000

  # PT100 constants
  @r_ref 430.0
  @r_nominal 100.0

  # Callendar-Van Dusen coefficients
  @cvd_a 3.9083e-3
  @cvd_b -5.775e-7

  @default_spi_bus "spidev0.0"
  @default_spi_speed_hz 500_000
  @default_spi_mode 1
  @conversion_delay_ms 75

  # Client API

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Reads the current temperature from the PT100 RTD.

  Returns `{:ok, celsius}` or `{:error, reason}`.
  """
  def read_temperature do
    GenServer.call(__MODULE__, :read_temperature)
  end

  # Server Callbacks

  @impl true
  def init(opts) do
    spi_module = Application.get_env(:silvia, :spi_module, Circuits.SPI)

    spi_bus =
      Keyword.get(opts, :spi_bus, Application.get_env(:silvia, :spi_bus, @default_spi_bus))

    speed_hz = Keyword.get(opts, :speed_hz, @default_spi_speed_hz)
    mode = Keyword.get(opts, :mode, @default_spi_mode)

    case spi_module.open(spi_bus, speed_hz: speed_hz, mode: mode) do
      {:ok, spi} ->
        state = %{spi: spi, spi_module: spi_module}
        write_register(state, @config_reg, @config_bias_on)
        Logger.info("[#{inspect(__MODULE__)}] MAX31865 initialized on #{spi_bus}")
        {:ok, state}

      {:error, reason} ->
        Logger.error("[#{inspect(__MODULE__)}] Failed to open SPI: #{inspect(reason)}")
        {:stop, reason}
    end
  end

  @impl true
  def handle_call(:read_temperature, _from, state) do
    case do_read_temperature(state) do
      {:ok, temp} ->
        {:reply, {:ok, temp}, state}

      {:error, reason} = error ->
        Logger.error("[#{inspect(__MODULE__)}] Read failed: #{inspect(reason)}")
        {:reply, error, state}
    end
  end

  @impl true
  def terminate(_reason, %{spi: spi, spi_module: spi_module}) do
    spi_module.close(spi)
    :ok
  end

  def terminate(_reason, _state), do: :ok

  # Internal functions

  defp do_read_temperature(state) do
    # Trigger one-shot conversion
    write_register(state, @config_reg, @config_oneshot)
    Process.sleep(@conversion_delay_ms)

    with {:ok, rtd_raw} <- read_rtd(state),
         :ok <- check_faults(state) do
      temp = rtd_to_temperature(rtd_raw)
      {:ok, temp}
    end
  end

  defp read_rtd(state) do
    with {:ok, msb} <- read_register(state, @rtd_msb_reg),
         {:ok, lsb} <- read_register(state, @rtd_lsb_reg) do
      # RTD value is 15 bits: MSB[7:0] + LSB[7:1], LSB bit 0 is fault flag
      fault_bit = lsb &&& 0x01

      if fault_bit == 1 do
        {:error, :fault_detected}
      else
        rtd_raw = (msb <<< 8 ||| lsb) >>> 1
        {:ok, rtd_raw}
      end
    end
  end

  defp check_faults(state) do
    case read_register(state, @fault_reg) do
      {:ok, 0x00} ->
        :ok

      {:ok, fault_byte} ->
        reason = decode_fault(fault_byte)
        clear_faults(state)
        {:error, {:fault, reason}}

      {:error, _} = error ->
        error
    end
  end

  defp decode_fault(fault_byte) do
    faults =
      [
        {0x80, :rtd_high_threshold},
        {0x40, :rtd_low_threshold},
        {0x20, :ref_in_high},
        {0x10, :ref_in_low_force_open},
        {0x08, :rtd_force_low_open},
        {0x04, :overvoltage_undervoltage}
      ]
      |> Enum.filter(fn {mask, _} -> (fault_byte &&& mask) != 0 end)
      |> Enum.map(fn {_, name} -> name end)

    case faults do
      [single] -> single
      multiple -> multiple
    end
  end

  defp clear_faults(state) do
    # Read current config, set fault clear bit (bit 1), write back
    case read_register(state, @config_reg) do
      {:ok, config} -> write_register(state, @config_reg, config ||| 0x02)
      _ -> :ok
    end
  end

  @doc false
  def rtd_to_temperature(rtd_raw) do
    resistance = rtd_raw / 32768.0 * @r_ref

    # Callendar-Van Dusen equation (for T >= 0°C)
    # R(T) = R0(1 + aT + bT²)
    # Solving quadratic: T = (-a + sqrt(a² - 4b(1 - R/R0))) / (2b)
    discriminant = @cvd_a * @cvd_a - 4.0 * @cvd_b * (1.0 - resistance / @r_nominal)
    (-@cvd_a + :math.sqrt(discriminant)) / (2.0 * @cvd_b)
  end

  defp read_register(%{spi: spi, spi_module: spi_module}, register) do
    case spi_module.transfer(spi, <<register, 0x00>>) do
      {:ok, <<_sent, value>>} -> {:ok, value}
      {:error, _} = error -> error
    end
  end

  defp write_register(%{spi: spi, spi_module: spi_module}, register, value) do
    spi_module.transfer(spi, <<register ||| @write_bit, value>>)
  end
end
