# PT100/MAX31865 Hardware Verification Script
#
# Run on Raspberry Pi with PT100 connected:
#   mix run scripts/test_pt100.exs
#
# Tests SPI connectivity, reads raw ADC values, converts to temperature,
# checks for faults, and runs a 30-second continuous stability test.

import Bitwise

defmodule PT100Test do
  @config_reg 0x00
  @rtd_msb_reg 0x01
  @rtd_lsb_reg 0x02
  @fault_reg 0x07
  @write_bit 0x80

  @config_bias_on 0b10010000
  @config_oneshot 0b10110000

  @r_ref 430.0
  @r_nominal 100.0
  @cvd_a 3.9083e-3
  @cvd_b -5.775e-7

  @conversion_delay_ms 75

  @spi_bus "spidev0.0"
  @spi_speed_hz 500_000
  @spi_mode 1

  def run do
    IO.puts("=" |> String.duplicate(60))
    IO.puts("  PT100/MAX31865 Hardware Verification")
    IO.puts("=" |> String.duplicate(60))
    IO.puts("")

    case test_spi_connection() do
      {:ok, spi} ->
        test_config_register(spi)
        test_single_reading(spi)
        test_fault_status(spi)
        run_continuous_test(spi, 30)
        Circuits.SPI.close(spi)
        IO.puts("")
        IO.puts("=" |> String.duplicate(60))
        IO.puts("  VERIFICATION COMPLETE")
        IO.puts("=" |> String.duplicate(60))

      {:error, _reason} ->
        IO.puts("")
        IO.puts("RESULT: FAIL - Cannot proceed without SPI connection")
    end
  end

  defp test_spi_connection do
    IO.puts("--- SPI Connection Test ---")
    IO.puts("  Bus:   #{@spi_bus}")
    IO.puts("  Speed: #{@spi_speed_hz} Hz")
    IO.puts("  Mode:  #{@spi_mode}")

    case Circuits.SPI.open(@spi_bus, speed_hz: @spi_speed_hz, mode: @spi_mode) do
      {:ok, spi} ->
        IO.puts("  Status: PASS - SPI opened successfully")
        IO.puts("")

        # Initialize MAX31865 with bias on
        write_register(spi, @config_reg, @config_bias_on)
        Process.sleep(10)
        {:ok, spi}

      {:error, reason} ->
        IO.puts("  Status: FAIL - #{inspect(reason)}")
        IO.puts("")
        IO.puts("  Troubleshooting:")
        IO.puts("    - Ensure SPI is enabled (check /boot/config.txt for dtparam=spi=on)")
        IO.puts("    - Verify #{@spi_bus} exists: ls /dev/spidev*")
        IO.puts("    - Check wiring: CS->CE0, SCK->SCLK, SDI->MOSI, SDO->MISO")
        {:error, reason}
    end
  end

  defp test_config_register(spi) do
    IO.puts("--- Config Register Test ---")

    case read_register(spi, @config_reg) do
      {:ok, value} ->
        IO.puts("  Config register: 0x#{Integer.to_string(value, 16) |> String.pad_leading(2, "0")}")
        IO.puts("  Vbias:       #{if (value &&& 0x80) != 0, do: "ON", else: "OFF"}")
        IO.puts("  3-wire:      #{if (value &&& 0x10) != 0, do: "YES", else: "NO"}")
        IO.puts("  Filter:      #{if (value &&& 0x01) != 0, do: "50Hz", else: "60Hz"}")
        IO.puts("  Status: PASS")

      {:error, reason} ->
        IO.puts("  Status: FAIL - #{inspect(reason)}")
    end

    IO.puts("")
  end

  defp test_single_reading(spi) do
    IO.puts("--- Single Temperature Reading ---")

    case read_temperature(spi) do
      {:ok, rtd_raw, resistance, temp} ->
        IO.puts("  Raw ADC value: #{rtd_raw}")
        IO.puts("  Resistance:    #{Float.round(resistance, 2)} ohms")
        IO.puts("  Temperature:   #{Float.round(temp, 2)} C")

        cond do
          temp < -50 or temp > 500 ->
            IO.puts("  Status: WARN - Temperature out of expected range")

          true ->
            IO.puts("  Status: PASS")
        end

      {:error, reason} ->
        IO.puts("  Status: FAIL - #{inspect(reason)}")
    end

    IO.puts("")
  end

  defp test_fault_status(spi) do
    IO.puts("--- Fault Status Check ---")

    case read_register(spi, @fault_reg) do
      {:ok, 0x00} ->
        IO.puts("  Fault register: 0x00")
        IO.puts("  Status: PASS - No faults detected")

      {:ok, fault_byte} ->
        IO.puts("  Fault register: 0x#{Integer.to_string(fault_byte, 16) |> String.pad_leading(2, "0")}")
        decode_and_print_faults(fault_byte)
        IO.puts("  Status: FAIL - Faults detected")
        clear_faults(spi)
        IO.puts("  (Faults cleared)")

      {:error, reason} ->
        IO.puts("  Status: FAIL - Could not read fault register: #{inspect(reason)}")
    end

    IO.puts("")
  end

  defp run_continuous_test(spi, duration_seconds) do
    IO.puts("--- Continuous Reading Test (#{duration_seconds}s) ---")
    IO.puts("  Reading every 500ms...")
    IO.puts("")

    start_time = System.monotonic_time(:millisecond)
    end_time = start_time + duration_seconds * 1000

    results = collect_readings(spi, end_time, [])

    successes = Enum.filter(results, &match?({:ok, _, _, _}, &1))
    failures = length(results) - length(successes)
    total = length(results)

    if length(successes) > 0 do
      temps = Enum.map(successes, fn {:ok, _, _, temp} -> temp end)
      min_temp = Enum.min(temps)
      max_temp = Enum.max(temps)
      avg_temp = Enum.sum(temps) / length(temps)
      spread = max_temp - min_temp

      IO.puts("")
      IO.puts("  Results:")
      IO.puts("    Total readings:  #{total}")
      IO.puts("    Successful:      #{length(successes)}")
      IO.puts("    Failed:          #{failures}")
      IO.puts("    Success rate:    #{Float.round(length(successes) / total * 100, 1)}%")
      IO.puts("")
      IO.puts("  Temperature Statistics:")
      IO.puts("    Min:    #{Float.round(min_temp, 2)} C")
      IO.puts("    Max:    #{Float.round(max_temp, 2)} C")
      IO.puts("    Avg:    #{Float.round(avg_temp, 2)} C")
      IO.puts("    Spread: #{Float.round(spread, 2)} C")
      IO.puts("")

      cond do
        length(successes) / total < 0.9 ->
          IO.puts("  Status: FAIL - Success rate below 90%")

        spread > 5.0 ->
          IO.puts("  Status: WARN - Temperature spread > 5C (unstable readings)")

        true ->
          IO.puts("  Status: PASS")
      end
    else
      IO.puts("")
      IO.puts("  Results:")
      IO.puts("    Total readings: #{total}")
      IO.puts("    Successful:     0")
      IO.puts("    Failed:         #{failures}")
      IO.puts("")
      IO.puts("  Status: FAIL - No successful readings")
    end
  end

  defp collect_readings(spi, end_time, acc) do
    now = System.monotonic_time(:millisecond)

    if now >= end_time do
      Enum.reverse(acc)
    else
      result = read_temperature(spi)

      case result do
        {:ok, _rtd, _res, temp} ->
          IO.write("  #{Float.round(temp, 1)} C  \r")

        {:error, reason} ->
          IO.write("  ERROR: #{inspect(reason)}  \r")
      end

      Process.sleep(500)
      collect_readings(spi, end_time, [result | acc])
    end
  end

  defp read_temperature(spi) do
    # Trigger one-shot conversion
    write_register(spi, @config_reg, @config_oneshot)
    Process.sleep(@conversion_delay_ms)

    with {:ok, msb} <- read_register(spi, @rtd_msb_reg),
         {:ok, lsb} <- read_register(spi, @rtd_lsb_reg) do
      fault_bit = lsb &&& 0x01

      if fault_bit == 1 do
        {:error, :fault_detected}
      else
        rtd_raw = (msb <<< 8 ||| lsb) >>> 1
        resistance = rtd_raw / 32768.0 * @r_ref
        temp = rtd_to_temperature(rtd_raw)

        # Check fault register
        case read_register(spi, @fault_reg) do
          {:ok, 0x00} ->
            {:ok, rtd_raw, resistance, temp}

          {:ok, fault_byte} ->
            clear_faults(spi)
            {:error, {:fault, decode_faults(fault_byte)}}

          {:error, _} = error ->
            error
        end
      end
    end
  end

  defp rtd_to_temperature(rtd_raw) do
    resistance = rtd_raw / 32768.0 * @r_ref
    discriminant = @cvd_a * @cvd_a - 4.0 * @cvd_b * (1.0 - resistance / @r_nominal)
    (-@cvd_a + :math.sqrt(discriminant)) / (2.0 * @cvd_b)
  end

  defp read_register(spi, register) do
    case Circuits.SPI.transfer(spi, <<register, 0x00>>) do
      {:ok, <<_sent, value>>} -> {:ok, value}
      {:error, _} = error -> error
    end
  end

  defp write_register(spi, register, value) do
    Circuits.SPI.transfer(spi, <<register ||| @write_bit, value>>)
  end

  defp decode_and_print_faults(fault_byte) do
    faults = [
      {0x80, "RTD High Threshold"},
      {0x40, "RTD Low Threshold"},
      {0x20, "REFIN- > 0.85 x VBIAS"},
      {0x10, "REFIN- < 0.85 x VBIAS (FORCE- open)"},
      {0x08, "RTDIN- < 0.85 x VBIAS (FORCE- open)"},
      {0x04, "Overvoltage/Undervoltage"}
    ]

    Enum.each(faults, fn {mask, name} ->
      if (fault_byte &&& mask) != 0 do
        IO.puts("  FAULT: #{name}")
      end
    end)
  end

  defp decode_faults(fault_byte) do
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
  end

  defp clear_faults(spi) do
    case read_register(spi, @config_reg) do
      {:ok, config} -> write_register(spi, @config_reg, config ||| 0x02)
      _ -> :ok
    end
  end
end

PT100Test.run()
